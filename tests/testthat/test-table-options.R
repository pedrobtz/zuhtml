test_that("html_table_cells() places spans as html_table() does", {
  c <- cells(paste0(
    "<table><thead><tr><th rowspan=2>A<th colspan=2>B</thead>",
    "<tbody><tr><th>b1<th>b2<tr><td>1<td rowspan=0>2<td>3",
    "<tr><td>4<td colspan=9>5</tbody>",
    "<tfoot><tr><td colspan=3>total</tfoot></table>"
  ))
  expect_named(c, c("row", "column", "rowspan", "colspan", "section",
                    "header", "text", "links"))
  expect_identical(c$text,
                   c("A", "B", "b1", "b2", "1", "2", "3", "4", "5", "total"))
  expect_identical(c$row, c(1L, 1L, 2L, 2L, 3L, 3L, 3L, 4L, 4L, 5L))
  # The thead rowspan is clipped, so b1 and b2 start at column 1; 5 skips
  # the column that 2 covers.
  expect_identical(c$column, c(1L, 2L, 1L, 2L, 1L, 2L, 3L, 1L, 3L, 1L))
  # rowspan=2 in thead is clipped to its group; rowspan=0 fills the tbody.
  expect_identical(c$rowspan, c(1L, 1L, 1L, 1L, 1L, 2L, 1L, 1L, 1L, 1L))
  # colspan=9 at column 3 widens the grid, as html_table() does.
  expect_identical(c$colspan, c(1L, 2L, 1L, 1L, 1L, 1L, 1L, 1L, 9L, 3L))
  expect_identical(c$section, rep(c("thead", "tbody", "tfoot"),
                                  c(2L, 7L, 1L)))
  expect_identical(c$header, rep(c(TRUE, FALSE), c(4L, 6L)))
  expect_identical(
    ncol(html_table(html_element(html_parse(paste0(
      "<table><tr><td>4<td colspan=9>5</table>")), "table"))),
    10L
  )
})

test_that("html_table_cells() lists links per cell, outside nested tables", {
  html <- paste0(
    "<table><tr><td><a href='a.html'>a</a> <a href='#top'>t</a>",
    "<td><map><area href='/m' alt=m></map><a>no href</a>",
    "<td><table><tr><td><a href='inner'>i</a></table>",
    "<a href='after'>after</a><td>none</table>"
  )
  c <- cells(html)
  expect_identical(c$links, list(c("a.html", "#top"), "/m", "after",
                                 character()))
  expect_identical(cells(html, absolute = TRUE)$links[[1]],
                   c("https://x.test/d/a.html", "https://x.test/d/#top"))
  expect_identical(c$text[3], "after")
})

test_that("html_table_cells() handles empty tables and validates", {
  c <- cells("<table></table>")
  expect_identical(nrow(c), 0L)
  expect_named(c, c("row", "column", "rowspan", "colspan", "section",
                    "header", "text", "links"))
  expect_identical(c$links, list())
  doc <- html_parse("<table><tr><td>1</table><p>")
  expect_error(html_table_cells(doc), class = "zuhtml_input_error")
  expect_error(html_table_cells(html_element(doc, "table"), absolute = NA),
               class = "zuhtml_input_error")
  expect_error(
    cells("<table><tr><td>a<td rowspan=2>b<tr><td colspan=2>c</table>"),
    class = "zuhtml_table_structure_error"
  )
  expect_error(
    cells("<table><tr><td colspan=50>a</table>",
          limits = html_limits(max_table_cells = 10)),
    class = "zuhtml_limit_error"
  )
})

test_that("html_tables(match =) keeps tables whose text matches", {
  doc <- html_parse(paste0(
    "<table id=a><tr><th>Name<th>Price<tr><td>Tea<td>3</table>",
    "<table id=b><tr><th>City<th>Pop<tr><td>Oslo<td>7</table>",
    "<table id=c><tr><td>outer<td><table><tr><td>Price</table></table>"
  ))
  got <- html_tables(doc, match = "Price")
  expect_length(got, 2L)
  expect_named(got[[1]], c("Name", "Price"))
  expect_identical(got[[2]]$V1, "outer")
  expect_identical(html_tables(doc, match = "^City"), list(html_tables(doc)[[2]]))
  expect_identical(html_tables(doc, match = "nothing"), list())
  expect_identical(html_tables(doc, match = "Tea", convert = TRUE)[[1]]$Price,
                   3L)
  expect_error(html_tables(doc, match = c("a", "b")),
               class = "zuhtml_input_error")
  expect_error(html_tables(doc, match = NA_character_),
               class = "zuhtml_input_error")
})

