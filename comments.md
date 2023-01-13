---
layout: page
title: Comments
image: assets/images/pic01.jpg
nav-menu: false
---

<!-- Main -->
<div id="main" class="alt">

<!-- One -->
<section id="one">
	<div class="inner">
		<header class="major">
			<h1>Comments</h1>
		</header>
		
	</div>
</section>
</div>

<script>

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

  function titleize(s) {
    s = s.replace(/-/g, ' ')

    const arr = s.split(" ");

    for (var i = 0; i < arr.length; i++) {
      arr[i] = arr[i].charAt(0).toUpperCase() + arr[i].slice(1);
    }

    return arr.join(' ')
  }

  fetch(airddataUrl('comments', 'GET'), {
    method: 'GET',
  })
  .then(response => response.json())
  .then(comments => {
    console.log({comments})

    const commentsDiv = $('<div />')
    comments.forEach(comment => {
      const div = $('<div class="comment" />')
      const title = titleize(comment['url'])
      $(`<p><strong>${title}</strong></p>`).appendTo(div)
      $(`<p>${comment['text']}</p>`).appendTo(div)
      div.appendTo(commentsDiv)
    })
    commentsDiv.appendTo($('#main .inner'))
  })
</script>