# Cells of an HTML table

One row per cell of one `<table>`, with its position in the grid that
[`html_table()`](https://pedrobtz.github.io/zuhtml/reference/html_table.md)
builds: spans are placed, clipped and checked exactly as there, and rows
are numbered in the same logical order, header rows included. Use it
when the data frame loses what you need: which cells are headers, how
far they span, or the links inside them.

## Usage

``` r
html_table_cells(x, trim = TRUE, absolute = FALSE, limits = html_limits())
```

## Arguments

- x:

  A nodeset holding exactly one `<table>` element.

- trim:

  Whether to trim each cell's text; see
  [`html_text_clean()`](https://pedrobtz.github.io/zuhtml/reference/html_text_clean.md).

- absolute:

  If `TRUE`, links are resolved with
  [`html_url()`](https://pedrobtz.github.io/zuhtml/reference/html_url.md);
  otherwise they are `href` as written, as in
  [`html_links()`](https://pedrobtz.github.io/zuhtml/reference/html_links.md).

- limits:

  Resource limits from
  [`html_limits()`](https://pedrobtz.github.io/zuhtml/reference/html_limits.md);
  `max_table_cells` bounds the grid, spans included.

## Value

A data frame with one row per `<td>` or `<th>`, in grid order (by row,
then column), and columns:

- `row`, `column`: the integer position of the cell's top-left slot;

- `rowspan`, `colspan`: the integer number of rows and columns it
  covers, after `rowspan="0"` is expanded and spans are clipped;

- `section`: `"thead"`, `"tbody"` or `"tfoot"`; rows directly in the
  table are `"tbody"`;

- `header`: `TRUE` for a `<th>`;

- `text`: the cell's cleaned text, without nested tables, as in
  [`html_table()`](https://pedrobtz.github.io/zuhtml/reference/html_table.md);

- `links`: a list of character vectors, the `href` of each `<a>` and
  `<area>` in the cell, outside nested tables.

## See also

Other extraction:
[`html_forms()`](https://pedrobtz.github.io/zuhtml/reference/html_forms.md),
[`html_links()`](https://pedrobtz.github.io/zuhtml/reference/html_links.md),
[`html_list()`](https://pedrobtz.github.io/zuhtml/reference/html_list.md),
[`html_table()`](https://pedrobtz.github.io/zuhtml/reference/html_table.md),
[`html_url()`](https://pedrobtz.github.io/zuhtml/reference/html_url.md)

## Examples

``` r
doc <- html_parse(paste0(
  "<table><tr><th rowspan=2>Package<th colspan=2>Links",
  "<tr><th>Home<th>Docs",
  "<tr><td>zuhtml<td><a href='https://example.org/'>site</a>",
  "<td><a href='/ref/'>ref</a> <a href='/news/'>news</a></table>"
), base_url = "https://example.org/pkg/")
cells <- html_table_cells(html_element(doc, "table"), absolute = TRUE)
cells[, c("row", "column", "rowspan", "colspan", "header", "text")]
#>   row column rowspan colspan header     text
#> 1   1      1       2       1   TRUE  Package
#> 2   1      2       1       2   TRUE    Links
#> 3   2      2       1       1   TRUE     Home
#> 4   2      3       1       1   TRUE     Docs
#> 5   3      1       1       1  FALSE   zuhtml
#> 6   3      2       1       1  FALSE     site
#> 7   3      3       1       1  FALSE ref news
cells$links[[7]]
#> [1] "https://example.org/ref/"  "https://example.org/news/"
```