test_that("convert = TRUE converts only whole columns", {
  t <- tab(paste0(
    "<table><tr><th>int<th>dbl<th>id<th>mixed<th>lgl<th>exp<th>zero",
    "<th>blank<th>big",
    "<tr><td> 12 <td>-1.5<td>0012<td>7<td>TRUE<td>1e3<td>0<td><td>3000000000",
    "<tr><td>+3<td>.25<td>0034<td>n/a<td>false<td>2.5E-1<td>0.5<td>1",
    "<td>1</table>"
  ), convert = TRUE)
  expect_identical(t$int, c(12L, 3L))
  expect_identical(t$dbl, c(-1.5, 0.25))
  expect_identical(t$id, c("0012", "0034"))
  expect_identical(t$mixed, c("7", "n/a"))
  expect_identical(t$lgl, c(TRUE, FALSE))
  expect_identical(t$exp, c(1000, 0.25))
  expect_identical(t$zero, c(0, 0.5))
  # "" is not a number unless na says it is missing.
  expect_identical(t$blank, c("", "1"))
  expect_identical(t$big, c(3e9, 1))

  t <- tab(paste0(
    "<table><tr><th>blank<th>none<th>dash",
    "<tr><td><td><td>-<tr><td>1<td><td>2</table>"
  ), convert = TRUE, na = c("", "-"))
  expect_identical(t$blank, c(NA, 1L))
  expect_identical(t$none, c(NA_character_, NA_character_))
  expect_identical(t$dash, c(NA, 2L))
  expect_identical(tab("<table><tr><td>1</table>", header = FALSE)$V1, "1")
})

test_that("convert = TRUE reads decimal and grouping marks", {
  html <- paste0(
    "<table><tr><th>a<th>b",
    "<tr><td>1,234,567.5<td>1.234<tr><td>12<td>1,5</table>"
  )
  t <- tab(html, convert = TRUE, thousands = ",")
  expect_identical(t$a, c(1234567.5, 12))
  # "1,5" is badly grouped for thousands = ",": the column stays character.
  expect_identical(t$b, c("1.234", "1,5"))
  t <- tab(html, convert = TRUE, decimal = ",")
  expect_identical(t$a, c("1,234,567.5", "12"))
  # With a decimal comma and no grouping mark, "1.234" is not a number.
  expect_identical(t$b, c("1.234", "1,5"))
  expect_identical(
    tab("<table><tr><th>c<tr><td>1,5<tr><td>-,25</table>", convert = TRUE,
        decimal = ",")$c,
    c(1.5, -0.25)
  )
  t <- tab(paste0(
    "<table><tr><th>eu<th>space<tr><td>1.234,50<td>12 345",
    "<tr><td>-0,5<td>7</table>"
  ), convert = TRUE, decimal = ",", thousands = ".")
  expect_identical(t$eu, c(1234.5, -0.5))
  expect_identical(t$space, c("12 345", "7"))
  expect_identical(
    tab("<table><tr><th>s<tr><td>12 345<tr><td>7</table>", convert = TRUE,
        thousands = " ")$s,
    c(12345L, 7L)
  )
})

test_that("convert options are validated", {
  html <- "<table><tr><td>1</table>"
  for (bad in list(NA, "yes", c(TRUE, FALSE))) {
    expect_error(tab(html, convert = bad), class = "zuhtml_input_error")
  }
  for (bad in list("", "..", "1", "-", NA_character_, 1)) {
    expect_error(tab(html, decimal = bad), class = "zuhtml_input_error")
  }
  expect_error(tab(html, thousands = "."), class = "zuhtml_input_error")
  expect_error(tab(html, thousands = "e"), class = "zuhtml_input_error")
  expect_identical(tab(html, header = FALSE, convert = TRUE,
                       decimal = "]", thousands = "^")$V1, 1L)
})
