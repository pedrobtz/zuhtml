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
  a byte-order mark, the page's declaration, or UTF-8.

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

A raw vector is decoded with, in order of precedence, a byte-order mark
(UTF-8, UTF-16LE or UTF-16BE), `encoding`, a declaration in the page, or
UTF-8. A byte-order mark that contradicts `encoding` is an error, and so
is any byte sequence that is invalid in the chosen encoding: nothing is
replaced silently. A fetcher that knows the HTTP charset should pass it
as `encoding`.

The declaration is found as browsers find it, by the HTML standard's
prescan of the first 1024 bytes for `<meta charset="...">` or
`<meta http-equiv="Content-Type" content="...; charset=...">`. The
prescan skips comments and the insides of tags, but not the text of
scripts. Labels are those of the Encoding Standard, which maps several
to a superset: `"iso-8859-1"`, `"latin1"` and `"us-ascii"` mean
windows-1252, `"gb2312"` means GBK, and a UTF-16 label means UTF-8 (the
bytes read as ASCII, so they are not UTF-16). An unknown label is
ignored.
[`html_info()`](https://pedrobtz.github.io/zuhtml/reference/html_info.md)
reports the encoding used and its source.

A file saved in another encoding without updating its declaration, as
some tools do when they convert pages to UTF-8, decodes wrongly or fails
to decode, as it would in a browser. Pass its real encoding as
`encoding`.

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
