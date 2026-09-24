test_that("the design's example keeps leading zeros", {
  t <- tab(paste0(
    "<table><thead><tr><th>Product<th>Price</thead>",
    "<tbody><tr><td>0012<td>12.50<tr><td>0034<td>9.00</tbody></table>"
  ))
  expect_s3_class(t, "data.frame")
  expect_identical(names(t), c("Product", "Price"))
  expect_identical(t$Product, c("0012", "0034"))
  expect_identical(t$Price, c("12.50", "9.00"))
})

test_that("header = 'auto' uses leading all-<th> rows without a thead", {
  t <- tab("<table><tr><th>a<th>b<tr><td>1<td>2</table>")
  expect_identical(names(t), c("a", "b"))
  expect_identical(nrow(t), 1L)
  # A row header in a data row does not make a header row.
  t <- tab("<table><tr><th>r1<td>1<tr><th>r2<td>2</table>")
  expect_identical(names(t), c("V1", "V2"))
  expect_identical(t$V1, c("r1", "r2"))
})

test_that("header = TRUE, FALSE and row numbers", {
  html <- "<table><tr><td>a<td>b<tr><td>c<td>d<tr><td>e<td>f</table>"
  expect_identical(names(tab(html, header = TRUE)), c("a", "b"))
  expect_identical(nrow(tab(html, header = TRUE)), 2L)
  expect_identical(names(tab(html, header = FALSE)), c("V1", "V2"))
  expect_identical(nrow(tab(html, header = FALSE)), 3L)
  t <- tab(html, header = c(1, 2))
  expect_identical(names(t), c("a / c", "b / d"))
  expect_identical(t$`a / c`, "e")
  expect_error(tab(html, header = c(2, 1)), class = "zuhtml_input_error")
  expect_error(tab(html, header = 4), class = "zuhtml_input_error")
  expect_error(tab(html, header = 0), class = "zuhtml_input_error")
  expect_error(tab(html, header = "yes"), class = "zuhtml_input_error")
})

test_that("multi-row headers join with ' / ' and merge colspan repeats", {
  t <- tab(paste0(
    "<table><tr><th rowspan=2>Region<th colspan=2>Sales",
    "<tr><th>2025<th>2026<tr><td>North<td>1<td>2</table>"
  ))
  expect_identical(names(t), c("Region", "Sales / 2025", "Sales / 2026"))
  expect_identical(unname(unlist(t)), c("North", "1", "2"))
})

test_that("row and column spans repeat their value", {
  t <- tab(paste0(
    "<table><tr><td rowspan=2>a<td>b<tr><td>c",
    "<tr><td colspan=2>d</table>"
  ), header = FALSE)
  expect_identical(t$V1, c("a", "a", "d"))
  expect_identical(t$V2, c("b", "c", "d"))
})

test_that("rowspan=0 extends to the end of its row group only", {
  t <- tab(paste0(
    "<table><tbody><tr><td rowspan=0>x<td>1<tr><td>2<tr><td>3</tbody>",
    "<tbody><tr><td>y<td>4</tbody></table>"
  ), header = FALSE)
  expect_identical(t$V1, c("x", "x", "x", "y"))
  expect_identical(t$V2, c("1", "2", "3", "4"))
})

test_that("positive rowspans are clipped at the end of their group", {
  t <- tab(paste0(
    "<table><thead><tr><th rowspan=5>h<th>k</thead>",
    "<tbody><tr><td>1<td>2</tbody></table>"
  ))
  expect_identical(names(t), c("h", "k"))
  expect_identical(t$h, "1")
})

test_that("huge and invalid spans are read by HTML's rules", {
  t <- tab("<table><tr><td colspan=' +2abc'>a<td colspan=0>b<td colspan=x>c</table>",
           header = FALSE)
  expect_identical(unname(unlist(t)), c("a", "a", "b", "c"))
  err <- expect_error(
    tab("<table><tr><td colspan=999999>a<td rowspan=70000>b</table>",
        limits = html_limits(max_table_cells = 500)),
    class = "zuhtml_limit_error"
  )
  expect_identical(err$limit, "max_table_cells")
  t <- tab("<table><tr><td colspan=999999>a</table>", header = FALSE)
  expect_identical(ncol(t), 1000L)
})

