/* eslint-disable */

{% assign decoded_page_url = argument.url | url_decode %}
{
  name: `{{argument.name}}`,
  text: `{{argument.text}}`,
  url: `{{decoded_page_url}}`,
  {% if argument.linkName != nil %}linkName : `{{argument.linkName}}`,{% endif -%}
  {% if argument.effect != nil %}effect : `{{argument.effect}}`,{% endif -%}
  {% if argument.answerLinkUrl != nil %}answerLinkUrl : `{{argument.answerLinkUrl}}`,{% endif -%}
  {% if argument.nodeLinkUrl != nil %}nodeLinkUrl : `{{argument.nodeLinkUrl}}`,{% endif -%}
  {% if argument.agreeTargetUrl != nil %}agreeTargetUrl : `{{argument.agreeTargetUrl}}`,{% endif -%}
  {% if argument.askQuestion != nil %}askQuestion : `{{argument.askQuestion}}`,{% endif -%}
  {% if argument.overridesSiblings != nil %}overridesSiblings : {{argument.overridesSiblings}},{% endif -%}
  {% if argument.listInTree != nil %}listInTree : {{argument.listInTree}},{% endif -%}
  {% if argument.question != nil %}question : `{{argument.question}}`,{% endif -%}
  {% if argument.isCheckboxOption != nil %}isCheckboxOption : {{argument.isCheckboxOption}},{% endif -%}
  {% if argument.delegateCheckboxes != nil %}delegateCheckboxes : {{argument.delegateCheckboxes}},{% endif -%}
  {% assign len = argument.nodes | size %}
  {% if len > 0 %}subArguments: [
    {% for argument in argument.nodes %}{% include argument_node.js %}{% endfor %}
  ]{% endif -%}
},