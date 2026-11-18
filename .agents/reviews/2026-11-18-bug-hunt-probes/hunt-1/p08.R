source("h.R")
T <- function(h, ...) html_table(html_element(html_parse(h), "table"), ...)
h <- "<table><tr><th>h<tr><td>1&nbsp;000<tr><td>2&nbsp;500</table>"
p("thousands=U+00A0", str(T(h, convert = TRUE, thousands = " ")))
p("thousands=U+0020", str(T(h, convert = TRUE, thousands = " ")))
p("na=U+00A0 text", T("<table><tr><td>a&nbsp;b<td>x</table>", header = FALSE, na = "a b"))
# html_table vs html_table_cells
h <- "<table><caption><a href=c>cap</a></caption><thead><tr><th rowspan=2>R<th colspan=2>S<tr><th>a<th>b</thead><tfoot><tr><td>f1<td>f2<td>f3</tfoot><tr><td rowspan=0>n<td><a href='/x'>l</a> <a href=y>m</a><td><table><tr><td><a href=inner>i</a></table>after<tr><td>p<td>q<td>extra</table>"
d <- html_parse(h, base_url = "http://h/d/"); t <- html_element(d, "table")
p("table", html_table(t)); cl <- p("cells", html_table_cells(t, absolute = TRUE)); str(cl$links)
p("cells empty", str(html_table_cells(html_element(html_parse("<table></table>"), "table"))))
p("cells row no cell", str(html_table_cells(html_element(html_parse("<table><tr></tr></table>"), "table"))))
p("cells flags", list(tr(html_table_cells(t, trim = 1)), tr(html_table_cells(t, absolute = NA)), tr(html_table_cells(t, limits = 5))))
p("cells nobase abs", html_table_cells(html_element(html_parse("<table><tr><td><a href=x>l</a><a href='http://a/b'>m</a></table>"), "table"), absolute = TRUE)$links)
p("overlap", tr(html_table(html_element(html_parse("<table><tr><td rowspan=2>a<td>b<tr><td colspan=2>c</table>"), "table")))$e[c("row","cell")])
# table in fragment / thead order
p("thead after", html_table(html_element(html_parse("<table><tr><td>1<td>2<thead><tr><th>a<th>b</thead></table>"), "table")))
p("th in first col", html_table(html_element(html_parse("<table><tr><th>k<td>1<tr><th>j<td>2</table>"), "table")))
p("header TRUE multi thead", html_table(html_element(html_parse("<table><thead><tr><th>a<tr><th>b</thead><tr><td>1</table>"), "table"), header = TRUE))
