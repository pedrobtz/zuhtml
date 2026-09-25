# zuhtml

zuhtml parses real-world HTML the way a browser does and turns it into
ordinary R values: character vectors, lists and data frames. It bundles
the [Gumbo](https://codeberg.org/gumbo-parser/gumbo-parser) HTML5
parser, so it needs no system library, and it has no hard dependencies.

- Malformed markup is repaired by the HTML parsing algorithm, not
  rejected.
  [`html_problems()`](https://pedrobtz.github.io/zuhtml/reference/html_problems.md)
  lists what was repaired.
- Select elements with a documented subset of CSS. Anything outside the
  subset is an error, never a partial match.
- Extract text, attributes, links, lists and tables. Tables handle row
  and column spans and keep every column as character, so `"0012"` stays
  `"0012"`.
- Every call runs under explicit limits on input size, native memory and
  nesting depth, and every error is a classed condition.

[`html_read()`](https://pedrobtz.github.io/zuhtml/reference/html_parse.md)
reads a file, a URL or any R connection. zuhtml has no HTTP client of
its own: a URL goes through base R’s
[`url()`](https://rdrr.io/r/base/connections.html), and a fetcher that
needs headers or authentication hands it the body. zuhtml does not run
JavaScript or sanitize HTML.

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

[`html_element()`](https://pedrobtz.github.io/zuhtml/reference/html_elements.md)
returns one result per card, with a missing value where a card has no
price, so the columns stay aligned.

[`html_read()`](https://pedrobtz.github.io/zuhtml/reference/html_parse.md)
reads a file, a connection or a URL. A URL becomes the document’s base
URL, so relative links resolve against the page:

``` r

doc <- html_read("https://cran.r-project.org/web/views/")
html_title(doc)
#> [1] "CRAN Task Views"

rows <- html_elements(doc, "table tr")
views <- data.frame(
  topic = html_text_clean(html_element(rows, "td:nth-child(2)")),
  url   = html_url(html_element(rows, "a"))
)
head(views, 3)
#>                  topic                                                        url
#> 1    Actuarial Science https://cran.r-project.org/web/views/ActuarialScience.html
#> 2 Agricultural Science      https://cran.r-project.org/web/views/Agriculture.html
#> 3    Anomaly Detection https://cran.r-project.org/web/views/AnomalyDetection.html
```

The [getting started
guide](https://pedrobtz.github.io/zuhtml/articles/zuhtml.html) walks
through a complete extraction. There are also guides to
[selectors](https://pedrobtz.github.io/zuhtml/articles/selectors.html),
[tables and
lists](https://pedrobtz.github.io/zuhtml/articles/tables-and-lists.html),
and [limits, encodings and
safety](https://pedrobtz.github.io/zuhtml/articles/limits-and-encoding.html).

## Licence

zuhtml is MIT-licensed. The bundled Gumbo parser is Apache-2.0, and
[`LICENSE.note`](https://github.com/pedrobtz/zuhtml/blob/main/LICENSE.note)
explains how the two apply.
