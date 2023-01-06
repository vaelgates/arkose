/* eslint-env jquery */

class Argument {
  static findArgumentByPath(searchArguments, path) {
    let queue = [...searchArguments]
    while (queue.length > 0) {
      const argument = queue.shift()
      if (argument.url === path || `${window.site_baseurl}${argument.url}` === path) {
        return argument;
      }
      if (argument.subArguments?.length > 0) {
        queue = queue.concat(argument.subArguments)
      }
    }
    return null
  }

  static updateSubSubArgumentVisibility() {
    const originalArgMapBottom = $('.argument-map')[0].offsetTop + $('.argument-map')[0].offsetHeight
    for (const subSection of $('.sub-sub-argument')) {
      let subNodesNotable = $(subSection).find('.argument-shape-link').filter((i, node) => ($(node).hasClass('disagree') || $(node).hasClass('none'))).length
      subNodesNotable += $(subSection).siblings('.argument-shape-link.agree, .argument-shape-link.disagree').length
      if (subNodesNotable > 0) {
        $(subSection).show()
      } else {
        $(subSection).hide()
      }
    }
    const newArgMapBottom = $('.argument-map')[0].offsetTop + $('.argument-map')[0].offsetHeight

    // if the argument map increased in height, and the argument map is within the current scroll view,
    // scroll down by the amount the argument map's height increased, so the content stays in the same
    // position.
    if (newArgMapBottom > originalArgMapBottom && $(document).scrollTop() < newArgMapBottom) {
      const argMapHeightIncrease = newArgMapBottom - originalArgMapBottom
      window.scrollTo({ top: $(document).scrollTop() + argMapHeightIncrease, behavior: 'instant' })
    }
  }

  constructor(args, params, parent = undefined) {
    this.args = args
    this.parent = parent
    this.name = params.name
    this.linkName = params.linkName ?? params.name
    this.url = params.url
    this.text = params.text ?? params.name
    this.effect = params.effect ?? 'disagree'
    this.nodeLinkUrl = params.nodeLinkUrl
    this.answerLinkUrl = params.answerLinkUrl
    this.agreeTargetUrl = params.agreeTargetUrl
    this.question = params.question
    this.askQuestion = params.askQuestion ?? true
    this.overridesSiblings = params.overridesSiblings ?? false
    this.parentListingType = params.parentListingType ?? 'checkbox'
    this.propagateAgreement = params.propagateAgreement ?? true
    this.listInTree = params.listInTree ?? true
    this.isCheckboxOption = params.isCheckboxOption ?? true
    this.delegateCheckboxes = params.delegateCheckboxes
    this.subArguments = []
    if (params.subArguments) {
      for (const subArgumentObj of params.subArguments) {
        this.subArguments.push(new Argument(args, subArgumentObj, this))
      }
    }
  }

  setAgreement(agreement, propagateFurther = true, pulse = true) {
    if (agreement == 'undecided') {
      this.agreement = null
    } else {
      this.agreement = agreement
    }

    this.colorSelfNode(pulse)

    if (propagateFurther) {
      if (agreement !== 'undecided') this.overrideSiblingsIfNeeded(agreement)
      if (this.effect !== 'none') this.propagateUp(agreement)
    }
    const checkboxes = $(`input[data-url='${this.url}']`)
    for (const checkbox of checkboxes) {
      if ($(checkbox).data('effect') === agreement) {
        $(checkbox).prop('checked', true)
      } else {
        $(checkbox).prop('checked', false)
      }
      const linkId = checkbox.id.substr(3);
      const linkEl = $(`.link-${linkId}`)
      if ($(checkbox).prop('checked')) {
        linkEl.addClass('visible')
      } else {
        linkEl.removeClass('visible')
      }
    }
  }

  getAgreement() {
    if (this.agreeTargetUrl) {
      const canonicalArgument = Argument.findArgumentByPath(this.args, this.agreeTargetUrl)
      return canonicalArgument.agreement
    } else {
      return this.agreement
    }
  }

