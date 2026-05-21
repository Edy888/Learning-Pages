// Simple numbering for non-book documents
#let equation-numbering = "(1)"
#let callout-numbering = "1"
#let subfloat-numbering(n-super, subfloat-idx) = {
  numbering("1a", n-super, subfloat-idx)
}

// Theorem configuration for theorion
// Simple numbering for non-book documents (no heading inheritance)
#let theorem-inherited-levels = 0

// Theorem numbering format (can be overridden by extensions for appendix support)
// This function returns the numbering pattern to use
#let theorem-numbering(loc) = "1.1"

// Default theorem render function
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  if full-title != "" and full-title != auto and full-title != none {
    strong[#full-title.]
    h(0.5em)
  }
  body
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}




// This function gets your whole document as its `body` and formats
// it as an article in the style of the IEEE.
#let ieee(
  // The paper's title.
  title: "Paper Title",

  // An array of authors. For each author you can specify a name,
  // department, organization, location, and email. Everything but
  // but the name is optional.
  authors: (),

  // The paper's abstract. Can be omitted if you don't have one.
  abstract: none,

  // A list of index terms to display after the abstract.
  index-terms: (),

  // The article's paper size. Also affects the margins.
  paper-size: "us-letter",

  // The path to a bibliography file if you want to cite some external
  // works.
  bibliography-file: none,

  // The paper's content.
  body
) = {
  // Set document metadata.
  set document(title: title, author: authors.map(author => author.name))

  // Set the body font.
  set text(font: "STIX Two Text", size: 10pt)

  // Configure the page.
  set page(
    paper: paper-size,
    // The margins depend on the paper size.
    margin: if paper-size == "a4" {
      (x: 41.5pt, top: 80.51pt, bottom: 89.51pt)
    } else {
      (
        x: (50pt / 216mm) * 100%,
        top: (55pt / 279mm) * 100%,
        bottom: (64pt / 279mm) * 100%,
      )
    }
  )

  // Configure equation numbering and spacing.
  set math.equation(numbering: "(1)")
  show math.equation: set block(spacing: 0.65em)

  // Configure lists.
  set enum(indent: 10pt, body-indent: 9pt)
  set list(indent: 10pt, body-indent: 9pt)

  // Configure headings.
  set heading(numbering: "I.A.1.")
  show heading: it => locate(loc => {
    // Find out the final number of the heading counter.
    let levels = counter(heading).at(loc)
    let deepest = if levels != () {
      levels.last()
    } else {
      1
    }

    set text(10pt, weight: 400)
    if it.level == 1 [
      // First-level headings are centered smallcaps.
      // We don't want to number of the acknowledgment section.
      #let is-ack = it.body in ([Acknowledgment], [Acknowledgement])
      #set align(center)
      #set text(if is-ack { 10pt } else { 12pt })
      #show: smallcaps
      #v(20pt, weak: true)
      #if it.numbering != none and not is-ack {
        numbering("I.", deepest)
        h(7pt, weak: true)
      }
      #it.body
      #v(13.75pt, weak: true)
    ] else if it.level == 2 [
      // Second-level headings are run-ins.
      #set par(first-line-indent: 0pt)
      #set text(style: "italic")
      #v(10pt, weak: true)
      #if it.numbering != none {
        numbering("A.", deepest)
        h(7pt, weak: true)
      }
      #it.body
      #v(10pt, weak: true)
    ] else [
      // Third level headings are run-ins too, but different.
      #if it.level == 3 {
        numbering("1)", deepest)
        [ ]
      }
      _#(it.body):_
    ]
  })

  // Display the paper's title.
  v(3pt, weak: true)
  align(center, text(18pt, title))
  v(8.35mm, weak: true)

  // Display the authors list.
  for i in range(calc.ceil(authors.len() / 3)) {
    let end = calc.min((i + 1) * 3, authors.len())
    let is-last = authors.len() == end
    let slice = authors.slice(i * 3, end)
    grid(
      columns: slice.len() * (1fr,),
      gutter: 12pt,
      ..slice.map(author => align(center, {
        text(12pt, author.name)
        if "department" in author [
          \ #emph(author.department)
        ]
        if "organization" in author [
          \ #emph(author.organization)
        ]
        if "location" in author [
          \ #author.location
        ]
        if "email" in author [
          \ #link("mailto:" + author.email)
        ]
      }))
    )

    if not is-last {
      v(16pt, weak: true)
    }
  }
  v(40pt, weak: true)

  // Start two column mode and configure paragraph properties.
  show: columns.with(2, gutter: 12pt)
  set par(justify: true, first-line-indent: 1em)
  show par: set block(spacing: 0.65em)

  // Display abstract and index terms.
  if abstract != none [
    #set text(weight: 700)
    #h(1em) _Abstract_---#abstract

    #if index-terms != () [
      #h(1em)_Index terms_---#index-terms.join(", ")
    ]
    #v(2pt)
  ]

  // Display the paper's contents.
  body

  // Display bibliography.
  if bibliography-file != none {
    show bibliography: set text(8pt)
    bibliography(bibliography-file, title: text(10pt)[References], style: "ieee")
  }
}
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)

