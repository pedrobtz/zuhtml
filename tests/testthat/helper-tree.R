# The tree of a document in the html5lib test format, one string per line.
# Internal: rendered by the C tree dump, which the conformance gate uses.
tree_lines <- function(doc) {
  out <- .Call(zuhtml:::C_zuh_doc_dump, doc$ptr)
  strsplit(sub("\n$", "", out), "\n", fixed = TRUE)[[1L]]
}

doc_meta <- function(doc) .Call(zuhtml:::C_zuh_doc_meta, doc$ptr)

# The body element of a parsed document.
body_of <- function(doc) html_children(html_root(doc))[2]
