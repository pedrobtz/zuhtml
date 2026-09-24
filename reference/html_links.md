# Links in a document

Finds the `<a>` and `<area>` elements with an `href` below the given
nodes (and the nodes themselves), in document order, without duplicates.
Duplicate destinations are kept, and so are fragment, `mailto:` and
`tel:` links.

## Usage

``` r
html_links(x, absolute = FALSE)
```

## Arguments

- x:

  A `zuhtml_document` or `zuhtml_nodeset`.

- absolute:

  If `TRUE`, `url` is resolved with
  [`html_url()`](https://pedrobtz.github.io/zuhtml/reference/html_url.md);
  otherwise it is `href` unchanged.

## Value

A data frame with one row per link and character columns `text` (the
link's cleaned text, see
[`html_text_clean()`](https://pedrobtz.github.io/zuhtml/reference/html_text_clean.md)),
`href` (the attribute as written, decoded) and `url`.

## See also

Other extraction:
[`html_forms()`](https://pedrobtz.github.io/zuhtml/reference/html_forms.md),
[`html_list()`](https://pedrobtz.github.io/zuhtml/reference/html_list.md),
[`html_table()`](https://pedrobtz.github.io/zuhtml/reference/html_table.md),
[`html_table_cells()`](https://pedrobtz.github.io/zuhtml/reference/html_table_cells.md),
[`html_url()`](https://pedrobtz.github.io/zuhtml/reference/html_url.md)

## Examples

``` r
doc <- html_parse(
  "<nav><a href='/'>Home</a> <a href='about.html'>About</a></nav>",
  base_url = "https://example.org/site/"
)
html_links(doc)
#>    text       href        url
#> 1  Home          /          /
#> 2 About about.html about.html
html_links(doc, absolute = TRUE)
#>    text       href                                 url
#> 1  Home          /                https://example.org/
#> 2 About about.html https://example.org/site/about.html
```
