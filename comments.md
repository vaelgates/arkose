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
  window.argumentPages = [{% for argument in site.data.arguments %}
    {% include argument_node.js %}
  {% endfor %}]
</script>
<script src="{{ "assets/js/comments.js" | absolute_url }}" type="module"></script>
