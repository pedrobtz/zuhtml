# Getting started with zuhtml

zuhtml turns real-world HTML into ordinary R values: character vectors,
lists and data frames. It parses the way a browser does, so malformed
markup is repaired rather than rejected, and it never fetches anything:
you give it a string, raw bytes or a file.

``` r

library(zuhtml)
```

## A page to work with

A small catalogue page, as it might have been saved from a site. Some
markup is sloppy on purpose: unclosed `<li>`s, unquoted attributes, a
stray end tag, and a product card without a price.

``` r

page <- '
<!DOCTYPE html>
<title>Tea shop</title>
<nav><ul><li><a href="/">Home</a><li><a href="sale/">Sale</a></ul></nav>
<p>Free shipping over 30 EUR</span>
<div class=product>
  <h2 class=name>Sencha</h2><span class=price>3.50</span>
  <a href="sencha.html">details</a>
</div>
<div class=product>
  <h2 class=name>Genmaicha</h2>
  <a href="genmaicha.html">details</a>
</div>
<table>
  <thead><tr><th>Size<th>Grams</thead>
  <tr><td>Small<td>0100
  <tr><td>Large<td>0250
</table>'

doc <- html_parse(page, base_url = "https://example.org/shop/")
doc
#> <zuhtml_document>
#> root:     <html> with <head>, <body>
#> nodes:    59
#> input:    472 bytes (UTF-8)
#> problems: 1
```

[`html_read()`](https://pedrobtz.github.io/zuhtml/reference/html_parse.md)
does the same for a file. `base_url` is where the page came from;
relative links are resolved against it.

## Selecting elements

[`html_elements()`](https://pedrobtz.github.io/zuhtml/reference/html_elements.md)
finds every element that matches a CSS selector.
[`html_element()`](https://pedrobtz.github.io/zuhtml/reference/html_elements.md)
finds the first match below *each* input node, and keeps a missing node
where there is none. That is what keeps extracted columns aligned when
some records lack a field:

``` r

cards <- html_elements(doc, ".product")
cards
#> <zuhtml_nodeset[2]>
#> [1] <div class="product">
#> [2] <div class="product">

products <- data.frame(
  name = html_text_clean(html_element(cards, ".name")),
  price = html_text_clean(html_element(cards, ".price")),
  url = html_url(html_element(cards, "a"))
)
products
#>        name price                                     url
#> 1    Sencha  3.50    https://example.org/shop/sencha.html
#> 2 Genmaicha  <NA> https://example.org/shop/genmaicha.html
```

Genmaicha has no price, so it gets `NA` rather than shifting the column.

## Values

[`html_text_clean()`](https://pedrobtz.github.io/zuhtml/reference/html_text_clean.md)
gives text as a reader wants it;
[`html_text()`](https://pedrobtz.github.io/zuhtml/reference/html_text.md)
gives it exactly as parsed.
[`html_attr()`](https://pedrobtz.github.io/zuhtml/reference/html_attr.md)
reads attributes, and
[`html_serialize()`](https://pedrobtz.github.io/zuhtml/reference/html_serialize.md)
writes nodes back as HTML.

``` r

html_text_clean(html_element(doc, "title"))
#> [1] "Tea shop"
html_attr(html_elements(doc, "nav a"), "href")
#> [1] "/"     "sale/"
html_serialize(html_element(doc, "h2"))
#> [1] "<h2 class=\"name\">Sencha</h2>"
```

## Structures

Links, lists and tables have their own extractors:

``` r

html_links(doc, absolute = TRUE)
#>      text           href                                     url
#> 1    Home              /                    https://example.org/
#> 2    Sale          sale/          https://example.org/shop/sale/
#> 3 details    sencha.html    https://example.org/shop/sencha.html
#> 4 details genmaicha.html https://example.org/shop/genmaicha.html
lapply(html_elements(doc, "nav ul"), html_list)
#> [[1]]
#> [1] "Home" "Sale"
html_tables(doc)
#> [[1]]
#>    Size Grams
#> 1 Small  0100
#> 2 Large  0250
```

Table columns are character: `"0100"` keeps its leading zero. Convert
types yourself when you know them, for example with
[`type.convert()`](https://rdrr.io/r/utils/type.convert.html).

## What the parser repaired

Real pages nearly always have markup errors, which the parser repairs.
[`html_problems()`](https://pedrobtz.github.io/zuhtml/reference/html_problems.md)
lists them:

``` r

html_problems(doc)
#>    stage               code line column byte_offset
#> 1 parser unexpected-end-tag    5     29         142
```

## Where next

- [`vignette("selectors")`](https://pedrobtz.github.io/zuhtml/articles/selectors.md):
  the supported CSS subset.
- [`vignette("tables-and-lists")`](https://pedrobtz.github.io/zuhtml/articles/tables-and-lists.md):
  how tables and lists are read.
- [`vignette("limits-and-encoding")`](https://pedrobtz.github.io/zuhtml/articles/limits-and-encoding.md):
  resource limits, encodings, and what zuhtml does not do.
