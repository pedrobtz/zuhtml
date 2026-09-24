# Resource limits for parsing and extraction

Every parse and extraction runs under explicit limits, so that untrusted
HTML cannot exhaust memory or time. Limits are per call, not global
options: pass the result to the `limits` argument of
[`html_parse()`](https://pedrobtz.github.io/zuhtml/reference/html_parse.md)
and the extraction functions. Exceeding one raises a
`zuhtml_limit_error` (see
[zuhtml-conditions](https://pedrobtz.github.io/zuhtml/reference/zuhtml-conditions.md))
after all native memory is released.

## Usage

``` r
html_limits(
  max_input = 16 * 1024^2,
  max_memory = 512 * 1024^2,
  max_depth = 512,
  max_nodes = 4e+06,
  max_errors = 100,
  max_table_cells = 1e+06,
  max_selector_length = 16 * 1024
)
```

## Arguments

- max_input:

  Largest input, in bytes of UTF-8 after decoding.

- max_memory:

  Largest native memory the parser may hold at once, in bytes.

- max_depth:

  Deepest nesting of open elements. Parsing time grows with the square
  of nesting depth, so this bounds it; it is enforced while parsing, not
  afterwards.

- max_nodes:

  Most nodes a document may have.

- max_errors:

  Most parse problems kept for
  [`html_problems()`](https://pedrobtz.github.io/zuhtml/reference/html_problems.md).
  Parsing continues past it; only the record is truncated.

- max_table_cells:

  Most cells a table may expand to, spans included.

- max_selector_length:

  Longest CSS selector, in bytes.

## Value

An object of class `zuhtml_limits`: a named list of the limits, as
doubles.

## Details

The memory limit is the real guard; the input limit is a cheap check
before parsing starts. Parsing and conversion together need about 26
bytes of native memory per input byte on ordinary markup, and 40 to 90
on markup dense with small elements, tables or formatting, so a large
enough page reaches `max_memory` before `max_input` or `max_nodes`: a
`zuhtml_limit_error`, not a crash. At the defaults, 16 MiB of ordinary
markup (about 1.5 million nodes, 450 MB) parses.

## Examples

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

# A tighter nesting limit for a service parsing untrusted pages:
lim <- html_limits(max_depth = 128)
try(html_parse(strrep("<div>", 200), limits = lim))
#> Error in html_parse(strrep("<div>", 200), limits = lim) : 
#>   Elements are nested deeper than max_depth = 128.
```
