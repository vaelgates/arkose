/* eslint-env jquery */

class Argument {
  static updateLinkSectionVisibility() {
    const visibleLinks = $('a.answer-link').filter((i, a) => $(a).css('display') !== 'none')
    if (visibleLinks.length > 0) {
      $('.nav-answer-links').show()
    } else {
      $('.nav-answer-links').hide()
    }
  }

  static findArgumentByPath(currentArguments, path) {
    for (const argument of currentArguments) {
      if (argument.url === path || `${window.site_baseurl}${argument.url}` === path) {
        return argument;
      }
  
      if (argument.subArguments?.length > 0) {
        const foundArg = Argument.findArgumentByPath(argument.subArguments, path)
        if (foundArg) 
          return foundArg;
        
      }
    }
    return null
  }

  static updateSubSubArgumentVisibility() {
    for (const subSection of $('.sub-sub-argument')) {
      let subNodesNotable = $(subSection).find('.argument-shape-link').filter((i, node) => ($(node).hasClass('disagree') || $(node).hasClass('none'))).length
      subNodesNotable += $(subSection).siblings('.argument-shape-link.agree, .argument-shape-link.disagree').length
      if (subNodesNotable > 0) {
        $(subSection).show()
      } else {
        $(subSection).hide()
      }
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

  setAgreement(agreement, propagateFurther = true) {
    if (agreement == 'undecided') {
      this.agreement = null
    } else {
      this.agreement = agreement
    }

    this.colorSelfNode()

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
      const linkId = `link_${checkbox.id.substr(3)}`;
      const linkEl = $(`#${linkId}`)
      if ($(checkbox).prop('checked')) {
        linkEl.css('display', 'block')
      } else {
        linkEl.hide()
      }
    }
    Argument.updateLinkSectionVisibility()
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
    // const yesNo = agreement === 'agree' ? 'no' : 'yes'
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

  colorSelfNode() {
    const fullUrl = `${window.site_baseurl}${this.url}`
    const argNodes = $(`a[data-url='${fullUrl}']`)

    for (const node of argNodes) {
      if (!$(node).data('effect') || $(node).data('effect') == this.getAgreement()) {
        $(node).removeClass(['agree', 'disagree', 'none'])
        $(node).addClass(this.getAgreement())
      } else {
        $(node).removeClass(['agree', 'disagree', 'none'])
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

  propagateUp(agreement) {
    if (!this.parent) return
    if (!this.propagateAgreement) return

    const siblingsAgreement = this.siblingsAgreement()
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
