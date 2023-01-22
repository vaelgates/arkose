/* eslint-env jquery */

import { airddataUrl, handleFormButtonError, transitionless } from './common.js'

function checkRequiredElements(...elements) {
  let missingEls = []
  for (const el of elements) {
    if (!el.val() || el.val() === '') {
      missingEls.push(el)
      el.addClass('required-missing')
    } else {
      el.removeClass('required-missing')
    }
  }
  return missingEls
}

$("#book_call_form").on('submit', () => {
  const formButton = $("#send_form_button")
  const buttonProgress = formButton.find('.button-progress-bar')
  const missingEls = checkRequiredElements(
    $('#name'),
    $('#email'),
    $('#interest'),
    $('#message')
  )
  if (missingEls.length > 0) {
    return false
  }
  transitionless(buttonProgress, () => {
    buttonProgress.removeClass(['sending', 'sent', 'error'])
  }, () => {
    buttonProgress.addClass('sending')

    fetch(airddataUrl('book_call', 'POST'), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        name: $("#name").val(),
        email: $("#email").val(),
        interest: $("#interest").val(),
        message: $("#message").val()
      })
    }).then((response) => {
      if (!response.ok) throw Error(response.statusText);
    }).then(() => {
      buttonProgress.removeClass('sending')
      buttonProgress.addClass('sent')
      $(".error-message").hide()
      window.setTimeout(() => {
        const originalWidth = formButton.outerWidth()
        formButton.css('width', String(originalWidth) + 'px')
        formButton.find('.button-text').html('Sent')
        buttonProgress.addClass('pulse')
        window.setTimeout(() => {
          buttonProgress.removeClass('pulse')
        }, 250)
      }, 200)
    }).catch(() => {
      handleFormButtonError(formButton, `An error occurred when sending the message. Please instead use the contact email (<a href="mailto:${window.contactEmail}">${window.contactEmail}</a>).`)
    })
  })
  return false;
})
