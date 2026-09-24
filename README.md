# zuhtml

<!-- badges: start -->
[![R-CMD-check](https://github.com/pedrobtz/zuhtml/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/pedrobtz/zuhtml/actions/workflows/R-CMD-check.yaml)
[![coverage](https://raw.githubusercontent.com/pedrobtz/zuhtml/main/.github/badges/coverage.svg)](https://github.com/pedrobtz/zuhtml/actions/workflows/coverage.yaml)
<!-- badges: end -->

zuhtml parses real-world HTML the way a browser does and turns it into
ordinary R values: character vectors, lists and data frames. It bundles
the [Gumbo](https://codeberg.org/gumbo-parser/gumbo-parser) HTML5 parser,
so it needs no system library, and it has no hard dependencies.

* Malformed markup is repaired by the HTML parsing algorithm, not
  rejected. `html_problems()` lists what was repaired.
* Select elements with a documented subset of CSS. Anything outside the
  subset is an error, never a partial match.
* Extract text, attributes, links, lists and tables. Tables handle row and
  column spans and keep every column as character, so `"0012"` stays
  `"0012"`.
* Every call runs under explicit limits on input size, native memory and
  nesting depth, and every error is a classed condition.

zuhtml does not fetch pages, run JavaScript or sanitize HTML: a fetcher
hands it a string.

## Installation

``` r
install.packages("zuhtml")
```

The development version, from GitHub:

``` r
# install.packages("pak")
pak::pak("pedrobtz/zuhtml")
```

## Example

``` r
library(zuhtml)

doc <- html_parse('
  <div class=product><h2>Sencha</h2><span class=price>3.50</span>
    <a href="sencha.html">details</a></div>
  <div class=product><h2>Genmaicha</h2>
    <a href="genmaicha.html">details</a></div>',
  base_url = "https://example.org/shop/"
)

cards <- html_elements(doc, ".product")
data.frame(
  name  = html_text_clean(html_element(cards, "h2")),
  price = html_text_clean(html_element(cards, ".price")),
  url   = html_url(html_element(cards, "a"))
)
#>        name price                                     url
#> 1    Sencha  3.50    https://example.org/shop/sencha.html
#> 2 Genmaicha  <NA> https://example.org/shop/genmaicha.html
```

`html_element()` returns one result per card, with a missing value where a
card has no price, so the columns stay aligned.

The [getting started guide](https://pedrobtz.github.io/zuhtml/articles/zuhtml.html)
walks through a complete extraction. There are also guides to
[selectors](https://pedrobtz.github.io/zuhtml/articles/selectors.html),
[tables and lists](https://pedrobtz.github.io/zuhtml/articles/tables-and-lists.html),
and [limits, encodings and safety](https://pedrobtz.github.io/zuhtml/articles/limits-and-encoding.html).

## Licence

zuhtml is MIT-licensed. The bundled Gumbo parser is Apache-2.0, and
[`LICENSE.note`](https://github.com/pedrobtz/zuhtml/blob/main/LICENSE.note)
explains how the two apply.
