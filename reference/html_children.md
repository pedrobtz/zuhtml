# Navigate a document tree

Move from nodes to related nodes. Operations that return exactly one
node per input node – `html_parent()`, `html_next_sibling()` and
`html_previous_sibling()` – are *aligned*: the result has the same
length as `x`, with a missing node where there is no answer, so that
results line up with their inputs. Operations that can return many nodes
per input – `html_children()`, `html_ancestors()` and
`html_template_content()` – return the set of all results, without
duplicates, in document order.

## Usage

``` r
html_children(x, elements_only = TRUE)

html_parent(x)

html_ancestors(x)

html_next_sibling(x, elements_only = TRUE)

html_previous_sibling(x, elements_only = TRUE)

html_template_content(x)

html_root(x)

html_document(x)
```

## Arguments

- x:

  A `zuhtml_document` or `zuhtml_nodeset`. A document stands for its
  document node.

- elements_only:

  If `TRUE`, consider element nodes only, skipping text, comments and
  other nodes.

## Value

- `html_children()`, `html_ancestors()`, `html_template_content()`: a
  `zuhtml_nodeset` in document order. `html_ancestors()` does not
  include the document node.

- `html_parent()`, `html_next_sibling()`, `html_previous_sibling()`: a
  `zuhtml_nodeset` as long as `x`, with missing nodes where there is no
  parent or sibling.

- `html_root()`: a `zuhtml_nodeset` of length one: the `<html>` element
  of a document, or the fragment node of a fragment.

- `html_document()`: the `zuhtml_document` that owns `x`.

## Details

A `<template>` element's contents are its children here, but they are
inert: searches and text extraction do not descend into them.
`html_template_content()` returns them explicitly.

## See also

Other navigation:
[`html_closest()`](https://pedrobtz.github.io/zuhtml/reference/html_closest.md),
[`html_elements()`](https://pedrobtz.github.io/zuhtml/reference/html_elements.md)

## Examples

``` r
doc <- html_parse("<ul><li>One</li><li>Two <b>bold</b></li></ul>")
body <- html_children(html_root(doc))[2]
items <- html_children(html_children(body))
items
#> <zuhtml_nodeset[2]>
#> [1] <li>
#> [2] <li>
html_parent(items)
#> <zuhtml_nodeset[2]>
#> [1] <ul>
#> [2] <ul>
html_next_sibling(items)
#> <zuhtml_nodeset[2]>
#> [1] <li>
#> [2] <missing>
html_ancestors(html_children(items[2]))
#> <zuhtml_nodeset[4]>
#> [1] <html>
#> [2] <body>
#> [3] <ul>
#> [4] <li>

# Template contents are reached explicitly:
tmpl <- html_parse("<template><p>inert</p></template>")
html_template_content(html_children(html_children(html_root(tmpl))[1]))
#> <zuhtml_nodeset[1]>
#> [1] <p>
```
