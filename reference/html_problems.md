# Parse problems recorded for a document

HTML parsing never fails on malformed markup: the parser repairs it as a
browser would. `html_problems()` lists what was repaired, which is
useful for diagnosing why a tree looks the way it does. Real pages
nearly always have some. This is not a conformance validator.

## Usage

``` r
html_problems(x)
```

## Arguments

- x:

  A `zuhtml_document`.

## Value

A data frame with one row per problem, in input order, and columns
`stage` (`"tokenizer"` or `"parser"`), `code` (a stable package-owned
name, such as `"unexpected-end-tag"` or `"duplicate-attr"`), `line` and
`column` (1-based) and `byte_offset` (0-based, into the decoded UTF-8
input). At most `max_errors` problems are kept (see
[`html_limits()`](https://pedrobtz.github.io/zuhtml/reference/html_limits.md));
attribute `"truncated"` is `TRUE` when more occurred.

## Examples

``` r
doc <- html_parse("<p>One</div><p id=a id=b>Two")
html_problems(doc)
#>       stage                 code line column byte_offset
#> 1    parser unexpected-start-tag    1      1           0
#> 2    parser   unexpected-end-tag    1      7           6
#> 3 tokenizer       duplicate-attr    1     21          20
```
