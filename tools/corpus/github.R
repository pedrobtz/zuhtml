# GitHub API helpers for tools/corpus/fetch --pin. Reads a JSON response on
# stdin; base R only, so the script needs nothing installed.
#
#   Rscript tools/corpus/github.R subtree <name>     sha of entry <name> in a
#                                                    (non-recursive) tree
#   Rscript tools/corpus/github.R paths <regex>      blob paths of a recursive
#                                                    tree listing matching
#                                                    <regex>, sorted
args <- commandArgs(TRUE)
json <- paste(readLines(file("stdin"), warn = FALSE), collapse = "")
field <- function(obj, key) {
  m <- regmatches(obj, regexec(sprintf('"%s": *"([^"]*)"', key), obj))[[1]]
  if (length(m) == 2L) m[[2L]] else NA_character_
}
objects <- regmatches(json, gregexpr("\\{[^{}]*\\}", json))[[1]]

if (args[[1L]] == "subtree") {
  names <- vapply(objects, field, "", key = "path")
  hit <- which(names == args[[2L]])
  if (length(hit) != 1L) stop("no entry named ", args[[2L]])
  cat(field(objects[[hit]], "sha"), "\n", sep = "")
} else if (args[[1L]] == "paths") {
  if (grepl('"truncated": *true', json)) stop("the tree listing is truncated")
  blobs <- objects[vapply(objects, field, "", key = "type") %in% "blob"]
  paths <- vapply(blobs, field, "", key = "path", USE.NAMES = FALSE)
  writeLines(sort(paths[grepl(args[[2L]], paths, perl = TRUE)]))
} else {
  stop("unknown command ", args[[1L]])
}
