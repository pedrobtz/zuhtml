# Cleaned text of a whole document, and the table of a document's first
# <table>, from HTML.
clean <- function(html, ...) html_text_clean(html_parse(html), ...)
tab <- function(html, ...) {
  html_table(html_element(html_parse(html), "table"), ...)
}
