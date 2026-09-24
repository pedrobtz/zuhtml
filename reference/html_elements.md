# Select elements with CSS selectors

`html_elements()` finds every element matching a selector below the
given nodes; `html_element()` finds the first below each node, keeping
one result per input so that extracted columns stay aligned.
`html_matches()` tests nodes themselves, and `html_filter()` keeps the
ones that match.

## Usage

``` r
html_elements(x, css)

html_element(x, css)

html_matches(x, css)

html_filter(x, css)
```

## Arguments

- x:

  A `zuhtml_document` or `zuhtml_nodeset`.

- css:

  A CSS selector: a single string.

## Value

- `html_elements()`: a `zuhtml_nodeset` of the matching elements below
  any node of `x`, without duplicates, in document order.

- `html_element()`: a `zuhtml_nodeset` as long as `x`: for each node,
  the first matching element below it in document order, or a missing
  node.

- `html_matches()`: a logical vector as long as `x`; `NA` for missing
  nodes, `FALSE` for nodes that are not elements.

- `html_filter()`: the nodes of `x` that match, in their order.

## Details

Searching a document includes its `<html>` element. Searching below an
element excludes the element itself unless the selector uses `:scope`
for it, as in `":scope > li"` or `":scope.active"`. Matching elsewhere
in the selector is against the whole document, as in a browser:
`"div p"` below a `<section>` finds a `<p>` whose `<div>` ancestor is
outside the section. Template contents are never searched.

## Supported selectors

A deliberately small subset of CSS Selectors Level 4, and nothing else:

- type (`p`) and universal (`*`) selectors;

- `#id` and `.class`;

- attributes: `[a]`, `[a=v]`, `[a~=v]`, `[a|=v]`, `[a^=v]`, `[a$=v]` and
  `[a*=v]`, with an optional `i` or `s` flag, as in `[type=text i]`;

- combinators: descendant (space), child (`>`), next sibling (`+`) and
  later sibling (`~`), and selector lists (`,`);

- `:scope`, `:root`, `:empty`, `:first-child`, `:last-child`,
  `:only-child`, `:nth-child(an+b)`, `:nth-of-type(an+b)`, and `:not()`
  with one compound selector.

Anything else – `:has()`, other pseudo-classes, pseudo-elements,
namespace prefixes, the `of S` form of `:nth-child()` – is an error of
class `zuhtml_selector_error`, never a silent partial match.

Case follows HTML documents in a browser: element and attribute names
match HTML elements regardless of ASCII case and SVG or MathML elements
exactly; IDs and classes are case-sensitive; attribute values are
case-sensitive except for the attributes HTML lists as case-insensitive
(such as `type` and `lang`), and an `i` or `s` flag overrides both.
Structural pseudo-classes count element siblings only. `:empty` is true
for an element with no element or text children; comments do not count,
whitespace does.

## See also

Other navigation:
[`html_children()`](https://pedrobtz.github.io/zuhtml/reference/html_children.md)

## Examples

``` r
doc <- html_parse(paste0(
  "<div class=card><h2>Tea</h2><span class=price>3.50</span></div>",
  "<div class=card><h2>Cake</h2></div>"
))
cards <- html_elements(doc, ".card")
html_text(html_element(cards, "h2"))
#> [1] "Tea"  "Cake"
html_text(html_element(cards, ".price"))
#> [1] "3.50" NA    
html_elements(doc, "div > h2:first-child")
#> <zuhtml_nodeset[2]>
#> [1] <h2>
#> [2] <h2>
html_matches(html_elements(doc, "div, h2"), ".card")
#> [1]  TRUE FALSE  TRUE FALSE
html_filter(html_elements(doc, "div, h2"), "h2")
#> <zuhtml_nodeset[2]>
#> [1] <h2>
#> [2] <h2>

try(html_elements(doc, "div:has(h2)"))
#> Error in html_elements(doc, "div:has(h2)") : 
#>   Invalid selector at position 4: :has() is not supported.
#>   div:has(h2)
#>      ^
```
