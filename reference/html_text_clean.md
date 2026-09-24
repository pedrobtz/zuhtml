# Cleaned text for extraction

Text as a reader would want it from a page, rather than exactly as
parsed. It is not a browser's `innerText`: there is no layout or CSS,
and hidden elements are included. The rules are fixed and documented:

- text inside `<script>`, `<style>` and `<template>` is skipped, and so
  are comments;

- runs of whitespace (space, tab, newline, carriage return, form feed)
  collapse to a single space, except inside `<pre>`, `<textarea>`,
  `<listing>` and `<plaintext>`, where whitespace is kept;

- `<br>` is a line break; each block element is a line break before and
  after, and adjacent block boundaries give a single line break. The
  block elements are `address`, `article`, `aside`, `blockquote`,
  `body`, `caption`, `center`, `dd`, `details`, `dialog`, `dir`, `div`,
  `dl`, `dt`, `fieldset`, `figcaption`, `figure`, `footer`, `form`, `h1`
  to `h6`, `head`, `header`, `hgroup`, `hr`, `html`, `legend`, `li`,
  `listing`, `main`, `menu`, `nav`, `ol`, `optgroup`, `option`, `p`,
  `plaintext`, `pre`, `section`, `summary`, `table`, `tbody`, `tfoot`,
  `thead`, `title`, `tr`, `ul` and `xmp`;

- table cells (`<td>`, `<th>`) are separated by a space.

## Usage

``` r
html_text_clean(x, trim = TRUE, nbsp = TRUE)
```

## Arguments

- x:

  A `zuhtml_document` or `zuhtml_nodeset`.

- trim:

  If `TRUE`, no whitespace at the start or end. If `FALSE`, whitespace
  there is kept, collapsed to a single space.

- nbsp:

  If `TRUE`, treat non-breaking spaces (U+00A0) as whitespace, so they
  collapse like spaces; inside `<pre>` they become spaces.

## Value

A character vector as long as `x`: the cleaned text of each element,
document, fragment or text node; `NA` for other nodes and for missing
nodes.

## See also

[`html_text()`](https://pedrobtz.github.io/zuhtml/reference/html_text.md)
for the text exactly as parsed.

Other node values:
[`html_attr()`](https://pedrobtz.github.io/zuhtml/reference/html_attr.md),
[`html_markdown()`](https://pedrobtz.github.io/zuhtml/reference/html_markdown.md),
[`html_name()`](https://pedrobtz.github.io/zuhtml/reference/html_name.md),
[`html_serialize()`](https://pedrobtz.github.io/zuhtml/reference/html_serialize.md),
[`html_strings()`](https://pedrobtz.github.io/zuhtml/reference/html_strings.md),
[`html_text()`](https://pedrobtz.github.io/zuhtml/reference/html_text.md)

## Examples

``` r
doc <- html_parse(paste0(
  "<div><h1>Title</h1>\n  <p>Some   <b>bold</b> text.<br>New line",
  "<script>ignored()</script></p><pre>  kept\n  as is</pre></div>"
))
div <- html_element(doc, "div")
cat(html_text_clean(div))
#> Title
#> Some bold text.
#> New line
#>   kept
#>   as is
html_text(div)
#> [1] "Title\n  Some   bold text.New lineignored()  kept\n  as is"
```
