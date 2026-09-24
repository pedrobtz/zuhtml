# Text pieces of nodes

The text nodes of each node's subtree, in tree order, as separate
strings: the pieces
[`html_text()`](https://pedrobtz.github.io/zuhtml/reference/html_text.md)
concatenates. Boundaries between elements are kept, which matters when
the markup, not whitespace, separates values (`<td>1</td><td>2</td>` is
`"1"`, `"2"`, not `"12"`). Text inside `<script>`, `<style>` and
`<template>` is skipped, as are comments.

## Usage

``` r
html_strings(x, trim = FALSE, drop_empty = FALSE)
```

## Arguments

- x:

  A `zuhtml_document` or `zuhtml_nodeset`.

- trim:

  If `TRUE`, remove leading and trailing whitespace from each piece.

- drop_empty:

  If `TRUE`, drop pieces that are empty (after trimming, when
  `trim = TRUE`).

## Value

A list as long as `x` of character vectors; `NA_character_` for a
missing node. A text node is its own single piece.

## See also

Other node values:
[`html_attr()`](https://pedrobtz.github.io/zuhtml/reference/html_attr.md),
[`html_markdown()`](https://pedrobtz.github.io/zuhtml/reference/html_markdown.md),
[`html_name()`](https://pedrobtz.github.io/zuhtml/reference/html_name.md),
[`html_serialize()`](https://pedrobtz.github.io/zuhtml/reference/html_serialize.md),
[`html_text()`](https://pedrobtz.github.io/zuhtml/reference/html_text.md),
[`html_text_clean()`](https://pedrobtz.github.io/zuhtml/reference/html_text_clean.md)

## Examples

``` r
doc <- html_parse("<p>One <b>two</b>\n  <i> three </i></p>")
p <- html_element(doc, "p")
html_strings(p)
#> [[1]]
#> [1] "One "    "two"     "\n  "    " three "
#> 
html_strings(p, trim = TRUE, drop_empty = TRUE)
#> [[1]]
#> [1] "One"   "two"   "three"
#> 
```
