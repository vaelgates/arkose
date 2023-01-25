# AIRD website

A Jekyll-based website based on the Forty Jekyll theme by HTML5 UP. To run it, clone the git repo, run `bundle install` to install the gems*, then `jekyll serve` to run the server, and then it'll be available at localhost:4000.

*If `bundle install` fails, try `gem install bundler`. If that fails, install Ruby and try again. If none of that works, idk, ask ChatGPT.

# Arguments

In the arguments section, people are asked their views on arguments for AI x-risk. Each page ends with checkboxes for choosing whether they agree or they disagree with that page's claims, and for what reasons. When they check a box, they're shown a link to further arguments addressing their concerns.

Metadata about the arguments is stored in `_data/arguments.yml`, which is explained further below.

The content for arguments is stored as Jekyll pages in `/arguments/`. The argument system actually loads the arguments with AJAX calls, not requiring a page load when new arguments are loaded, and for this reason the HTML of the arguments is *also* kept as files in `/assets/html/arguments/`. Arguments in the latter place should not be edited directly! The Jekyll pages in `/arguments/` are the canonical versions of the argument pages, so update them there, then run the Ruby script `/tools/move_arguments.rb`, which copies the HTML (also interpreting some Jekyll variables) to the /assets/html/arguments/ directory.

(Why this complicated system? It's primarily to keep the argument tree visualization from flickering between page loads. Because we're using Jekyll, not a server, the user's agreements/disagreements are kept in the browser. When the page is initially loaded, the argument tree can't already be colored correctly to indicate the user's choices, because the server sending the HTML doesn't know what the user chose. So we fill out the choices immediately after the page loads the first time, and all subsequent navigation only reloads the content of the page, without reloading the argument tree section. This solves the flickering and incidentally makes pages load faster.)

## The arguments YAML format

This argument system relies on _data/arguments.yml, which provides the data structure for *argument nodes*.

Argument nodes can represent one or more of:
* A page you can navigate to,
* An item in the argument tree visualization that displays at the top of the page,
* A checkbox you can select at the bottom of a page to record your agreement/disagreement with an argument.