test_that("overlapping spans are an error, not an overwrite", {
  err <- expect_error(
    tab("<table><tr><td>a<td rowspan=2>b<tr><td colspan=2>c</table>"),
    class = "zuhtml_table_structure_error"
  )
  expect_identical(err$row, 2L)
  expect_identical(err$cell, 1L)
})

test_that("ragged rows get NA; empty cells are ''", {
  t <- tab("<table><tr><td>a<td>b<td>c<tr><td>d<td></table>", header = FALSE)
  expect_identical(t$V3, c("c", NA))
  expect_identical(t$V2, c("b", ""))
})

test_that("na= marks text as missing after trimming", {
  t <- tab("<table><tr><td> - <td>n/a<td>0</table>", header = FALSE,
           na = c("-", "n/a"))
  expect_identical(unname(unlist(t)), c(NA, NA, "0"))
  expect_error(tab("<table>", na = NA), class = "zuhtml_input_error")
})

test_that("row groups are ordered head, bodies, foot; footers are data", {
  t <- tab(paste0(
    "<table><tfoot><tr><td>foot</tfoot><tbody><tr><td>b1</tbody>",
    "<thead><tr><th>head</thead><tbody><tr><td>b2</tbody></table>"
  ))
  expect_identical(names(t), "head")
  expect_identical(t$head, c("b1", "b2", "foot"))
})

test_that("nested tables are excluded from cells and rows, as a break", {
  t <- tab(paste0(
    "<table><tr><th>a<th>b<tr><td>x<table><tr><td>inner</table>y<td>z",
    "</table>"
  ))
  expect_identical(t$a, "x\ny")
  expect_identical(nrow(t), 1L)
})

test_that("empty, header-only and duplicate-name tables", {
  expect_identical(dim(tab("<table></table>")), c(0L, 0L))
  expect_identical(dim(tab("<table><tr></tr></table>")), c(0L, 0L))
  t <- tab("<table><tr><th>a<th>b</table>")
  expect_identical(dim(t), c(0L, 2L))
  expect_identical(names(t), c("a", "b"))
  expect_type(t$a, "character")
  t <- tab("<table><tr><th>x<th>x<th><th>x<tr><td>1<td>2<td>3<td>4</table>")
  expect_identical(names(t), c("x", "x.1", "V3", "x.2"))
})

test_that("cell text is cleaned; trim = FALSE keeps outer spaces", {
  t <- tab("<table><tr><td>  a  <b>b</b>\n c </table>", header = FALSE)
  expect_identical(t$V1, "a b c")
  t <- tab("<table><tr><td>  a  </table>", header = FALSE, trim = FALSE)
  expect_identical(t$V1, " a ")
})

test_that("html_tables() reads outermost matches only", {
  doc <- html_parse(paste0(
    "<table id=t1><tr><th>A<tr><td>1<table><tr><th>N<tr><td>n</table></table>",
    "<table id=t2><tr><th>B<tr><td>2</table>"
  ))
  ts <- html_tables(doc)
  expect_length(ts, 2L)
  expect_identical(names(ts[[1L]]), "A")
  expect_identical(names(ts[[2L]]), "B")
  expect_identical(html_tables(doc, css = "#t2")[[1L]]$B, "2")
  expect_identical(html_tables(doc, css = "p"), list())
  # A nodeset of tables reads those tables.
  expect_length(html_tables(html_elements(doc, "table")), 2L)
  expect_identical(html_tables(doc, header = FALSE)[[2L]]$V1, c("B", "2"))
})

test_that("html_table() needs exactly one table element", {
  doc <- html_parse("<table></table><table></table><p>x</p>")
  expect_error(html_table(doc), class = "zuhtml_input_error")
  expect_error(html_table(html_elements(doc, "table")),
               class = "zuhtml_input_error")
  expect_error(html_table(html_element(doc, "p")),
               class = "zuhtml_input_error")
})
