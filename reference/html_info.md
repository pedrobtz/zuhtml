# Information about a parsed document

Information about a parsed document

## Usage

``` r
html_info(x)
```

## Arguments

- x:

  A `zuhtml_document`, or a `zuhtml_nodeset` for the document that owns
  it.

## Value

An object of class `zuhtml_doc_info`: a list with

- `type`: `"document"` or `"fragment"`;

- `context`: a fragment's context element, `NA` for a document;

- `nodes`, `attributes`: counts;

- `native_bytes`: memory the document owns, outside R's heap;

- `parse_peak_bytes`: the most memory the parser held at once;

- `input_bytes`: size of the decoded UTF-8 input;

- `encoding`: the encoding the input was decoded from;

- `base_url`: the `base_url` given to
  [`html_parse()`](https://pedrobtz.github.io/zuhtml/reference/html_parse.md),
  or `NA`;

- `quirks_mode`: `"no-quirks"`, `"quirks"` or `"limited-quirks"`, as the
  doctype selected;

- `problems`: the number of parse problems kept, and
  `problems_truncated`: whether more occurred than `max_errors`.

## See also

Other parsing:
[`html_fragment()`](https://pedrobtz.github.io/zuhtml/reference/html_fragment.md),
[`html_parse()`](https://pedrobtz.github.io/zuhtml/reference/html_parse.md)

## Examples

``` r
html_info(html_parse("<!DOCTYPE html><title>t</title><p>Hello"))
#> <zuhtml_doc_info>
#>   type               document
#>   context            NA
#>   nodes              9
#>   attributes         0
#>   native_bytes       555
#>   parse_peak_bytes   2,307
#>   input_bytes        39
#>   encoding           UTF-8
#>   base_url           NA
#>   quirks_mode        no-quirks
#>   problems           0
#>   problems_truncated FALSE
```
