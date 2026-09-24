# Read every corpus file and print one TSV row per file describing what zuhtml
# made of it. tools/corpus/run compares the rows with expected.tsv.
#
#   Rscript tools/corpus/sweep.R <files-dir>
#
# HTML never fails to parse, so "ok" says little. Each row records enough to
# notice any change in what the parser builds or the extractors return:
#
#   outcome     ok, ok:<encoding> when UTF-8 failed and windows-1252 was
#               used instead (as a user would retry), or the error class
#   nodes       nodes in the document
#   problems    parse errors repaired (at most max_errors = 100)
#   tables      <table> elements, and cells the outermost read to (or
#               "overlap" / "limit" when html_table() refuses one)
#   lists       <ul>/<ol> elements, and <li> items
#   links       a[href] and area[href] elements
#   text        characters of html_text_clean() of the whole document, and
#               the first 12 hex digits of its MD5
#   roundtrip   whether serializing and parsing again gives the same tree:
#               TRUE, "doctype" when only the doctype's public and system
#               identifiers were lost (the standard's serializer drops
#               them), or FALSE

suppressMessages(library(zuhtml))
dir <- commandArgs(TRUE)[[1L]]
files <- sort(list.files(dir, recursive = TRUE, pattern = "\\.html$"))

md5_text <- function(x) {
  f <- tempfile()
  on.exit(unlink(f))
  writeBin(charToRaw(enc2utf8(x)), f)
  substr(unname(tools::md5sum(f)), 1L, 12L)
}

dump_of <- function(doc) .Call(zuhtml:::C_zuh_doc_dump, doc$ptr)

roundtrip <- function(doc, again) {
  if (is.null(again)) return("FALSE")
  a <- dump_of(doc)
  b <- dump_of(again)
  if (identical(a, b)) return("TRUE")
  drop_doctype <- function(x) sub("^\\| <!DOCTYPE [^\n]*\n", "", x)
  if (identical(drop_doctype(a), drop_doctype(b))) "doctype" else "FALSE"
}

row <- function(path) {
  outcome <- "ok"
  doc <- tryCatch(html_read(path), zuhtml_encoding_error = function(e) NULL)
  if (is.null(doc)) {
    outcome <- "ok:windows-1252"
    doc <- tryCatch(html_read(path, encoding = "windows-1252"),
                    zuhtml_error = function(e) e)
  }
  if (inherits(doc, "zuhtml_error")) {
    return(c(outcome = class(doc)[[1L]], rep("", 8L)))
  }
  info <- html_info(doc)
  tabs <- html_elements(doc, "table")
  cells <- tryCatch(
    sum(vapply(html_tables(doc), function(t) as.double(prod(dim(t))), 0)),
    zuhtml_table_structure_error = function(e) "overlap",
    zuhtml_limit_error = function(e) "limit"
  )
  text <- html_text_clean(doc)
  again <- tryCatch(html_parse(html_serialize(doc)),
                    zuhtml_error = function(e) NULL)
  c(
    outcome = outcome,
    nodes = format(info$nodes, scientific = FALSE),
    problems = format(info$problems),
    tables = paste0(length(tabs), "/", format(cells, scientific = FALSE)),
    lists = paste0(length(html_elements(doc, "ul, ol")), "/",
                   length(html_elements(doc, "li"))),
    links = length(html_elements(doc, "a[href], area[href]")),
    text = paste0(nchar(text), "/", md5_text(text)),
    roundtrip = roundtrip(doc, again),
    ""
  )
}

cols <- c("file", "outcome", "nodes", "problems", "tables", "lists", "links",
          "text", "roundtrip")
cat(paste(cols, collapse = "\t"), "\n", sep = "")
for (f in files) {
  r <- row(file.path(dir, f))
  cat(paste(c(f, r[seq_len(length(cols) - 1L)]), collapse = "\t"), "\n",
      sep = "")
}
