function html_asset_path(path) {
  path_parts = path.match(/(\/aird\/)(.*)/);
  if (!path_parts || path_parts.length < 3) 
    throw `path mismatch for ${path}`

  return `${
    path_parts[1]
  }assets/html/${
    path_parts[2]
  }`
}

function findArgumentByPath(currentArguments, path) {
  for (const argument of currentArguments) {
    if (`${window.site_baseurl}${argument.url}` === path && argument.listInTree !== 'false') {
      return argument;
    }
    
    if (argument.subArguments?.length > 0) {
      const foundArg = findArgumentByPath(argument.subArguments, path)
      if (foundArg) 
        return foundArg;
      
    }
  }
  return null
}

function toId(s) {
  return s.toLowerCase().replace(/[^a-zA-Z0-9]+/g, '_')
}

/* hideOldStuff can be removed after updating the script to not include the questions at the end of each page,
    but to instead include them in arguments.yml */
function hideOldStuff(argument) {
  $('.nav-answers-old').hide();
  $('.question').hide();

  // Don't remove the links section if the page has no questions
  if (argument.noQuestion) return

  for (let a of $('div a')) {
    if (a.id === 'feedback_button') continue
    if (a.childNodes.length <= 1 && a.parentNode.innerText.match(/➥|✉/))
      $(a.parentNode).hide()
  }
}

function insertTitleQuestion(argument) {
  if (argument.question) {
    $(`<h2>${argument.question}</h2>`).appendTo($('.page-content'));
  } else {
    if (argument.subArguments?.length > 0) {
      $('<h2>Do you agree?</h2>').appendTo($('.page-content'));
    } else {
      $('<h2>Do you find the above arguments convincing?</h2>').appendTo($('.page-content'));
    }
  }
}

function insertSubargumentCheckboxes(checkboxesSection, argument) {
  for (subArgument of argument.subArguments) {
    const id = toId(subArgument.name)
    const div = $('<div />', {class: ''}).appendTo(checkboxesSection);
    const effect = subArgument.effect || 'disagree'
    const checked = subArgument.agreement === effect
    $('<input />', {
      type: 'checkbox',
      id: `cb_${id}`,
      'data-url': subArgument.url,
      value: id,
      checked
    }).appendTo(div);
    $('<label />', {
      'for': `cb_${id}`,
      text: subArgument.text || subArgument.name,
    }).appendTo(div);
  }
}

function insertYesNoCheckboxes(checkboxesSection, argument) {
  let div = $('<div />', {class: ''}).appendTo(checkboxesSection);
  $('<input />', {
    type: 'checkbox',
    id: `cb_yes`,
    value: 'yes',
    'data-effect': 'agree',
    'data-url': argument.url,
    checked: argument.agreement === 'agree'
  }).appendTo(div);
  $('<label />', {
    'for': `cb_yes`,
    text: 'Yes',
  }).appendTo(div);

  div = $('<div />', {class: ''}).appendTo(checkboxesSection);
  $('<input />', {
    type: 'checkbox',
    id: `cb_no`,
    value: 'no',
    'data-effect': 'disagree',
    'data-url': argument.url,
    checked: argument.agreement === 'disagree'
  }).appendTo(div);
  $('<label />', {
    'for': `cb_no`,
    text: 'No'
  }).appendTo(div);
}

function insertCheckboxes(argument) {
  const checkboxesSection = $('<ul />', {class: 'nav-answers'}).appendTo($('.page-content'));
  if (argument.subArguments?.length > 0) {
    insertSubargumentCheckboxes(checkboxesSection, argument)
  } else {
    insertYesNoCheckboxes(checkboxesSection, argument)
  }
}

function insertSubargumentLinks(argument) {
  const links = $('<ul />', {class: 'nav-answer-links'}).appendTo($('.page-content'));
  if (argument.subArguments?.length > 0) {
    $('<h2>Want to read more on these topics?</h2>').appendTo(links);
    for (subArgument of argument.subArguments) {
      const id = toId(subArgument.name)
      const visibility = subArgument.agreement === (subArgument.effect || 'disagree')
      const displayStyle = visibility ? 'block' : 'none'
      const link = $(`<a />`, {
        class: 'answer-link',
        style: `display: ${displayStyle}`,
        id: `link_${id}`,
        href: `${window.site_baseurl}` + subArgument.url,
        'data-url': subArgument.url
      }).appendTo(links);
      $('<span />', {html: subArgument.name}).appendTo(link)
    }
    updateLinkSectionVisibility()
  }
}

function insertGoBackLink(argument) {
  const argParent = getArgumentParent(window.argumentPages, argument)
  if (!argParent) return
  
  const link = $(`<a />`, {
    class: 'go-back-link',
    href: `${window.site_baseurl}` + argParent.url,
    'data-url': argParent.url,
    title: argParent.name
  }).appendTo($('.page-content'));
  $('<span />', {html: '➥ Go back'}).appendTo(link)
}

