# Resolve URLs in attributes

Reads a URL-valued attribute from each node and resolves it against the
document's base URL with the reference-resolution algorithm of RFC 3986,
section 5 (<https://www.rfc-editor.org/rfc/rfc3986#section-5>): dot
segments are removed and relative, query-only, fragment-only and
protocol-relative references are handled. Nothing is fetched.

## Usage

``` r
html_url(x, attr = "href", base_url = NULL)
```

## Arguments

- x:

  A `zuhtml_document` or `zuhtml_nodeset`.

- attr:

  The attribute holding the URL.

- base_url:

  The base URL to resolve against, overriding the document's; `NULL` to
  use the document's.

## Value

A character vector as long as `x`: the resolved URL of each node. `NA`
where the node lacks the attribute, the reference is malformed, or a
relative reference has no absolute base URL to resolve against; and for
missing nodes. The original attribute value stays available through
[`html_attr()`](https://pedrobtz.github.io/zuhtml/reference/html_attr.md).

## Details

The base URL is `base_url` if given; otherwise the document's first
`<base href>` resolved against the `base_url` given to
[`html_parse()`](https://pedrobtz.github.io/zuhtml/reference/html_parse.md);
otherwise that `base_url` alone.

This is RFC 3986, not the WHATWG URL Standard browsers implement: there
is no IDNA processing, no percent-encoding of characters that need it,
and no special handling of backslashes. Leading and trailing ASCII
whitespace is removed from the attribute; a reference that still
contains whitespace or a control character, or whose scheme is invalid,
is malformed.

## See also

Other extraction:
[`html_links()`](https://pedrobtz.github.io/zuhtml/reference/html_links.md),
[`html_list()`](https://pedrobtz.github.io/zuhtml/reference/html_list.md),
[`html_table()`](https://pedrobtz.github.io/zuhtml/reference/html_table.md),
[`html_table_cells()`](https://pedrobtz.github.io/zuhtml/reference/html_table_cells.md)

## Examples

``` r
doc <- html_parse(
  "<a href='../img/a.png'>A</a><a href='//cdn.example.org/b'>B</a>",
  base_url = "https://example.org/docs/page.html"
)
html_url(html_elements(doc, "a"))
#> [1] "https://example.org/img/a.png" "https://cdn.example.org/b"    
html_url(html_elements(doc, "a"), base_url = "http://other.test/x/")
#> [1] "http://other.test/img/a.png" "http://cdn.example.org/b"   
```
