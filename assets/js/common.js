/* returns the argument URLs in a list, ordered depth-first order as they are in the TOC */
export function listArgumentUrls() {
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

export function html_asset_path(path) {
  const path_parts = path.match(/(\/${window.site_baseurl}\/)(.*)/);
  if (path_parts) {
    return `${
      path_parts[1]
    }assets/html/${
      path_parts[2]
    }`
  } else {
    return `/assets/html/${path}`
  }
  // if (!path_parts || path_parts.length < 3)
  //   throw `path mismatch for ${path}`
}

export function airddataUrl(dataType, method) {
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

export function findArgumentByPath(searchArguments, path) {
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