function checkboxChange(event) {
  const label = $(event.currentTarget).parent().find('label')
  const linkId = `link_${
    event.target.id.substr(3)
  }`;
  const linkEl = $(`#${linkId}`)
  if ($(event.target).prop('checked')) {
    linkEl.css('display', 'block')
  } else {
    linkEl.hide()
  }
  updateLinkSectionVisibility()
  const link = $(event.currentTarget)
  const path = `${window.site_baseurl}` + link.data('url')
  let agreement
  if (link.prop('checked')) {
    agreement = link.data('effect')
  } else {
    agreement = 'undecided'
  }

  recordAnswer(link.data('url'), agreement)

  if (event.currentTarget.id === 'cb_no' && $(event.currentTarget).prop('checked')) pulseFeedbackButton()

  label.addClass('pulse')
  window.setTimeout(() => {
    label.removeClass('pulse')
  }, 100)
}

function linkClick(event) {
  event.preventDefault();
  const link = $(event.currentTarget)
  const path = `${window.site_baseurl}` + link.data('url')

  getHtml(path, true, true)
}

function insertAnswerSection(path) {
  const argument = findArgumentByPath(window.argumentPages, path);
  if (!argument) 
    throw `Couldn't find argument for ${path}`;

  hideOldStuff(argument)
  if (argument.noQuestion) return

  insertTitleQuestion(argument)
  insertCheckboxes(argument)
  insertSubargumentLinks(argument)
  insertGoBackLink(argument)

  $('.nav-answers input').on('change', checkboxChange)
  $('.answer-link').on('click', linkClick)
}

function toggleFeedback() {
  $("#feedback").toggle()
}

function pulseFeedbackButton() {
  $('a[href="#feedback"]').addClass('feedback-button-pulsed')
  window.setTimeout(() => {
    $('a[href="#feedback"]').removeClass('feedback-button-pulsed')
  }, 300)
}

function updateLinkSectionVisibility() {
  const visibleLinks = $('a.answer-link').filter((i, a) => $(a).css('display') !== 'none')
  if (visibleLinks.length > 0) {
    $('.nav-answer-links').show()
  } else {
    $('.nav-answer-links').hide()
  }
}

function getHtml(path, saveAddress = true, scrollIntoView = false) {
  html_path = html_asset_path(path)
  $.get(html_path).done(data => {
    $('.page-content').html(data);
    const title = $('.page-content .page-data').data('page-title');
    $('.page-title').html(title);
    insertAnswerSection(path);
    if (saveAddress)
      window.history.pushState({}, "", path);

    if (scrollIntoView)
      $('#argument_section')[0].scrollIntoView();
  })
}

function recordAnswer(url, agreement = null) {
  const fullUrl = `${window.site_baseurl}${url}`
  const argument = findArgumentByPath(window.argumentPages, fullUrl)
  if (argument.agreeTargetUrl) {
    recordAnswer(argument.agreeTargetUrl)
    return
  }
  argument.agreement = agreement || argument.effect || 'disagree'
  if (argument.agreement === 'undecided') argument.agreement = null
  const argumentNode = $(`a[data-url='${fullUrl}']`)
  overrideSiblingsIfNeeded(argument, agreement)
  setNodeAgreement(argumentNode, argument.agreement)
  propagateAgreement(window.argumentPages, argument, argument.agreement)
  saveAnswers()
}

function saveAnswers() {
  let answers = recursiveBuildAnswers(window.argumentPages, {})
  localStorage.setItem('answers', JSON.stringify(answers))
}

function recursiveBuildAnswers(currentArguments, answers) {
  for (const argument of currentArguments) {
    if (argument.agreement)
      answers[argument.url] = argument.agreement
    
    if (argument.subArguments?.length > 0) {
      const foundArg = recursiveBuildAnswers(argument.subArguments, answers)
    }
  }
  return answers
}

function loadAnswers() {
  let answers = JSON.parse(localStorage.getItem('answers'))
  if (!answers) return

  recursiveAttachAnswers(window.argumentPages, answers)
  for (const [url, agreement] of Object.entries(answers)) {
    const fullUrl = `${window.site_baseurl}${url}`
    const argumentNode = $(`a[data-url='${fullUrl}']`)
    if (argumentNode.length == 0) debugger
    setNodeAgreement(argumentNode, agreement)

    const checkbox = $(`input[data-url='${url}']`)
    checkbox.prop('checked', true)
  }
  updateLinkSectionVisibility()
}

function recursiveAttachAnswers(currentArguments, answers) {
  for (const argument of currentArguments) {
    if (answers[argument.url]) {
      argument.agreement = answers[argument.url]
    }
    
    if (argument.subArguments?.length > 0) {
      const foundArg = recursiveAttachAnswers(argument.subArguments, answers)
    }
  }
}

function setNodeAgreement(node, agreement) {
  node.addClass(agreement)
  if (agreement !== 'agree') node.removeClass('agree')
  if (agreement !== 'disagree') node.removeClass('disagree')
}

