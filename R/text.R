#' Text content of nodes
#'
#' `html_text()` is the structural text of each node: the text nodes in its
#' subtree, concatenated in tree order, exactly as parsed. It inserts no
#' separators, trims nothing and keeps `<script>` and `<style>` text; it
#' does not include comments or the contents of `<template>` elements.
#'
#' @param x A `zuhtml_document` or `zuhtml_nodeset`.
#' @param recursive If `FALSE`, only the direct text children of each node.
#'
#' @return A character vector as long as `x`. An element with no text is
#'   `""`; a text, comment or processing-instruction node is its own
#'   content; a doctype and a missing node are `NA`.
#' @family node values
#' @export
#' @examples
#' doc <- html_parse("<p>Hello <b>big</b> world</p>")
#' p <- html_children(html_children(html_root(doc))[2])
#' html_text(p)
#' html_text(p, recursive = FALSE)
html_text <- function(x, recursive = TRUE) {
  call <- sys.call()
  zuh_check_flag(recursive, "recursive", call)
  n <- zuh_nodes(x, call = call)
  zuh_checked(.Call(C_zuh_node_text, n$doc$ptr, n$ids, recursive), n,
              call = call)
}
