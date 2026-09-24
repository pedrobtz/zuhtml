# Tables and lists

``` r

library(zuhtml)
```

## Tables

[`html_table()`](https://pedrobtz.github.io/zuhtml/reference/html_table.md)
reads one `<table>` into a data frame;
[`html_tables()`](https://pedrobtz.github.io/zuhtml/reference/html_table.md)
finds tables and reads each. Every column is character, so identifiers
keep their leading zeros.

``` r

doc <- html_parse("
<table>
  <thead><tr><th>Code<th>Price</thead>
  <tr><td>0012<td>12.50
  <tr><td>0034<td>9.00
</table>")
html_table(html_element(doc, "table"))
#>   Code Price
#> 1 0012 12.50
#> 2 0034  9.00
```

### Spans

A value that spans rows or columns is repeated in every slot it covers,
and a column’s name joins the header rows above it with `" / "`:

``` r

doc <- html_parse("
<table>
  <tr><th rowspan=2>Region<th colspan=2>Sales
  <tr><th>2025<th>2026
  <tr><td>North<td>10<td>12
  <tr><td rowspan=2>South<td>7<td>9
  <tr><td>8<td>11
</table>")
html_table(html_element(doc, "table"))
#>   Region Sales / 2025 Sales / 2026
#> 1  North           10           12
#> 2  South            7            9
#> 3  South            8           11
```

`rowspan="0"` runs to the end of its row group, and a rowspan larger
than the rows left in its group is cut there. Two cells whose spans
cover the same slot are an error, not a silent overwrite:

``` r

doc <- html_parse("<table><tr><td>a<td rowspan=2>b<tr><td colspan=2>c</table>")
try(html_table(html_element(doc, "table")))
#> Error in html_table(html_element(doc, "table")) : 
#>   Cell 1 of row 2 spans a slot another cell already covers.
```

### Headers

With the default `header = "auto"`, the rows of `<thead>` are headers if
there is one, otherwise the leading rows made only of `<th>` cells. A
`<th>` among `<td>`s is a row label, not a header. Use `TRUE`, `FALSE`
or row numbers to choose explicitly:

``` r

doc <- html_parse("<table><tr><td>name<td>qty<tr><td>tea<td>2</table>")
tab <- html_element(doc, "table")
html_table(tab)
#>     V1  V2
#> 1 name qty
#> 2  tea   2
html_table(tab, header = TRUE)
#>   name qty
#> 1  tea   2
```

Blank names become `V1`, `V2`, …; duplicate names get
[`make.unique()`](https://rdrr.io/r/base/make.unique.html) suffixes.
Rows are read head first, then bodies, then footers, and footers are
data. Rows of a table nested inside a cell stay out of the outer table,
and the nested table’s text stays out of the cell.

Missing slots (in ragged rows) are `NA`; an empty cell is `""`. Mark
placeholders as missing with `na`:

``` r

doc <- html_parse("<table><tr><th>a<th>b<tr><td>1<td>-<tr><td>2</table>")
html_table(html_element(doc, "table"), na = "-")
#>   a    b
#> 1 1 <NA>
#> 2 2 <NA>
```

## Lists

[`html_list()`](https://pedrobtz.github.io/zuhtml/reference/html_list.md)
reads one `<ul>` or `<ol>`. Each item’s text leaves out the lists nested
inside it:

``` r

doc <- html_parse("
<ul>
  <li>Fruit
    <ul><li>Apple<li>Pear</ul>
  <li>Tools
    <div><ol><li>Hammer<li>Saw</ol></div>
</ul>")
menu <- html_element(doc, "ul")
html_list(menu)
#> [1] "Fruit" "Tools"
```

`mode = "tree"` keeps the nesting, including lists inside wrapper
elements such as the `<div>` above:

``` r

tree <- html_list(menu, mode = "tree")
tree
#> <zuhtml_list ul, 2 items>
#> - Fruit
#>   - Apple
#>   - Pear
#> - Tools
#>   1. Hammer
#>   2. Saw
tree$items[[2]]$children[[1]]$type
#> [1] "ol"
```

To read many lists, [`lapply()`](https://rdrr.io/r/base/lapply.html)
over a nodeset passes one node at a time:

``` r

lapply(html_elements(doc, "ul ul, ol"), html_list)
#> [[1]]
#> [1] "Apple" "Pear" 
#> 
#> [[2]]
#> [1] "Hammer" "Saw"
```