  rootArgument() {
    let ancestor = this
    let nextAncestor = true
    while (nextAncestor) {
      nextAncestor = ancestor.parent
      if (nextAncestor) ancestor = nextAncestor
    }
    return ancestor
  }

  siblings() {
    if (!this.parent) return []

    return this.parent.subArguments.filter(child => child !== this)
  }

  nextSectionArgument() {
    const thisSectionIndex = this.args.indexOf(this.rootArgument())
    if (this.args[thisSectionIndex + 1]) return this.args[thisSectionIndex + 1]
  }

  nameAsId() {
    return this.name.toLowerCase().replace(/[^a-zA-Z0-9]+/g, '_')
  }

  overrideSiblingsIfNeeded(agreement) {
    if (this.overridesSiblings) {
      this.overrideSiblings()
    } else if (this.subArguments.length === 0) {
      this.overrideYesNoSibling(agreement)
    }
  }

  overrideSiblings() {
    for (const sibling of this.siblings()) {
      sibling.setAgreement(null, false)
    }
  }

  overrideYesNoSibling(agreement) {
    const yesNo = agreement === 'undecided' ? 'no' : 'yes'
    const checkbox = $(`input[data-url='${this.url}'][value=${yesNo}]`)
    if (checkbox.prop('checked')) checkbox.prop('checked', false)
  }

  checkboxArguments() {
    let checkboxArgs = []
    if (this.subArguments.length > 0) {
      for (const subArgument of this.subArguments) {
        if (subArgument.isCheckboxOption) {
          checkboxArgs.push(subArgument)
        }
        if (subArgument.delegateCheckboxes) {
          checkboxArgs.push(subArgument.checkboxArguments())
        }
      }
    }
    return checkboxArgs.flat()
  }

  colorSelfNode(pulse) {
    const argNodes = $(`a[data-url='${this.url}']`)

    for (const node of argNodes) {
      const originalNodeClasses = node.classList.length
      if (!$(node).data('effect') || $(node).data('effect') == this.getAgreement()) {
        $(node).removeClass(['agree', 'disagree', 'none'])
        $(node).addClass(this.getAgreement())
      } else {
        $(node).removeClass(['agree', 'disagree', 'none'])
      }
      if (pulse && originalNodeClasses !== node.classList.length) {
        $(node).addClass('pulse')
        window.setTimeout(() => {
          $(node).removeClass('pulse')
        }, 100)
      }
    }
  }

  siblingsAgreement() {
    let siblingArguments
    if (this.parent.delegateCheckboxes) {
      siblingArguments = this.parent.parent.checkboxArguments()
    } else {
      siblingArguments = this.parent.checkboxArguments()
    }
    return siblingArguments.reduce(
      (agreement, argument) => {
        if (agreement === 'conflict') return 'conflict'
        if (agreement === 'agree' && argument.getAgreement() === 'disagree') return 'conflict'
        if (agreement === 'disagree' && argument.getAgreement() === 'agree') return 'conflict'
        return argument.getAgreement() || agreement
      }, 'undecided')
  }

  noNewDisagreementInConflict(agreement, siblingsAgreement) {
    return (agreement !== 'disagree' && this.parent?.parent?.effect === 'calculated' && siblingsAgreement === 'conflict')
  }

  propagateUp(agreement) {
    if (!this.parent) return
    if (!this.propagateAgreement) return

    const siblingsAgreement = this.siblingsAgreement()
    if (this.noNewDisagreementInConflict(agreement, siblingsAgreement)) return

    if (agreement === 'undecided' && this.parent?.parent?.effect === 'calculated' && siblingsAgreement === 'conflict') return
    if (this.parent.effect === 'calculated' || this.parent.effect === siblingsAgreement) {
      const parentAgreement = siblingsAgreement === 'conflict' ? 'undecided' : siblingsAgreement
      this.parent.setAgreement(parentAgreement)
    } else if (this.parent.effect === 'disagree' && siblingsAgreement === 'conflict') {
      this.parent.setAgreement('disagree')
    } else {
      this.parent.setAgreement('undecided')
    }
    this.parent.propagateUp()
  }
}

export default Argument
