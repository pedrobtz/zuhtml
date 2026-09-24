# Serialize nodes as HTML

Produces normalized HTML following the WHATWG serialization algorithm,
not the original input bytes: end tags the input left out are written,
attribute values are always double-quoted, and `&`, `<`, `>`, `"` and
non-breaking spaces are escaped as the algorithm requires. Parsing the
result gives back the same tree, except where the HTML standard itself
does not guarantee that (for example markup that tree construction
rearranges).

## Usage

``` r
html_serialize(x, outer = TRUE)
```

## Arguments

- x:

  A `zuhtml_document` or `zuhtml_nodeset`.

- outer:

  If `TRUE`, each node with its own markup, like `outerHTML`; if
  `FALSE`, only its contents, like `innerHTML`. A document or fragment
  has no markup of its own, so both give its contents.

## Value

A character vector as long as `x`; `NA` for missing nodes.

## Details

Serialization is not sanitization: `<script>` elements and `javascript:`
URLs are written as they were parsed.

[`as.character()`](https://rdrr.io/r/base/character.html) on a nodeset
is `html_serialize()`.

## See also

Other node values:
[`html_attr()`](https://pedrobtz.github.io/zuhtml/reference/html_attr.md),
[`html_name()`](https://pedrobtz.github.io/zuhtml/reference/html_name.md),
[`html_text()`](https://pedrobtz.github.io/zuhtml/reference/html_text.md),
[`html_text_clean()`](https://pedrobtz.github.io/zuhtml/reference/html_text_clean.md)

## Examples

``` r
doc <- html_parse("<p class=x>One<br>Two & <b>three</p>")
html_serialize(doc)
#> [1] "<html><head></head><body><p class=\"x\">One<br>Two &amp; <b>three</b></p></body></html>"
p <- html_children(html_children(html_root(doc))[2])
html_serialize(p)
#> [1] "<p class=\"x\">One<br>Two &amp; <b>three</b></p>"
html_serialize(p, outer = FALSE)
#> [1] "One<br>Two &amp; <b>three</b>"

# To write a document to a file:
path <- tempfile(fileext = ".html")
writeLines(html_serialize(doc), path)
```
