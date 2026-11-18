source("h.R")
T <- function(h, ...) html_table(html_element(html_parse(h), "table"), ...)
C <- function(vals, ...) { h <- paste0("<table><tr><th>h", paste0("<tr><td>", vals, collapse = ""), "</table>"); r <- T(h, convert = TRUE, ...)[[1]]; cat(sprintf("%-40s -> %s %s\n", paste(vals, collapse="|"), class(r), paste(format(r, digits = 17), collapse = " | "))) }
C(c("1","2")); C(c("1","","3")); C(c("1"," ","3")); C(c("1","&nbsp;","3")); C(c("1","","3"), na = ""); C(c("1","-","3"), na = "-"); C(c("1.5","2")); C(c("1e3","2")); C(c("1.","2")); C(c(".5")); C(c("+5","-3")); C("007"); C(c("0","0.5","-0")); C("1e999"); C("12345678901234567890"); C("0.12345678901234567890123"); C("2147483647"); C("2147483648"); C("-2147483648")
C(c("TRUE","false","True")); C(c("TRUE","")); C(c("T","F")); C(c("true","1")); C(c("NA","1")); C(c("NA","1"), na = "NA"); C(c("Inf")); C("0x1A"); C("1 000"); C("1 000", thousands = " "); C("1&nbsp;000", thousands = " "); C("1&nbsp;000", thousands = " "); C("1&#8239;000", thousands = " ")
C(c("1,234.5","12"), thousands = ","); C("1,23", thousands = ","); C("1234,567", thousands = ","); C("0,123", thousands = ","); C("1.234,5", decimal = ",", thousands = "."); C("1.5", decimal = ","); C("1,5", decimal = ","); C("1,5e3", decimal = ","); C(",5", decimal = ","); C("1.000", decimal = ",", thousands = "."); C("1.000")
C("1'234", thousands = "'"); C("1^5", decimal = "^"); C("1\\5", decimal = "\\"); C("1]5", decimal = "]"); C("1[5", decimal = "["); C("1|5", decimal = "|"); C("1*5", decimal = "*"); C("1a5", decimal = "a"); C("1 5", decimal = " "); C("1$5", decimal = "$"); C("1)5", decimal = ")"); C("1é5", decimal = "é")
C(c("1","2")," extra"); 
for (dv in list("", "..", NA_character_, 1, NULL, c(".", ","), "e", "5", "-", "+", "E")) { cat("decimal", deparse(dv), ": "); print(tr(class(T("<table><tr><td>1</table>", convert = TRUE, decimal = dv)[[1]]))) }
for (tv in list("", ".", NA_character_, 1, c(".", ","), ",,", TRUE)) { cat("thousands", deparse(tv), ": "); print(tr(class(T("<table><tr><td>1</table>", convert = TRUE, thousands = tv)[[1]]))) }
for (cv in list(NA, "yes", 1, c(TRUE, FALSE), NULL)) { cat("convert", deparse(cv), ": "); print(tr(class(T("<table><tr><td>1</table>", convert = cv)[[1]]))) }
p("convert=FALSE bad decimal", T("<table><tr><td>1</table>", decimal = "xx"))
h <- "<table><tr><th>A<th>B<tr><td>1<td>2<tr><td>3<td>4<tr><td>5<td>6</table>"
for (hv in list("auto", TRUE, FALSE, 1, 2, c(1,2), c(2,1), c(1,1), 0, -1, 1.5, 5, NA, NA_real_, NULL, "AUTO", c("auto","auto"), 1L, 2^31, Inf, numeric(0), "1", factor("auto"), c(TRUE,TRUE), list(1), c(a = 1), c(1, 3))) { cat("header", deparse(hv)[1], ":\n"); print(tr(T(h, header = hv))) }
p("empty table bad header", T("<table></table>", header = "junk"))
p("empty table bad na", T("<table></table>", na = 1))
p("row no cells", T("<table><tr></tr></table>"))
p("header only", str(T("<table><thead><tr><th>a<th>b</thead></table>", convert = TRUE)))
p("all th", str(T("<table><tr><th>a<th>b<tr><th>c<th>d</table>")))
p("dup hdr", names(T("<table><tr><th>a<th>a<th><th>V3<th>a.1<tr><td>1<td>2<td>3<td>4<td>5</table>")))
p("multi hdr", names(T("<table><thead><tr><th>Total<th colspan=2>X<tr><th>Total<th>a<th>b</thead><tr><td>1<td>2<td>3</table>")))
p("multi hdr same text different meaning", names(T("<table><thead><tr><th>2020<th>2020<tr><th>2020<th>Q1</thead><tr><td>1<td>2</table>")))
p("ragged", T("<table><tr><td>1<td>2<td>3<tr><td>4</table>", header = FALSE))
p("ragged header", T("<table><tr><th>a<tr><td>1<td>2<td>3</table>"))
p("na trim", T("<table><tr><td> - <td>-<td>x</table>", header = FALSE, na = "-"))
p("na notrim", T("<table><tr><td> - <td>-<td>x</table>", header = FALSE, na = "-", trim = FALSE))
p("na vec/dup/long", T("<table><tr><td>a<td>bbb<td>x</table>", header = FALSE, na = c("a", "bbb", "a")))
p("na factor", T("<table><tr><td>a</table>", header = FALSE, na = factor("a")))
p("na NA", T("<table><tr><td>a</table>", header = FALSE, na = NA_character_))
p("na NULL", T("<table><tr><td>a</table>", header = FALSE, na = NULL))
p("na header", T("<table><tr><th>-<th>b<tr><td>-<td>2</table>", na = "-"))
p("trim NA", T("<table><tr><td>a</table>", trim = NA))
d <- html_parse("<table id=a><tr><td>x<table id=b><tr><td>inner</table></table><table id=c><tr><td>North (1</table><svg><table></table></svg>")
p("tables", html_tables(d)); p("tables match", html_tables(d, match = "North")); p("tables match regex bad", html_tables(d, match = "(")); p("match inner", length(html_tables(d, match = "inner")))
p("tables css inner", html_tables(d, css = "#b")); p("tables css nontable", html_tables(d, css = "td"));p("tables on nodeset self", length(html_tables(html_elements(d, "table"))))
p("tables match NA/vec", list(tr(html_tables(d, match = NA_character_)), tr(html_tables(d, match = c("a","b"))), tr(html_tables(d, match = ""))))
p("tables dots", html_tables(d, header = FALSE, css = "#c")); p("tables bad dots", html_tables(d, foo = 1))
p("table on doc", html_table(d)); p("table on 2", html_table(html_elements(d, "table"))); p("table on NA", html_table(html_element(d, "nope"))); p("table on td", html_table(html_element(d, "td")))
