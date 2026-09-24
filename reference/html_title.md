# Document title

The document's title as the HTML standard defines `document.title`: the
text of the first `<title>` element in the HTML namespace, with leading
and trailing whitespace removed and runs of whitespace collapsed to one
space. An SVG `<title>` does not count.

## Usage

``` r
html_title(x)
```

## Arguments

- x:

  A `zuhtml_document`, or a `zuhtml_nodeset` whose document is used.

## Value

A single string, `NA` when the document has no `<title>`.

## See also

Other metadata:
[`html_json_ld()`](https://pedrobtz.github.io/zuhtml/reference/html_json_ld.md),
[`html_meta()`](https://pedrobtz.github.io/zuhtml/reference/html_meta.md),
[`html_microdata()`](https://pedrobtz.github.io/zuhtml/reference/html_microdata.md)

## Examples

``` r
html_title(html_parse("<title>  Annual\n  report </title><p>Body"))
#> [1] "Annual report"
html_title(html_parse("<p>No title"))
#> [1] NA
```