Most nodes are all three. However, some nodes just represent an item of the argument tree (e.g. Alignment Problem/Agree, which is an item in the argument tree but doesn't have a corresponding page), and some nodes just represent a checkbox option but not a page nor an item in the argument tree (e.g. Generally Capable AI systems/Never/Yes, I agree).

The following options are complicated. It might help to first list the main cases, and which options are needed for each.

**Top-level page**: name, url, effect (set to 'calculated'), question, nodes.

**Regular leaf page arguing against an objection**: name, url, text, question (optional).

**A checkbox option that shouldn't be listed in the argument tree**: name, text, effect, answerLinkUrl, agreeTargetUrl, listInTree

**A 'Disagree' node that 'delegates' its checkbox sub-nodes to its parent**: name, effect, nodeLinkUrl, isCheckboxOption, delegateCheckboxes

**An 'Agree' node that leads you to the next top-level argument**: name, linkName, text, effect, nodeLinkUrl, agreeTargetUrl, answerLinkUrl

**Nodes that should be shown as buttons rather than checkboxes**: name, url, text, propagateAgreement, parentListingType

These are all the available options:

**name**: string (required). The title that will display as the heading of the page, and in the listing in the argument tree, e.g. "AI cannot be conscious", and as the text of the link to that page that appears when you select its corresponding checkbox.

**url**: string (optional). The URL of the argument, e.g. "/arguments/consciousness" (note that it shouldn't end with ".html"). This should be specified when the node represents a page that you can navigate to.

**text**: string (optional). The text that should display in the checkbox item for this argument, which will be similar to the title, but phrased as the answer to a question about whether the user agrees, e.g. "No – AI cannot be conscious in the way a human is". If it's not supplied, the name will be used instead.

**effect**: 'agree'|'disagree'|'calculated'|'undecidedOverride' (optional, default 'disagree'). This determines what it means to agree with this node, when clicked as a checkbox ('agree'|'disagree'). Agree/Disagree effects might be propagated to parent nodes, depending on other options. Top-level arguments (Generally Capable AI Systems, The Alignment Problem, etc.) should be set to 'calculated', which will cause the node's agreement state to be determined by its sub-nodes. There's also one 'undecidedOverride' special case (possibly to be renamed later), for setting the agreement state back to 'undecided' (i.e. default gray), currently used only for the agreement checkbox on the Generally Capable AI Systems/Never page, which sets its parent 'Never' node to undecided.

**question**: string (optional). The question that should be asked at the bottom of the page, above the checkboxes, e.g. 'Do you agree that biology is probably not essential for general intelligence?'. If it's not supplied, it defaults to "Do you think the reasoning above is valid?".

**askQuestion**: boolean (optional, default true). Set this to false if this page shouldn't ask a question at the bottom (like the 'Within 50 Years' page, which exists to briefly acknowledge the user's agreement and redirect them to the next section).

**overridesSiblings**: boolean (optional, default false). Set this to true if agreeing with this argument should automatically un-set its sibling arguments. One place this is used is for the question about when AGI will exist, where the three options ("Within 50 years", "More than 50 years", and "Never") are mutually exclusive.

**listInTree**: boolean (optional, default true). Set this to false if the argument shouldn't be listed in the argument tree visualization. This is used for the 'Agree' checkbox on the "Never" page, where we want to list a checkbox the user can click, but it doesn't lead to a page of counter-arguments.

**nodes**: (list, optional). A list of nodes that descend from this one (optional). If supplied, they'll be displayed as checkbox options at the bottom of the argument page content (unless their `isCheckboxOption` parameter is set to false). If no nodes are supplied, Yes/No checkboxes will be shown instead (unless `askQuestion` is set to false).

**propagateAgreement**: boolean (optional, default true). Determines whether selecting this node's checkbox affects the parent's agreement state. Usually this is desirable, but not for Generally Capable AI Systems/More Than 50 Years/Why These Systems Might Come Soon, where disagreeing with that shouldn't affect agreement with More Than 50 Years.

**parentListingType**: 'checkbox'|'button' (optional, default 'checkbox'). Determines whether the parent node displays this nodes as a checkbox or a button. Currently, only the nodes under Generally Capable AI Systems/More Than 50 Years are buttons.

**linkName**: (string, optional). When you check a checkbox, a link usually appears below so you can learn more about the topic. The text of the link is usually the `name` of the node, but you can override that by setting `linkName`. This is used for 'Agree' checkboxes under top-level arguments that display links to the next top-level argument page.

**delegateCheckboxes**: boolean (optional, default false). Usually, a node's sub-nodes are listed as checkboxes on the node's page. On most top-level argument pages (The Alignment Problem, Instrumental Incentives, etc.), the argument map shows two subnodes (Agree and Disagree), but we want to list all the disagreement options on the main page. Set delegateCheckboxes to true to make the sub-node's sub-nodes be listed on the parent's page. (Currently, this is always used with the `isCheckboxOption` setting, and should possibly be combined with it.)

**isCheckboxOption**: boolean (optional, default true). Usually a node's sub-nodes should be listed as checkboxes on the node's page. On most top-level argument pages (The Alignment Problem, Instrumental Incentives, etc.), the argument map shows two subnodes (Agree and Disagree), but the Disagree node isn't actually a selectable checkbox node (its sub-nodes are delegated as checkboxes instead with the `delegateCheckboxes`). So set `isCheckboxOption` to false to make a node not be listed as a checkbox on its parent page.

**nodeLinkUrl**: string (optional). What URL to navigate to if the user clicks on this node in the argument map. (Use this when the node has no `url` because it doesn't correspond to a page.)

**agreeTargetUrl**: (string, optional). Usually, a node's checkbox affects the agreement state of its URL, whether you click it on its parent page (e.g. clicking "We would test it before deploying" on "The Alignment Problem" main page) or on its own page (e.g. clicking "Yes" or "No" on the checkboxes at the end of the "We would test before deploying" page). When a node doesn't directly represent a page (e.g. the Agree node under The Alignment Problem, which represents a checkbox and an item node but isn't a page you can navigate to), set the `agreeTargetUrl` to the `url` of the node the agreement effect should be applied to.

**answerLinkUrl**: (string, optional). In most cases, a page's sub-nodes represent pages you can navigate to when you select their corresponding checkbox. When a node doesn't directly represent a page (e.g. the Agree node under The Alignment Problem, which represents a checkbox and an item node but isn't a page you can navigate to), set the `answerLinkUrl` to the URL that should be listed as a link for the user to navigate to when the checkbox is selected.

It should look a bit like this:
```
- node:
  name: Generally capable AI systems
  url: /arguments/when-agi
  effect: calculated
  question: When do you think these generally capable systems will exist?
  nodes:
    - node:
      name: Within 50 Years
      url: /arguments/within-50-years
      effect: agree
      overridesSiblings: true
      askQuestion: false
    - node:
      name: More than 50 years
      url: /arguments/more-than-50-years
      effect: agree
      question: Would you like to hear these arguments?
      overridesSiblings: true
      nodes:
        - node:
          name: Why these systems might come soon
          text: Yes, I would like to hear these arguments for why AGI might come soon
          propagateAgreement: false
          url: /arguments/agisooner
          parentListingType: button
        - node:
          name: Moving on to potential risks
          text: No, let’s move on - I want to learn about potential risks
          url: /arguments/goto-potential-risk
          parentListingType: button
          askQuestion: false
    - node:
      name: Never
      url: /arguments/never
      question: Would you agree that there might be such generally capable systems at some time in the future?
      overridesSiblings: true
      nodes:
        - node:
          name: The Alignment Problem
          text: Yes, I agree there might be such generally capable systems at some time in the future (move on to potential risks from AI).
          effect: undecidedOverride
          answerLinkUrl: /arguments/the-alignment-problem
          agreeTargetUrl: /arguments/never
          listInTree: false
        - node:
          name: There is something special about biology
          text: No – there is something special about biology which we will never be able to put into machines
          url: /arguments/biology-special
          question: Do you agree that biology is probably not essential for general intelligence?
...
```

# On the Jekyll version

We use Jekyll 3.9.2 rather than the latest Jekyll (currently 4.3.2), because we’re running on GitHub Pages, which uses Jekyll 3.9.2. The later versions of Jekyll handle URLs a little differently, which can lead to problems in when running locally. The AIRD project has a Gemfile to control the versions of its libraries, so run `bundle install` in your aird directory, and it should install the right version of Jekyll for you. If that doesn’t work, try `gem install bundler`, and then run `bundle install` again.


**The original README for the Jekyll Forty theme continues below:**
# Forty - Jekyll Theme

A Jekyll version of the "Forty" theme by [HTML5 UP](https://html5up.net/).  

![Forty Theme](assets/images/forty.jpg "Forty Theme")

# How to Use

For those unfamiliar with how Jekyll works, check out [jekyllrb.com](https://jekyllrb.com/) for all the details, 
or read up on just the basics of [front matter](https://jekyllrb.com/docs/frontmatter/), [writing posts](https://jekyllrb.com/docs/posts/), 
and [creating pages](https://jekyllrb.com/docs/pages/).

Simply fork this repository and start editing the `_config.yml` file!

> NOTE: GitHub Actions is required to deploy to GitHub Pages because GitHub [refuses to update their version of Jekyll](https://github.com/github/pages-gem/issues/651).

# Added Features

* **[Formspree.io](https://formspree.io/) contact form integration** - just add your email to the `_config.yml` and it works!
* Use `_config.yml` to **set whether the homepage tiles should pull pages or posts**, as well as how many to display.
* Add your **social profiles** easily in `_config.yml`. Only social profiles buttons you enter in `config.yml` show up on the site footer!
* Set **featured images** in front matter.

# Credits

Original README from HTML5 UP:

```
Forty by HTML5 UP
html5up.net | @ajlkn
Free for personal and commercial use under the CCA 3.0 license (html5up.net/license)


This is Forty, my latest and greatest addition to HTML5 UP and, per its incredibly
creative name, my 40th (woohoo)! It's built around a grid of "image tiles" that are
set up to smoothly transition to secondary landing pages (for which a separate page
template is provided), and includes a number of neat effects (check out the menu!),
extra features, and all the usual stuff you'd expect. Hope you dig it!

Demo images* courtesy of Unsplash, a radtastic collection of CC0 (public domain) images
you can use for pretty much whatever.

(* = not included)

AJ
aj@lkn.io | @ajlkn


Credits:

	Demo Images:
		Unsplash (unsplash.com)

	Icons:
		Font Awesome (fortawesome.github.com/Font-Awesome)

	Other:
		jQuery (jquery.com)
		html5shiv.js (@afarkas @jdalton @jon_neal @rem)
		background-size polyfill (github.com/louisremi)
		Misc. Sass functions (@HugoGiraudel)
		Respond.js (j.mp/respondjs)
		Skel (skel.io)
```

Repository [Jekyll logo](https://github.com/jekyll/brand) icon licensed under a [Creative Commons Attribution 4.0 International License](http://choosealicense.com/licenses/cc-by-4.0/).
