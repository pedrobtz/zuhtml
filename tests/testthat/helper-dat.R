# Read an html5lib tree-construction .dat file into a list of cases, each
# with `data` (the input), `fragment` (the context, or "") and `document`
# (the expected tree, one string per line). As upstream Gumbo's harness
# reads them: the final newline of #data is not part of the input.
read_dat <- function(path) {
  lines <- readLines(path, encoding = "UTF-8", warn = FALSE)
  cases <- list()
  cur <- NULL
  section <- ""
  flush <- function() {
    if (is.null(cur)) return()
    doc <- cur$document
    while (length(doc) && !nzchar(doc[length(doc)])) doc <- doc[-length(doc)]
    cur$document <- doc
    cur$data <- paste(cur$data, collapse = "\n")
    cases[[length(cases) + 1L]] <<- cur
  }
  for (l in lines) {
    if (l == "#data") {
      flush()
      cur <- list(data = character(), fragment = "", document = character())
      section <- "data"
    } else if (l == "#document") {
      section <- "document"
    } else if (l == "#document-fragment") {
      section <- "fragment"
    } else if (startsWith(l, "#")) {
      section <- "other"
    } else if (section == "data") {
      cur$data <- c(cur$data, l)
    } else if (section == "document") {
      cur$document <- c(cur$document, l)
    } else if (section == "fragment") {
      cur$fragment <- l
      section <- "other"
    }
  }
  flush()
  cases
}

parse_dat_case <- function(case, html = case$data) {
  if (nzchar(case$fragment)) {
    html_fragment(html, context = case$fragment)
  } else {
    html_parse(html)
  }
}
