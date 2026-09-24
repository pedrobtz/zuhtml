# Cleaned text of a whole document, and the table of a document's first
# <table>, from HTML.
clean <- function(html, ...) html_text_clean(html_parse(html), ...)
tab <- function(html, ...) {
  html_table(html_element(html_parse(html), "table"), ...)
}

# The cells of a document's first <table>, parsed with a base URL.
cells <- function(html, ...) {
  doc <- html_parse(html, base_url = "https://x.test/d/")
  html_table_cells(html_element(doc, "table"), ...)
}
