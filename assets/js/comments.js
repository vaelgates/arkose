/* eslint-env jquery */

function findArgumentByPath(searchArguments, path) {
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
  console.error(`Couldn't find argument for path '${path}'`)
  return null
}

function airddataUrl(dataType, method) {
  let suffix = ''
  if (method === 'GET') {
    suffix = '/json'
  }
  if (window.location.host === 'localhost:4000') {
    return `http://localhost:4567/${dataType}${suffix}`
  } else {
    return `https://aird.michaelkeenan.net/${dataType}${suffix}`
  }
}

function urlToTitle(url) {
  const arg = findArgumentByPath(window.argumentPages, '/perspectives/' + url)
  if (arg) {
    return arg.name
  } else {
    "Error: Couldn't find title"
  }
}

$(() => {
  fetch(airddataUrl('comments', 'GET'), {
    method: 'GET',
  })
  .then(response => response.json())
  .then(comments => {
  
    const commentsDiv = $('<div />')
    comments.forEach(comment => {
      const div = $('<div class="comment" />')
      const title = urlToTitle(comment['url'])
      $(`<p><strong>${title}</strong></p>`).appendTo(div)
      $(`<p>${comment['text'].replace('\n', '<br />')}</p>`).appendTo(div)
      div.appendTo(commentsDiv)
    })
    commentsDiv.appendTo($('#main .inner'))
  })
})
