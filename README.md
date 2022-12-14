# AIRD website

A Jekyll-based website based on the Forty Jekyll theme by HTML5 UP. To run it, clone the git repo, run `bundle install` to install the gems*, then `jekyll serve` to run the server, and then it'll be available at localhost:4000.

*If `bundle install` fails, try `gem install bundler`. If that fails, install Ruby and try again. If none of that works, idk, ask ChatGPT.

# Arguments

In the arguments section, people are asked their views on arguments for AI x-risk Each page ends with checkboxes whether they agree or they disagree with that page's claims, and for what reasons. When they check a box, they're shown a link to further arguments addressing their concerns.

Metadata about the arguments is stored in `_data/arguments.yml`, which is explained further below.

The content for arguments is stored as Jekyll pages in `/arguments/`. The argument system actually loads the arguments with AJAX calls, not requiring a page load when new arguments are loaded, and for this reason the HTML of the arguments is *also* kept as files in `/assets/html/arguments/`. Arguments in the latter place should not be edited directly! The Jekyll pages in `/arguments/` are the canonical versions of the argument pages, so update them there, then run the Ruby script `/tools/move_arguments.rb`, which copies the HTML (also interpreting some Jekyll variables) to the /assets/html/arguments/ directory.

(Why this complicated system? It's primarily to keep the argument tree visualization from flickering between page loads. Because we're using Jekyll, not a server, the user's agreements/disagreements with the arguments are kept in the browser. When the page is initially loaded, the argument tree can't already be colored correctly to indicate the user's choices, because the server sending the HTML doesn't know what the user chose. So we fill out the choices immediately after the page loads the first time, and all subsequent navigation only reloads the content of the page, without reloading the argument tree section. This is weird and complicated, but it solves the flickering and incidentally makes pages load faster.)

## The arguments YAML format

 This argument system relies on _data/arguments.yml, which lists arguments as follows:

**name**: string (required). The title that will display as the heading of the page, and in the listing in the argument tree, e.g. "AI cannot be conscious".
**text**: string (optional? but we probably want it for every argument because the default is to duplicate the **name**). The text that should display in the checkbox item for this argument, which will be similar to the title, but phrased as the answer to a question about whether the user agrees, e.g. "No – AI cannot be conscious in the way a human is". If it's not supplied, the name will be used instead.
**url**: string (required). The URL of the argument, e.g. "/arguments/consciousness" (note that it shouldn't end with ".html")
**effect**: 'agree'|'disagree' (optional, default 'disagree'). This sets whether clicking the checkbox represents disagreement or agreement, which affects, among other things, the visualization color (red or green).
**question**: string (optional? but we probably want it for every argument because the default is probably worse). The question that should be asked at the bottom of the page, above the checkboxes, e.g. 'Do you agree that biology is probably not essential for general intelligence?'. If it's not supplied, it defaults to "Do you find the above arguments convincing?".
**noQuestion**: boolean (optional, default false). Set this to true if this page shouldn't ask a question at the bottom (like the 'Within 50 Years' page, which exists to briefly acknowledge the user's agreement and redirect them to the next section).
**overrideSiblings**: boolean (optional, default false). Set this to true if agreeing with this argument should automatically un-set its sibling arguments. This is used for the question about when AGI will exist, where the three options ("Within 50 years", "More than 50 years", and "Never") are mutually exclusive.
**listInTree**: boolean (optional, default true). Set this to false if the argument should appear in the checkbox list under a parent argument, but *shouldn't* be listed in the argument tree visualization. This is used for the final checkbox on the "Never" page, where we want to list a checkbox the user can click, but it doesn't lead to a page of counter-arguments.
**subArguments**: a list of argument pages that descend from this one (optional). If supplied, they'll be displayed as checkbox options at the bottom of the argument page content. If they're not supplied, Yes/No checkboxes will be shown instead.

It should look a bit like this:
```
- page:
  name: Generally capable AI systems
  url: /arguments/when-agi
  question: When do you think these generally capable systems will exist?
  pages:
    - page:
      name: Within 50 Years
      url: /arguments/within-50-years
      effect: agree
      overrideSiblings: true
      noQuestion: true
    - page:
      name: More than 50 years
      url: /arguments/more-than-50-years
      question: Would you like to hear these arguments?
      overrideSiblings: true
      pages:
        - page:
          text: Yes, I would like to hear these arguments for why AGI might come soon
          name: Why these systems might come soon
          url: /arguments/agisooner
        - page:
          text: No, let’s move on - I want to learn about potential risks
          name: Moving on to potential risks
          url: /arguments/goto-potential-risk
    - page:
      name: Never
      url: /arguments/never
      question: Would you agree that there might be such generally capable systems at some time in the future?
      overrideSiblings: true
      pages:
        - page:
          name: There is something special about biology
          text: No – there is something special about biology which we will never be able to put into machines
          url: /arguments/biology-special
          question: Do you agree that biology is probably not essential for general intelligence?
        - page:
          name: Intelligent Machines - seems weird
          text: No – truly intelligent machines - that seems really weird
          url: /arguments/seems-weird
...
```


The original README for the Jekyll Forty theme continues below:
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
