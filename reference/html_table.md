# Extract HTML tables as data frames

`html_table()` reads one `<table>` element into a data frame of
character columns. `html_tables()` finds tables and reads each.

## Usage

``` r
html_table(
  x,
  header = "auto",
  trim = TRUE,
  na = character(),
  convert = FALSE,
  decimal = ".",
  thousands = NULL,
  limits = html_limits()
)

html_tables(x, css = "table", match = NULL, ...)
```

## Arguments

- x:

  For `html_table()`, a nodeset holding exactly one `<table>` element;
  for `html_tables()`, a `zuhtml_document` or `zuhtml_nodeset` to
  search.

- header:

  How to find header rows; see the Headers section.

- trim:

  Whether to trim each cell's text; see
  [`html_text_clean()`](https://pedrobtz.github.io/zuhtml/reference/html_text_clean.md).

- na:

  Strings that become `NA` after trimming, such as `c("", "-")`. By
  default no text is treated as missing.

- convert:

  If `TRUE`, convert columns that are entirely numbers or logicals; see
  the Conversion section.

- decimal:

  The decimal mark for `convert`: a single character.

- thousands:

  The grouping mark for `convert`: a single character other than
  `decimal`, or `NULL` for none.

- limits:

  Resource limits from
  [`html_limits()`](https://pedrobtz.github.io/zuhtml/reference/html_limits.md);
  `max_table_cells` bounds the grid, spans included.

- css:

  For `html_tables()`, the selector of tables to read. Only the
  outermost matching tables are read; nested ones remain part of their
  parents' cells.

- match:

  For `html_tables()`, a regular expression
  ([`grepl()`](https://rdrr.io/r/base/grep.html)) that a table's cleaned
  text must match for the table to be read, or `NULL` to read every
  table.

- ...:

  For `html_tables()`, arguments passed on to `html_table()`.

## Value

`html_table()`: a data frame of character columns. A table with no rows
gives a data frame with no rows and no columns; a table with only header
rows gives no rows and the named columns. `html_tables()`: a list of
such data frames, [`list()`](https://rdrr.io/r/base/list.html) when
there are none.

## The grid

Rows are read in logical order – every `<thead>`, then the `<tbody>`
sections (and any rows directly in the table), then every `<tfoot>` –
and footer rows are ordinary data rows. Rows of nested tables never
become rows of the outer table, and a nested table's text is left out of
the cell that holds it (it still separates the text around it with a
line break).

Each cell is placed at the next free column of its row. `colspan` and
`rowspan` are read with HTML's rules for non-negative integers: a
missing or invalid value is 1, `colspan="0"` is 1, and values are capped
at 1000 columns and 65534 rows. `rowspan="0"` extends to the end of the
cell's row group, and a larger `rowspan` is cut silently at the end of
its group. A spanned value is repeated in every slot it covers. A cell
whose span would cover a slot another cell already covers is an error of
class `zuhtml_table_structure_error`, never a silent overwrite. Slots no
cell covers, in ragged rows, are `NA`; an empty cell is `""`.

## Headers

- `"auto"`: the rows of `<thead>` sections if there are any, otherwise
  the leading rows whose cells are all `<th>` (a `<th>` among `<td>`s
  does not make a header row);

- `TRUE`: the first row; `FALSE`: none;

- a vector of row numbers: those rows.

Header rows are removed from the data. A column's name joins the
non-empty header texts above it with `" / "`, merging repeats that a
`colspan` created. Blank names become `V1`, `V2`, ... by column
position, and duplicates are made unique with
[`make.unique()`](https://rdrr.io/r/base/make.unique.html). Names are
not otherwise made syntactic.

Cell text follows
[`html_text_clean()`](https://pedrobtz.github.io/zuhtml/reference/html_text_clean.md).
All columns are character unless `convert = TRUE`.

## Conversion

With `convert = TRUE`, each column is converted on its own, and only
when every non-missing value converts; otherwise it stays character, so
conversion never turns a value into `NA`. Values are compared after
removing surrounding whitespace.

- `TRUE`, `FALSE`, `true`, `false`, `True` and `False` make a logical
  column.

- Decimal numbers, with an optional sign and exponent, make an integer
  column when all are whole and fit, otherwise a double column.
  `decimal` is the decimal mark. `thousands`, if given, is a grouping
  mark allowed between groups of three digits, as in `1,234,567.5`; a
  badly grouped value such as `1,23` keeps the column character.

- A value with a leading zero, such as `"0012"`, keeps the column
  character: it is an identifier, not a number. `"0"` and `"0.5"` are
  numbers.

- `Inf`, `NaN`, `NA`, currency symbols and percentages are not numbers;
  list such strings in `na`, or convert them yourself. A column with no
  non-missing values stays character.

## See also

Other extraction:
[`html_forms()`](https://pedrobtz.github.io/zuhtml/reference/html_forms.md),
[`html_links()`](https://pedrobtz.github.io/zuhtml/reference/html_links.md),
[`html_list()`](https://pedrobtz.github.io/zuhtml/reference/html_list.md),
[`html_table_cells()`](https://pedrobtz.github.io/zuhtml/reference/html_table_cells.md),
[`html_url()`](https://pedrobtz.github.io/zuhtml/reference/html_url.md)

## Examples

``` r
doc <- html_parse(paste0(
  "<table><thead><tr><th>Product<th>Price</thead>",
  "<tbody><tr><td>0012<td>12.50<tr><td>0034<td>9.00</tbody></table>"
))
html_table(html_element(doc, "table"))
#>   Product Price
#> 1    0012 12.50
#> 2    0034  9.00

doc <- html_parse(paste0(
  "<table><tr><th rowspan=2>Region<th colspan=2>Sales",
  "<tr><th>2025<th>2026<tr><td>North<td>1<td>2</table>"
))
html_tables(doc)
#> [[1]]
#>   Region Sales / 2025 Sales / 2026
#> 1  North            1            2
#> 
html_tables(doc, match = "North")
#> [[1]]
#>   Region Sales / 2025 Sales / 2026
#> 1  North            1            2
#> 

doc <- html_parse(paste0(
  "<table><tr><th>Id<th>Amount<th>Paid",
  "<tr><td>007<td>1.234,50<td>true<tr><td>012<td>99<td>false</table>"
))
str(html_table(html_element(doc, "table"), convert = TRUE,
               decimal = ",", thousands = "."))
#> 'data.frame':    2 obs. of  3 variables:
#>  $ Id    : chr  "007" "012"
#>  $ Amount: num  1234 99
#>  $ Paid  : logi  TRUE FALSE
```
