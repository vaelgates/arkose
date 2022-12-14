{% assign decoded_page_url = argument.url | url_decode %}
{
  name: `{{argument.name}}`,
  text: `{{argument.text}}`,
  url: `{{decoded_page_url}}`,
  {% if argument.effect != nil %}effect : `{{argument.effect}}`,{% endif -%}
  {% if argument.agreeTargetUrl != nil %}agreeTargetUrl : `{{argument.agreeTargetUrl}}`,{% endif -%}
  {% if argument.noQuestion != nil %}noQuestion : `{{argument.noQuestion}}`,{% endif -%}
  {% if argument.overrideSiblings != nil %}overrideSiblings : {{argument.overrideSiblings}},{% endif -%}
  {% if argument.listInTree != nil %}listInTree : `{{argument.listInTree}}`,{% endif -%}
  {% if argument.question != nil %}question : `{{argument.question}}`,{% endif -%}
  {% assign len = argument.pages | size %}
  {% if len > 0 %}subArguments: [
    {% for argument in argument.pages %}{% include argument_page.js %}{% endfor %}
  ]{% endif -%}
},