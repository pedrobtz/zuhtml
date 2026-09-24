# Parse HTML

`html_parse()` parses one string or raw vector of HTML the way a browser
does: omitted end tags, unquoted attributes, character references and
misnested elements are repaired by the HTML parsing algorithm, never
rejected. `html_read()` reads and parses one local file.

## Usage

``` r
html_parse(
  x,
  encoding = NULL,
  base_url = NULL,
  comments = TRUE,
  limits = html_limits()
)

html_read(path, ...)
```

## Arguments

- x:

  One string, or a raw vector of encoded bytes.

- encoding:

  The encoding of raw input, as a name
  [`iconv()`](https://rdrr.io/r/base/iconv.html) accepts; `NULL` to use
  a byte-order mark or UTF-8.

- base_url:

  The document's URL, used to resolve relative links; `NULL` if unknown.

- comments:

  Whether to keep comment nodes.

- limits:

  Resource limits from
  [`html_limits()`](https://pedrobtz.github.io/zuhtml/reference/html_limits.md).

- path:

  Path of one local file.

- ...:

  Arguments passed on to `html_parse()`.

## Value

A `zuhtml_document`.

## Details

Neither function fetches anything. `html_parse()` never treats a string
as a file name or URL, and `html_read()` never downloads.

## Encoding

A character string is taken as text: it is converted to UTF-8 with
[`enc2utf8()`](https://rdrr.io/r/base/Encoding.html), and `encoding`
must be `NULL` or `"UTF-8"`. A string marked as `"bytes"` is rejected;
pass a raw vector instead.

A raw vector is decoded with, in order of precedence, `encoding`, a
byte-order mark (UTF-8, UTF-16LE or UTF-16BE), or UTF-8. A byte-order
mark that contradicts `encoding` is an error, and so is any byte
sequence that is invalid in the chosen encoding: nothing is replaced
silently. `<meta charset>` declarations are not consulted. A fetcher
that knows the HTTP charset should pass it as `encoding`.

A leading byte-order mark is removed. Input containing a NUL character
after decoding is rejected.

## See also

[`html_problems()`](https://pedrobtz.github.io/zuhtml/reference/html_problems.md)
for the parse errors that were repaired;
[`html_limits()`](https://pedrobtz.github.io/zuhtml/reference/html_limits.md);
[zuhtml-conditions](https://pedrobtz.github.io/zuhtml/reference/zuhtml-conditions.md)
for the errors these functions raise.

Other parsing:
[`html_fragment()`](https://pedrobtz.github.io/zuhtml/reference/html_fragment.md),
[`html_info()`](https://pedrobtz.github.io/zuhtml/reference/html_info.md),
[`html_limits()`](https://pedrobtz.github.io/zuhtml/reference/html_limits.md),
[`html_problems()`](https://pedrobtz.github.io/zuhtml/reference/html_problems.md),
[`zuhtml_info()`](https://pedrobtz.github.io/zuhtml/reference/zuhtml_info.md)

## Examples

``` r
doc <- html_parse("<p>Hello <b>world</b>")
doc
#> <zuhtml_document>
#> root:     <html> with <head>, <body>
#> nodes:    8
#> input:    21 bytes (UTF-8)
#> problems: 1

# Raw bytes in a declared encoding:
html_parse(as.raw(c(0x3c, 0x70, 0x3e, 0xe9)), encoding = "latin1")
#> <zuhtml_document>
#> root:     <html> with <head>, <body>
#> nodes:    6
#> input:    5 bytes (latin1)
#> problems: 1

# From a file:
path <- tempfile(fileext = ".html")
writeLines("<title>Saved page</title><p>Text", path)
html_read(path)
#> <zuhtml_document>
#> root:     <html> with <head>, <body>
#> nodes:    8
#> input:    33 bytes (UTF-8)
#> problems: 1
```
