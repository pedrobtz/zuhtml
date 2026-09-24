# CSS selectors

zuhtml implements a deliberately small subset of CSS Selectors and
rejects everything else with an error. A selector either works exactly
as it would in a browser or fails loudly: it never matches something
partly.

``` r

library(zuhtml)
doc <- html_parse('
<div id=main class="card wide">
  <h2 class=title>One</h2>
  <p class="a b" lang=en-US>first</p>
  <p title="">second</p>
  <ul><li>1<li>2<li>3<li>4</ul>
</div>')
```

## What is supported

| Kind | Examples |
|----|----|
| Type and universal | `p`, `*` |
| ID and class | `#main`, `.card.wide` |
| Attributes | `[title]`, `[lang=en-US]`, `[class~=a]`, `[lang\|=en]`, `[href^=http]`, `[href$=".pdf"]`, `[href*=shop]`, with an `i` or `s` flag |
| Combinators | `div p`, `div > p`, `h2 + p`, `h2 ~ p`, and lists: `h2, p` |
| Pseudo-classes | `:scope`, `:root`, `:empty`, `:first-child`, `:last-child`, `:only-child`, `:nth-child(an+b)`, `:nth-of-type(an+b)`, `:not()` of one compound selector |

``` r

html_text(html_elements(doc, "h2 ~ p"))
#> [1] "first"  "second"
html_text(html_elements(doc, "li:nth-child(odd)"))
#> [1] "1" "3"
html_text(html_elements(doc, "p:not([title])"))
#> [1] "first"
html_text(html_elements(doc, "[lang|=en]"))
#> [1] "first"
```

## What is rejected

`:has()`, other pseudo-classes, pseudo-elements (including Scrapy’s
`::text` and `::attr()`), namespace prefixes and the `of S` form of
`:nth-child()` are errors. The error says where:

``` r

try(html_elements(doc, "div:has(> h2)"))
#> Error in html_elements(doc, "div:has(> h2)") : 
#>   Invalid selector at position 4: :has() is not supported.
#>   div:has(> h2)
#>      ^
try(html_elements(doc, "p::text"))
#> Error in html_elements(doc, "p::text") : 
#>   Invalid selector at position 2: pseudo-elements are not supported.
#>   p::text
#>    ^
```

Handle them by class, `zuhtml_selector_error`; the condition carries the
selector, the position and whether the form is unsupported or malformed.

## Case

As in a browser on an HTML page: element and attribute names match HTML
elements whatever their case, and SVG or MathML elements exactly. IDs
and classes are case-sensitive. Attribute values are case-sensitive,
except for the attributes HTML lists as case-insensitive (`type`, `lang`
and others); an `i` or `s` flag overrides either.

``` r

length(html_elements(doc, "P"))
#> [1] 2
length(html_elements(doc, ".CARD"))
#> [1] 0
length(html_elements(doc, "[lang=EN-US]"))
#> [1] 1
length(html_elements(doc, "[lang=EN-US s]"))
#> [1] 0
```

## Where the search looks

Searching a document includes its `<html>` element. Searching below an
element excludes the element itself, unless `:scope` names it:

``` r

main <- html_element(doc, "#main")
length(html_elements(main, ".card"))
#> [1] 0
length(html_elements(main, ":scope.card"))
#> [1] 1
html_name(html_elements(main, ":scope > *"))
#> [1] "h2" "p"  "p"  "ul"
```

The rest of a selector may match outside the context, as
`querySelectorAll()` does: `"body h2"` below `#main` finds the `<h2>`
even though `<body>` is outside it.

[`html_elements()`](https://pedrobtz.github.io/zuhtml/reference/html_elements.md)
on several nodes returns the union of their matches, without duplicates,
in document order.
[`html_element()`](https://pedrobtz.github.io/zuhtml/reference/html_elements.md)
returns one result per input node, a missing node where there is no
match: use it to pull one field out of each of many records.

`<template>` contents are never searched; reach them with
[`html_template_content()`](https://pedrobtz.github.io/zuhtml/reference/html_children.md).