#show: ieee.with(
  title: "A typesetting system to untangle the scientific writing process",
  abstract: [The process of scientific writing is often tangled up with the intricacies of typesetting, leading to frustration and wasted time for researchers. In this paper, we introduce Typst, a new typesetting system designed specifically for scientific writing. Typst untangles the typesetting process, allowing researchers to compose papers faster. In a series of experiments we demonstrate that Typst offers several advantages, including faster document creation, simplified syntax, and increased ease-of-use.

],
authors: (
    (
    name: "Martin Haug",
        department: [Co-Founder],
    organization: [Typst GmbH],
    location: [Berlin, Germany],
        email: "haug\@typst.app"
  ),
    (
    name: "Laurenz Mädje",
        department: [Co-Founder],
    organization: [Typst GmbH],
    location: [Berlin, Germany],
        email: "maedje\@typst.app"
  )),
  index-terms: ("Scientific writing", "Typesetting", "Document creation", "Syntax"),
)


= Introduction
<introduction>
Scientific writing is a crucial part of the research process, allowing researchers to share their findings with the wider scientific community. However, the process of typesetting scientific documents can often be a frustrating and time-consuming affair, particularly when using outdated tools such as LaTeX. Despite being over 30 years old, it remains a popular choice for scientific writing due to its power and flexibility. However, it also comes with a steep learning curve, complex syntax, and long compile times, leading to frustration and despair for many researchers. #cite(<netwok2020>, form: "prose")

== Paper overview
<paper-overview>
In this paper we introduce Typst, a new typesetting system designed to streamline the scientific writing process and provide researchers with a fast, efficient, and easy-to-use alternative to existing systems. Our goal is to shake up the status quo and offer researchers a better way to approach scientific writing.

By leveraging advanced algorithms and a user-friendly interface, Typst offers several advantages over existing typesetting systems, including faster document creation, simplified syntax, and increased ease-of-use.

To demonstrate the potential of Typst, we conducted a series of experiments comparing it to other popular typesetting systems, including LaTeX. Our findings suggest that Typst offers several benefits for scientific writing, particularly for novice users who may struggle with the complexities of LaTeX. Additionally, we demonstrate that Typst offers advanced features for experienced users, allowing for greater customization and flexibility in document creation.

Overall, we believe that Typst represents a significant step forward in the field of scientific writing and typesetting, providing researchers with a valuable tool to streamline their workflow and focus on what really matters: their research. In the following sections, we will introduce Typst in more detail and provide evidence for its superiority over other typesetting systems in a variety of scenarios.

= Methods
<methods>
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vestibulum dapibus dictum leo, vel molestie felis hendrerit at. In diam nisl, rhoncus dapibus facilisis at, laoreet ac nunc. Sed vehicula metus id faucibus tempus. Etiam at laoreet orci, mattis efficitur sem. Aenean eu malesuada nisl. Mauris tempor pulvinar magna, eu tempus felis aliquet nec. In nec iaculis nisi. Fusce at arcu enim. In ipsum massa, pretium vitae pharetra in, vulputate vel felis.

$a + b = g a m m a$

Mauris egestas laoreet aliquam. Integer non convallis risus. Ut eu felis ut augue ultricies tempus. Integer posuere lacinia ex, ac sollicitudin tortor tempus id. Morbi dictum elit at orci accumsan, vitae volutpat dui scelerisque. Pellentesque vitae lectus id nisl posuere placerat pharetra nec ligula. Donec laoreet ligula hendrerit velit tempus porttitor. Vivamus eleifend imperdiet magna quis pellentesque. Pellentesque blandit congue nisi ac ultricies. Sed velit ante, pretium nec facilisis ac, ultricies vitae orci. In hac habitasse platea dictumst. Phasellus massa mauris, tincidunt sed facilisis eu, venenatis a leo.

Fusce id risus mauris. Morbi tincidunt interdum odio, a laoreet sem pulvinar condimentum. Integer suscipit lobortis quam vitae hendrerit. Duis nec convallis mi. Etiam cursus felis eget sem tincidunt, at vulputate urna mattis. Aenean nec libero condimentum, posuere tellus eget, ultrices dui. In quis magna ac metus facilisis porta. Integer et massa dignissim, tempus massa quis, feugiat ante. Aliquam a tortor ligula. Praesent aliquam, lorem id ullamcorper rutrum, nunc orci posuere nulla, id fermentum mi erat a justo. Sed ut sapien vulputate, elementum ante ac, maximus lorem. Phasellus metus est, ultricies et ipsum ac, volutpat lobortis turpis. Vestibulum accumsan elementum vehicula.

#bibliography(("refs.bib"))

