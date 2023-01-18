/* eslint-env jquery */

/* returns the argument URLs in a list, in order, for use when sorting comments by page */
function listArgumentUrls() {
  let argumentsList = []
  let queue = [...window.argumentPages]
  while (queue.length > 0) {
    const argument = queue.shift()
    argumentsList.push(argument.url.split('/')[2])
    if (argument.subArguments?.length > 0) {
      queue = argument.subArguments.concat(queue)
    }
  }
  return argumentsList
}

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
