# Parse an HTML fragment

Parses markup as the contents of a given element, as a browser does for
`innerHTML`. The context matters: `"<tr><td>x"` is a table row in a
`"tbody"` context but only text in a `"div"`.

## Usage

``` r
html_fragment(x, context = "div", ...)
```

## Arguments

- x:

  One string, or a raw vector of encoded bytes.

- context:

  The name of the context element, an HTML element the bundled parser
  knows, such as `"div"`, `"tbody"`, `"select"` or `"template"`.

- ...:

  Arguments passed on to
  [`html_parse()`](https://pedrobtz.github.io/zuhtml/reference/html_parse.md):
  `encoding`, `base_url`, `comments` and `limits`.

## Value

A `zuhtml_document` whose document node is a fragment:
[`html_type()`](https://pedrobtz.github.io/zuhtml/reference/html_name.md)
reports `"fragment"`, and
[`html_root()`](https://pedrobtz.github.io/zuhtml/reference/html_children.md)
returns the fragment node, whose children are the parsed nodes.

## See also

[`html_parse()`](https://pedrobtz.github.io/zuhtml/reference/html_parse.md)
for whole documents.

Other parsing:
[`html_info()`](https://pedrobtz.github.io/zuhtml/reference/html_info.md),
[`html_limits()`](https://pedrobtz.github.io/zuhtml/reference/html_limits.md),
[`html_parse()`](https://pedrobtz.github.io/zuhtml/reference/html_parse.md),
[`html_problems()`](https://pedrobtz.github.io/zuhtml/reference/html_problems.md),
[`zuhtml_info()`](https://pedrobtz.github.io/zuhtml/reference/zuhtml_info.md)

## Examples

``` r
frag <- html_fragment("<tr><td>1<td>2", context = "tbody")
html_children(html_root(frag))
#> <zuhtml_nodeset[1]>
#> [1] <tr>
html_fragment("<tr><td>1<td>2")
#> <zuhtml_document>
#> fragment: in <div>
#> nodes:    2
#> input:    14 bytes (UTF-8)
#> problems: 3
```