function getArgumentParent(currentArguments, argumentToFind) {
  for (const argument of currentArguments) {
    if (argument.subArguments?.length > 0) {
      if (argument.subArguments.find((arg) => arg.url === argumentToFind.url))
        return argument

      const argParent = getArgumentParent(argument.subArguments, argumentToFind)
      if (argParent) return argParent;
    }
  }
  return null
}

function getArgumentSiblings(currentArguments, argumentToFind) {
  for (const argument of currentArguments) {
    if (argumentToFind === argument)
      return currentArguments.filter((el) => el !== argumentToFind)

    if (argument.subArguments?.length > 0) {
      const siblings = getArgumentSiblings(argument.subArguments, argumentToFind)
      if (siblings)
        return siblings;
    }
  }
  return null
}

function overrideSiblingsIfNeeded(argument, agreement) {
  if (agreement === 'undecided') return

  if (argument.overrideSiblings) {
    overrideSiblings(argument)
  } else if (!argument.subArguments || argument.subArguments.length === 0) {
    overrideYesNoSibling(argument, agreement)
  }
}

function overrideSiblings(argument) {
  const siblings = getArgumentSiblings(window.argumentPages, argument) || []

  for (sibling of siblings) {
    sibling.agreement = null

    const fullUrl = `${window.site_baseurl}${sibling.url}`
    const argumentNode = $(`a[data-url='${fullUrl}']`)

    setNodeAgreement(argumentNode, sibling.agreement)
    const checkbox = $(`input[data-url='${sibling.url}']`)
    checkbox.prop('checked', false).change()
    updateLinkSectionVisibility()
  }
}

function overrideYesNoSibling(argument, agreement) {
  yesNo = agreement === 'agree' ? 'no' : 'yes'
  const checkbox = $(`input[data-url='${argument.url}'][value=${yesNo}]`)
  if (checkbox.prop('checked')) checkbox.prop('checked', false)
}

// A conflict among siblings is when some are 'agree' and some are 'disagree'
function getSiblingsAgreement(siblings) {
  return siblings.reduce(
    (agreement, argument) => {
      if (agreement === 'conflict') return 'conflict'
      if (agreement === 'agree' && argument.agreement === 'disagree') return 'conflict'
      if (agreement === 'disagree' && argument.agreement === 'agree') return 'conflict'
      return argument.agreement || agreement
    }, 'undecided')
}

// If you agree with a node, it sets the value of its parent node similarly if there are
// no siblings with a different agreement valence.
function propagateAgreement(currentArguments, changedArgument, agreement) {
  for (const argument of currentArguments) {

    if (argument === changedArgument) {
      argument.agreement = agreement
      return true
    }

    if (argument.subArguments?.length > 0) {
      const foundArg = propagateAgreement(argument.subArguments, changedArgument, agreement)
      if (foundArg) {
        const fullUrl = `${window.site_baseurl}${argument.url}`
        const argumentNode = $(`a[data-url='${fullUrl}']`)

        // if there are no conflicts among the siblings, set the parent value and continue propagating,
        // otherwise set the parent value to undecided and then stop.
        const siblingsAgreement = getSiblingsAgreement(argument.subArguments)
        if (siblingsAgreement === 'conflict') {
          if (!argument.overrideSiblings) {
            argument.agreement = 'disagree'
            setNodeAgreement(argumentNode, 'disagree')
          }
          return true
        } else if (siblingsAgreement === 'undecided') {
          argument.agreement = 'undecided'
          setNodeAgreement(argumentNode, null)
          return false
        } else {
          if (argument.overrideSiblings) return true
          if (argument.overrideSiblings && agreement === 'agree') {
            argument.agreement = 'undecided'
            setNodeAgreement(argumentNode, null)
            return true
          }
          argument.agreement = siblingsAgreement
          setNodeAgreement(argumentNode, siblingsAgreement)
          return true
        }
      }
    }
  }
  return false
}

function initPage() {
  loadAnswers()

  $('.top-argument, .argument-shape-link').on('click', (event) => {
    event.preventDefault();
    const path = $(event.currentTarget).data('url');
    getHtml(path, true, true);
  })

  // Because we're messing with the address with window.history.pushState, when the user clicks the Back
  // button, it doesn't cause a page load, so we listen for the popstate event and cause the page load manually.
  window.addEventListener('popstate', function(event) {
    getHtml(window.location.pathname, false)
  });

  getHtml(window.location.pathname);

  $('a[href="#feedback"]').on('click', () => {
    toggleFeedback();
    window.setTimeout(() => {
      window.history.replaceState({}, '', window.url);
    },1)
  })

  if (window.location.host === 'localhost:4000' || window.location.host === '127.0.0.1:4000') {
    console.log(argNodeHistory);
  }

  Cognito.prefill({
    "CurrentURL": window.location.pathname,
    "NodeHistory": argNodeHistory.join(', '),
    "LandingPath": localStorage.getItem('LandingPath'),
    "sParam": localStorage.getItem('sParam'),
    "Referrer": localStorage.getItem('Referrer')
  });
}
