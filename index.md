---
title: Home
layout: new_home
description: Reducing risks from advanced AI through field-building activities

featured_image: /assets/img/social.jpg
---

<section id="banner" class="major">
  <div class="arkose-banner" style="background-image: url('{{ '/assets/images/arkose-banner.jpg' | relative_url }}')"></div>
  <div class="row xs-padding-1 banner-inner">
    <div class="10u -2u -1u(large) 11u(large)">
      <h1 class="display-1">Arkose</h1>
      <p class="subheading">Reducing risks from advanced AI through field-building activities</p>
    </div>
    <div class="12u -2u -1u(large) 11u(large) banner-button-container">
      <a href="/apply" class="banner-button">
        Apply for advising
      </a>
    </div>
  </div>
</section>

<div class="section">
  <div class="inner">
    <div class="row align-items-center">
      <div>
        <p>Arkose is an early-stage, field-building nonprofit with the mission of improving the safety of advanced AI systems. At Arkose, our primary organizational focus is supporting researchers, engineers, and other professionals interested in contributing to technical AI safety research. Our approach encompasses a range of activities, with the following core elements:</p>

        <ul>
        <li>Hosting calls and other support programs that provide<b> connections, mentorship, resources, and tailored guidance</b> to researchers, engineers, and others with relevant skill sets to facilitate their engagement in AI safety technical research. Machine learning professionals are invited to <a href="apply">apply for an Arkose Consultation Call</a>.</li>
        <li>Advancing understanding of AI safety research and opportunities via <b>outreach</b> and <b>curating educational resources</b>. See our <a href="resources">Resource Center</a>, which is periodically reviewed by an <a href="experts">advisory panel of experts</a> in the field.</li>
        </ul>

        <p>Our older 2022 work aimed to facilitate discussion and evaluation of potential risks from advanced AI, with a focus on soliciting and engaging with expert perspectives on the arguments and providing resources for stakeholders. Our results, based on a set of 97 interviews with AI researchers on their perspectives on current AI and the future of AI (pre-ChatGPT era), can be found at <a href="ai-risk-discussions">AI Risk Discussions</a>.</p>

        {% if false %}
	    <h4><a href="https://airtable.com/shr4RFKRUUfQRK15V">We're Hiring!</a></h4>
	    <p>Arkose is looking for an <b>Operations Lead</b> to work on day-to-day operations along with other projects. If you’re interested, you can <a href="operations-lead">apply for the Operations Lead position here</a>!</p>

	    <p>If you're interested in contributing to Arkose but do not think the above role is a good fit, feel free to email <a href="mailto:info@arkose.org">info@arkose.org</a> with an expression of interest.</p>
	    {% endif %}

      </div>
    </div>
  </div>
</div>

<div class="section bg-gray">
  <div class="inner">
    {% assign cards = site.advisors %}
    {% assign advisors1 = cards | where: "section", "strategic" | sort: 'order' %}
    {% assign advisors2 = cards | where: "section", "selected" | sort: 'order' %}

    <h2>Strategic Advisory Panel</h2>

    <p>Strategic advisory panel members advise on Arkose's suggested resources, recommendations, and strategic direction.</p>

    <div class="cards">
      {% for card in advisors1 %}
        {% include person_card.html card=card %}
      {% endfor %}
    </div>

    <h2>Selected Experts</h2>

    <p>Experts generously lend their knowledge and time to Arkose's pairing program, providing one-on-one support to researchers and engineers interested in contributing to technical AI safety.</p>

    <div class="cards">
      {% for card in advisors2 %}
        {% include person_card.html card=card %}
      {% endfor %}
    </div>
  </div>
</div>

<div class="section">
  <div class="inner">
    <h3>About the Team</h3>
    <div class="cards">
      <a href="https://vaelgates.com">
        <div class="card card-team">
          <div class="card-thumbnail">
            <img src="/assets/images/people/vael-gates.jpg">
          </div>
          <div class="card-content">
            <div class="card-title">
              <h3>Dr. Vael Gates</h3>
            </div>
            <div class="card-description">Founder</div>
          </div>
        </div>
      </a>
      <a href="https://www.linkedin.com/in/zacharythomas10/">
        <div class="card card-team">
          <div class="card-thumbnail">
            <img src="/assets/images/people/zachary-thomas.jpg">
          </div>
          <div class="card-content">
            <div class="card-title">
              <h3>Zachary Thomas</h3>
            </div>
            <div class="card-description">Operations</div>
          </div>
        </div>
      </a>
      <a href="https://www.linkedin.com/in/audrazook/">
        <div class="card card-team">
          <div class="card-thumbnail">
            <img src="/assets/images/people/audra-zook.jpg">
          </div>
          <div class="card-content">
            <div class="card-title">
              <h3>Audra Zook</h3>
            </div>
            <div class="card-description">Operations</div>
          </div>
        </div>
      </a>
    </div>
  </div>
</div>
