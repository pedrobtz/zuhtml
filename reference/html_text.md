# Text content of nodes

`html_text()` is the structural text of each node: the text nodes in its
subtree, concatenated in tree order, exactly as parsed. It inserts no
separators, trims nothing and keeps `<script>` and `<style>` text; it
does not include comments or the contents of `<template>` elements.

## Usage

``` r
html_text(x, recursive = TRUE)
```

## Arguments

- x:

  A `zuhtml_document` or `zuhtml_nodeset`.

- recursive:

  If `FALSE`, only the direct text children of each node.

## Value

A character vector as long as `x`. An element with no text is `""`; a
text, comment or processing-instruction node is its own content; a
doctype and a missing node are `NA`.

## See also

Other node values:
[`html_attr()`](https://pedrobtz.github.io/zuhtml/reference/html_attr.md),
[`html_markdown()`](https://pedrobtz.github.io/zuhtml/reference/html_markdown.md),
[`html_name()`](https://pedrobtz.github.io/zuhtml/reference/html_name.md),
[`html_serialize()`](https://pedrobtz.github.io/zuhtml/reference/html_serialize.md),
[`html_strings()`](https://pedrobtz.github.io/zuhtml/reference/html_strings.md),
[`html_text_clean()`](https://pedrobtz.github.io/zuhtml/reference/html_text_clean.md)

## Examples

``` r
doc <- html_parse("<p>Hello <b>big</b> world</p>")
p <- html_children(html_children(html_root(doc))[2])
html_text(p)
#> [1] "Hello big world"
html_text(p, recursive = FALSE)
#> [1] "Hello  world"
```
