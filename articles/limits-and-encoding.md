# Limits, encodings and safety

``` r

library(zuhtml)
```

## Every call runs under limits

HTML from the web is untrusted input. zuhtml bounds the work and memory
any page can cost, per call, with
[`html_limits()`](https://pedrobtz.github.io/zuhtml/reference/html_limits.md):

``` r

html_limits()
#> <zuhtml_limits>
#>   max_input           16,777,216
#>   max_memory          536,870,912
#>   max_depth           512
#>   max_nodes           4,000,000
#>   max_errors          100
#>   max_table_cells     1,000,000
#>   max_selector_length 16,384
```

- `max_input` is checked before parsing. `max_memory` bounds the
  parser’s native memory and the document it builds; it is the real
  guard, since some markup costs far more memory per byte than other
  markup.
- `max_depth` bounds nesting *while parsing*. Tree construction takes
  time quadratic in nesting depth, so a check after parsing would come
  too late: 100,000 nested elements would take 16 seconds. With the
  limit it fails at once.
- `max_nodes`, `max_errors` (parse problems kept), `max_table_cells` and
  `max_selector_length` bound the rest.

Exceeding a limit is a `zuhtml_limit_error`, raised after every native
allocation has been released. It says which limit and by how much:

``` r

err <- tryCatch(
  html_parse(strrep("<div>", 1e5)),
  zuhtml_limit_error = function(e) e
)
conditionMessage(err)
#> [1] "Elements are nested deeper than max_depth = 512."
err$limit
#> [1] "max_depth"
```

Tighter limits suit a service that parses pages from strangers:

``` r

strict <- html_limits(max_input = 2 * 1024^2, max_memory = 64 * 1024^2,
                      max_depth = 128)
doc <- html_parse("<p>Small page</p>", limits = strict)
```

## Encodings

A string is already text: it is used as UTF-8. Raw bytes are decoded, in
order of preference, with the `encoding` you give, a byte-order mark, or
UTF-8:

``` r

bytes <- as.raw(c(0x3c, 0x70, 0x3e, 0x63, 0x61, 0x66, 0xe9))  # "<p>caf\xe9"
html_text_clean(html_parse(bytes, encoding = "latin1"))
#> [1] "café"
```

Invalid input is an error, never silently replaced:

``` r

try(html_parse(bytes))
#> Error in html_parse(bytes) : The input is not valid UTF-8.
```

zuhtml does not guess encodings from `<meta charset>`. When you fetch a
page, pass the charset from the HTTP `Content-Type` header as
`encoding`.

## Errors are classed

Handle errors by class, never by message text:

``` r

tryCatch(
  html_elements(html_parse("<p>"), "p:hover"),
  zuhtml_selector_error = function(e) paste("unsupported at", e$position)
)
#> [1] "unsupported at 2"
```

See `?zuhtml-conditions` for the classes and their fields.

## What zuhtml does not do

- **It does not sanitize.** Parsing and serializing keep `<script>`
  elements, event-handler attributes and `javascript:` URLs. Do not
  treat
  [`html_serialize()`](https://pedrobtz.github.io/zuhtml/reference/html_serialize.md)
  output as safe to embed in another page.
- It does not fetch pages or resolve anything over the network:
  [`html_url()`](https://pedrobtz.github.io/zuhtml/reference/html_url.md)
  is string arithmetic.
- It does not run JavaScript, compute CSS or layout, or know what is
  visible.
  [`html_text_clean()`](https://pedrobtz.github.io/zuhtml/reference/html_text_clean.md)
  follows fixed, documented rules.
- It has no XPath and does not edit documents.
