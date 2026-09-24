#' Serialize nodes as HTML
#'
#' Produces normalized HTML following the WHATWG serialization algorithm,
#' not the original input bytes: end tags the input left out are written,
#' attribute values are always double-quoted, and `&`, `<`, `>`, `"` and
#' non-breaking spaces are escaped as the algorithm requires. Parsing the
#' result gives back the same tree, except where the HTML standard itself
#' does not guarantee that (for example markup that tree construction
#' rearranges).
#'
#' Serialization is not sanitization: `<script>` elements and
#' `javascript:` URLs are written as they were parsed.
#'
#' `as.character()` on a nodeset is `html_serialize()`.
#'
#' @param x A `zuhtml_document` or `zuhtml_nodeset`.
#' @param outer If `TRUE`, each node with its own markup, like
#'   `outerHTML`; if `FALSE`, only its contents, like `innerHTML`. A
#'   document or fragment has no markup of its own, so both give its
#'   contents.
#'
#' @return A character vector as long as `x`; `NA` for missing nodes.
#' @family node values
#' @export
#' @examples
#' doc <- html_parse("<p class=x>One<br>Two & <b>three</p>")
#' html_serialize(doc)
#' p <- html_children(html_children(html_root(doc))[2])
#' html_serialize(p)
#' html_serialize(p, outer = FALSE)
#'
#' # To write a document to a file:
#' path <- tempfile(fileext = ".html")
#' writeLines(html_serialize(doc), path)
html_serialize <- function(x, outer = TRUE) {
  call <- sys.call()
  zuh_check_flag(outer, "outer", call)
  n <- zuh_nodes(x, call = call)
  zuh_checked(.Call(C_zuh_node_serialize, n$doc$ptr, n$ids, outer), n,
              call = call)
}

#' @export
as.character.zuhtml_nodeset <- function(x, ...) html_serialize(x)
