source("h.R")
T <- function(h, ...) html_table(html_element(html_parse(h), "table"), ...)
C <- function(vals, ...) { h <- paste0("<table><tr><th>h", paste0("<tr><td>", vals, collapse = ""), "</table>"); r <- T(h, convert = TRUE, ...)[[1]]; cat(sprintf("%-30s -> %s %s  [%s]\n", paste(vals, collapse="|"), class(r), paste(format(r, digits = 17), collapse = " | "), paste(utf8ToInt(as.character(r[1])), collapse=","))) }
C("1&nbsp;000", thousands = " "); C("1&nbsp;000", thousands = " "); C("1&#8239;000", thousands = " "); C("1&#8239;000", thousands = " "); C("1 000", thousands = " "); C("1&#8201;000", thousands = " ")
C("1&nbsp;000,5", thousands = " ", decimal = ",")
p("clean nbsp", utf8ToInt(html_text_clean(html_parse("<p>1&nbsp;0&#8239;0&#8201;0"))))
p("table nbsp", utf8ToInt(T("<table><tr><td>1&nbsp;0&#8239;0</table>", header = FALSE)[[1]]))
p("table nbsp na", T("<table><tr><td>&nbsp;<td>a&nbsp;b</table>", header = FALSE, na = c("", "a b")))
p("table nbsp na2", T("<table><tr><td>&nbsp;<td>a&nbsp;b</table>", header = FALSE, na = c("", "a b")))
