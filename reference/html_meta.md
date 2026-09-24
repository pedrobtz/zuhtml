# Meta tags

One row per `<meta>` element below the given nodes (and the nodes
themselves), in document order. Duplicates are kept, so OpenGraph
(`og:*` in `property`), Twitter cards and Dublin Core (`name`) come out
as rows to filter.

## Usage

``` r
html_meta(x)
```

## Arguments

- x:

  A `zuhtml_document` or `zuhtml_nodeset`.

## Value

A data frame with character columns `name`, `property`, `http_equiv`,
`charset` and `content`, each the attribute as written (decoded) or `NA`
when absent. `name`, `property` and `http_equiv` keep their case;
compare with [`tolower()`](https://rdrr.io/r/base/chartr.html).

## See also

Other metadata:
[`html_json_ld()`](https://pedrobtz.github.io/zuhtml/reference/html_json_ld.md),
[`html_microdata()`](https://pedrobtz.github.io/zuhtml/reference/html_microdata.md),
[`html_title()`](https://pedrobtz.github.io/zuhtml/reference/html_title.md)

## Examples

``` r
doc <- html_parse(paste0(
  "<meta charset='utf-8'>",
  "<meta name='description' content='A page.'>",
  "<meta property='og:title' content='Title'>",
  "<meta property='og:image' content='a.png'>",
  "<meta property='og:image' content='b.png'>"
))
meta <- html_meta(doc)
meta
#>          name property http_equiv charset content
#> 1        <NA>     <NA>       <NA>   utf-8    <NA>
#> 2 description     <NA>       <NA>    <NA> A page.
#> 3        <NA> og:title       <NA>    <NA>   Title
#> 4        <NA> og:image       <NA>    <NA>   a.png
#> 5        <NA> og:image       <NA>    <NA>   b.png
meta$content[meta$property %in% "og:image"]
#> [1] "a.png" "b.png"
```
