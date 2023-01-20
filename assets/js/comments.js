/* eslint-env jquery */

import { listArgumentUrls, airddataUrl, findArgumentByPath } from './common.js'

function urlToTitle(url) {
  const arg = findArgumentByPath(window.argumentPages, '/perspectives/' + url)
  if (arg) {
    return arg.name
  } else {
    "Error: Couldn't find title"
  }
}

function sortCommentsByPage(comments) {
  const urlList = listArgumentUrls()
  return comments.sort((c1, c2) => {
    return (urlList.indexOf(c1.url) > urlList.indexOf(c2.url) ? 1 : -1)
  })
}

$(() => {
  fetch(airddataUrl('comments', 'GET'), {
    method: 'GET',
  })
  .then(response => response.json())
  .then(comments => {
    comments = sortCommentsByPage(comments)
    const commentsDiv = $('<div />')
    let previousUrl = ''
    comments.forEach(comment => {
      const div = $('<div class="comment" />')
      if (comment['url'] !== previousUrl) {
        const title = urlToTitle(comment['url'])
        $(`<h3><a href="perspectives/${comment['url']}">${title}</a></h3>`).appendTo(div)
        previousUrl = comment['url']
      }
      $(`<p>${comment['text'].replace('\n', '<br />')}</p>`).appendTo(div)
      div.appendTo(commentsDiv)
    })
    commentsDiv.appendTo($('#main .inner'))
  })
})
