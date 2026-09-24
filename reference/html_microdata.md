# Microdata items

The top-level microdata items (elements with `itemscope` and no
`itemprop`) below the given nodes (and the nodes themselves), in
document order, with their properties collected by the HTML standard's
algorithm (<https://html.spec.whatwg.org/multipage/microdata.html>),
including properties pulled in by `itemref`. RDFa is not read.

## Usage

``` r
html_microdata(x)
```

## Arguments

- x:

  A `zuhtml_document` or `zuhtml_nodeset`.

## Value

A list of items. Each item is a list with `type` (the tokens of
`itemtype`, a character vector, possibly empty), `id` (`itemid` resolved
as a URL, `NA` when absent or without `itemtype`) and `properties`: a
named list, in document order of first appearance, of lists of values,
since a name may occur more than once. A value is a string or a nested
item.

## Details

Each property's value follows the standard: a nested item for an element
with `itemscope`; the `content` attribute of `<meta>`; the resolved
`src` of `<audio>`, `<embed>`, `<iframe>`, `<img>`, `<source>`,
`<track>` and `<video>`, `href` of `<a>`, `<area>` and `<link>`, and
`data` of `<object>` (resolved as
[`html_url()`](https://pedrobtz.github.io/zuhtml/reference/html_url.md)
does, `""` when that fails); the `value` attribute of `<data>` and
`<meter>`; the `datetime` attribute of `<time>` when present. Otherwise
it is the element's text, which here is cleaned as
[`html_text_clean()`](https://pedrobtz.github.io/zuhtml/reference/html_text_clean.md)
does, not the raw `textContent`. An item that is its own ancestor
through `itemref` is `NULL`.

## See also

Other metadata:
[`html_json_ld()`](https://pedrobtz.github.io/zuhtml/reference/html_json_ld.md),
[`html_meta()`](https://pedrobtz.github.io/zuhtml/reference/html_meta.md),
[`html_title()`](https://pedrobtz.github.io/zuhtml/reference/html_title.md)

## Examples

``` r
doc <- html_parse(paste0(
  "<div itemscope itemtype='https://schema.org/Book'>",
  "<span itemprop='name'>Dune</span>",
  "<div itemprop='author' itemscope itemtype='https://schema.org/Person'>",
  "<span itemprop='name'>Frank Herbert</span></div>",
  "<meta itemprop='isbn' content='9780441013593'>",
  "</div>"
))
book <- html_microdata(doc)[[1]]
book$type
#> [1] "https://schema.org/Book"
book$properties$name[[1]]
#> [1] "Dune"
book$properties$author[[1]]$properties$name[[1]]
#> [1] "Frank Herbert"
```
