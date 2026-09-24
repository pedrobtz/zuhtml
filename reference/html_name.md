# Node names, namespaces and types

Vectorized accessors returning one value per node, with `NA` for missing
nodes.

## Usage

``` r
html_name(x)

html_namespace(x)

html_type(x)
```

## Arguments

- x:

  A `zuhtml_document` or `zuhtml_nodeset`.

## Value

A character vector as long as `x`.

- `html_name()`: the element name, lowercase for HTML elements and in
  the spec's mixed case for SVG ones such as `"foreignObject"`; the
  doctype's name for a doctype node; `NA` for other nodes.

- `html_namespace()`: the namespace URI of an element, for example
  `"http://www.w3.org/1999/xhtml"` or `"http://www.w3.org/2000/svg"`;
  `NA` for other nodes.

- `html_type()`: one of `"document"`, `"fragment"`, `"doctype"`,
  `"element"`, `"text"`, `"comment"` and `"processing_instruction"`. A
  `<template>` is an `"element"`.

## See also

Other node values:
[`html_attr()`](https://pedrobtz.github.io/zuhtml/reference/html_attr.md),
[`html_text()`](https://pedrobtz.github.io/zuhtml/reference/html_text.md)

## Examples

``` r
doc <- html_parse("<p>Text<svg><foreignObject/></svg><!-- note -->")
nodes <- html_children(html_children(html_root(doc))[2], FALSE)
nodes <- html_children(nodes, FALSE)
html_type(nodes)
#> [1] "text"    "element" "comment"
html_name(nodes)
#> [1] NA    "svg" NA   
html_namespace(nodes)
#> [1] NA                           "http://www.w3.org/2000/svg"
#> [3] NA                          
```
