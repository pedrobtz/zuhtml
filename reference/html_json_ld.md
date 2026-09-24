# JSON-LD blocks

The structured data pages embed as JSON-LD: the text of each
`<script type="application/ld+json">` below the given nodes (and the
nodes themselves), in document order. The type is matched as a MIME
type: case-insensitively, ignoring surrounding whitespace and any
parameters.

## Usage

``` r
html_json_ld(x, parse = FALSE)
```

## Arguments

- x:

  A `zuhtml_document` or `zuhtml_nodeset`.

- parse:

  If `TRUE`, parse each block with
  [`jsonlite::fromJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html)
  (with `simplifyVector = FALSE`, so objects are named lists and arrays
  are lists). This needs the jsonlite package. A wrapper around the
  whole block, `<![CDATA[ ... ]]>` or `<!-- ... -->`, optionally
  commented out with `//` or `/* */` as pages often do, is removed
  first.

## Value

With `parse = FALSE`, a character vector: the text of each block,
exactly as written. With `parse = TRUE`, a list as long as that vector:
each block's parsed value, or `NULL` for a block that is not valid JSON;
the texts are kept in its attribute `"json"`.

## See also

Other metadata:
[`html_meta()`](https://pedrobtz.github.io/zuhtml/reference/html_meta.md),
[`html_microdata()`](https://pedrobtz.github.io/zuhtml/reference/html_microdata.md),
[`html_title()`](https://pedrobtz.github.io/zuhtml/reference/html_title.md)

## Examples

``` r
doc <- html_parse(paste0(
  "<script type='application/ld+json'>",
  '{"@context": "https://schema.org", "@type": "Person", "name": "Ada"}',
  "</script>"
))
html_json_ld(doc)
#> [1] "{\"@context\": \"https://schema.org\", \"@type\": \"Person\", \"name\": \"Ada\"}"
if (requireNamespace("jsonlite", quietly = TRUE)) {
  html_json_ld(doc, parse = TRUE)[[1]]$name
}
#> [1] "Ada"
```
