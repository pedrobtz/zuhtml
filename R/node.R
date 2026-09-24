# Nodesets: an integer vector of node IDs plus the document that owns them.
# IDs are 0-based indices into the frozen document, assigned in document
# order, so sorting IDs sorts by document order. NA_integer_ is a missing
# node: aligned operations produce one where a node has no answer.

new_nodeset <- function(ids, doc) {
  structure(as.integer(ids), class = "zuhtml_nodeset", doc = doc)
}

zuh_owner <- function(x) attr(x, "doc", exact = TRUE)

# Resolve a document or nodeset argument to its owning document and IDs.
# A document stands for its document node, ID 0.
zuh_nodes <- function(x, arg = "x", call = sys.call(-1L)) {
  if (inherits(x, "zuhtml_document")) {
    return(list(doc = x, ids = 0L))
  }
  if (inherits(x, "zuhtml_nodeset")) {
    return(list(doc = zuh_owner(x), ids = as.vector(unclass(x), "integer")))
  }
  zuh_input_error(
    arg, sprintf("`%s` must be a zuhtml_document or zuhtml_nodeset.", arg),
    call = call
  )
}

# Check the result of a native node accessor: NULL means a dead document
# or a node ID that does not belong to it. Each caller names its routine in
# its own .Call(), which R CMD check needs to see.
zuh_checked <- function(res, nodes, call = sys.call(-1L)) {
  if (is.null(res)) {
    if (!.Call(C_zuh_doc_alive, nodes$doc$ptr)) {
      zuh_abort(
        "pointer",
        paste0("This document is no longer available, for example because ",
               "it was restored from a saved session. Parse the HTML again."),
        call = call
      )
    }
    zuh_abort("pointer", "A node ID does not belong to its document.",
              call = call)
  }
  res
}

zuh_set <- function(ids) sort(unique(ids[!is.na(ids)]))

zuh_check_flag <- function(x, arg, call) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    zuh_input_error(arg, sprintf("`%s` must be TRUE or FALSE.", arg),
                    call = call)
  }
}

#' Navigate a document tree
#'
#' Move from nodes to related nodes. Operations that return exactly one
#' node per input node -- `html_parent()`, `html_next_sibling()` and
#' `html_previous_sibling()` -- are *aligned*: the result has the same
#' length as `x`, with a missing node where there is no answer, so that
#' results line up with their inputs. Operations that can return many nodes
#' per input -- `html_children()`, `html_ancestors()` and
#' `html_template_content()` -- return the set of all results, without
#' duplicates, in document order.
#'
#' A `<template>` element's contents are its children here, but they are
#' inert: searches and text extraction do not descend into them.
#' `html_template_content()` returns them explicitly.
#'
#' @param x A `zuhtml_document` or `zuhtml_nodeset`. A document stands for
#'   its document node.
#' @param elements_only If `TRUE`, consider element nodes only, skipping
#'   text, comments and other nodes.
#'
#' @return
#' * `html_children()`, `html_ancestors()`, `html_template_content()`: a
#'   `zuhtml_nodeset` in document order. `html_ancestors()` does not include
#'   the document node.
#' * `html_parent()`, `html_next_sibling()`, `html_previous_sibling()`: a
#'   `zuhtml_nodeset` as long as `x`, with missing nodes where there is no
#'   parent or sibling.
#' * `html_root()`: a `zuhtml_nodeset` of length one: the `<html>` element
#'   of a document, or the fragment node of a fragment.
#' * `html_document()`: the `zuhtml_document` that owns `x`.
#' @family navigation
#' @export
#' @examples
#' doc <- html_parse("<ul><li>One</li><li>Two <b>bold</b></li></ul>")
#' body <- html_children(html_root(doc))[2]
#' items <- html_children(html_children(body))
#' items
#' html_parent(items)
#' html_next_sibling(items)
#' html_ancestors(html_children(items[2]))
#'
#' # Template contents are reached explicitly:
#' tmpl <- html_parse("<template><p>inert</p></template>")
#' html_template_content(html_children(html_children(html_root(tmpl))[1]))
html_children <- function(x, elements_only = TRUE) {
  call <- sys.call()
  zuh_check_flag(elements_only, "elements_only", call)
  n <- zuh_nodes(x, call = call)
  ids <- zuh_checked(
    .Call(C_zuh_node_children, n$doc$ptr, n$ids, elements_only, FALSE),
    n, call = call
  )
  new_nodeset(zuh_set(ids), n$doc)
}

#' @rdname html_children
#' @export
html_parent <- function(x) {
  call <- sys.call()
  n <- zuh_nodes(x, call = call)
  ids <- zuh_checked(.Call(C_zuh_node_parent, n$doc$ptr, n$ids), n,
                     call = call)
  new_nodeset(ids, n$doc)
}

#' @rdname html_children
#' @export
html_ancestors <- function(x) {
  call <- sys.call()
  n <- zuh_nodes(x, call = call)
  ids <- zuh_checked(.Call(C_zuh_node_ancestors, n$doc$ptr, n$ids), n,
                     call = call)
  new_nodeset(zuh_set(ids), n$doc)
}

#' @rdname html_children
#' @export
html_next_sibling <- function(x, elements_only = TRUE) {
  call <- sys.call()
  zuh_check_flag(elements_only, "elements_only", call)
  n <- zuh_nodes(x, call = call)
  ids <- zuh_checked(
    .Call(C_zuh_node_sibling, n$doc$ptr, n$ids, TRUE, elements_only),
    n, call = call
  )
  new_nodeset(ids, n$doc)
}

#' @rdname html_children
#' @export
html_previous_sibling <- function(x, elements_only = TRUE) {
  call <- sys.call()
  zuh_check_flag(elements_only, "elements_only", call)
  n <- zuh_nodes(x, call = call)
  ids <- zuh_checked(
    .Call(C_zuh_node_sibling, n$doc$ptr, n$ids, FALSE, elements_only),
    n, call = call
  )
  new_nodeset(ids, n$doc)
}

#' @rdname html_children
#' @export
html_template_content <- function(x) {
  call <- sys.call()
  n <- zuh_nodes(x, call = call)
  ids <- zuh_checked(
    .Call(C_zuh_node_children, n$doc$ptr, n$ids, FALSE, TRUE),
    n, call = call
  )
  new_nodeset(zuh_set(ids), n$doc)
}

#' @rdname html_children
#' @export
html_root <- function(x) {
  call <- sys.call()
  n <- zuh_nodes(x, call = call)
  m <- .Call(C_zuh_doc_meta, zuh_doc_ptr(n$doc, call = call))
  new_nodeset(if (m$is_fragment) 0L else m$root, n$doc)
}

#' @rdname html_children
#' @export
html_document <- function(x) {
  zuh_nodes(x, call = sys.call())$doc
}

#' Node names, namespaces and types
#'
#' Vectorized accessors returning one value per node, with `NA` for missing
#' nodes.
#'
#' @param x A `zuhtml_document` or `zuhtml_nodeset`.
#'
#' @return A character vector as long as `x`.
#' * `html_name()`: the element name, lowercase for HTML elements and in
#'   the spec's mixed case for SVG ones such as `"foreignObject"`; the
#'   doctype's name for a doctype node; `NA` for other nodes.
#' * `html_namespace()`: the namespace URI of an element, for example
#'   `"http://www.w3.org/1999/xhtml"` or `"http://www.w3.org/2000/svg"`;
#'   `NA` for other nodes.
#' * `html_type()`: one of `"document"`, `"fragment"`, `"doctype"`,
#'   `"element"`, `"text"`, `"comment"` and `"processing_instruction"`. A
#'   `<template>` is an `"element"`.
#' @family node values
#' @export
#' @examples
#' doc <- html_parse("<p>Text<svg><foreignObject/></svg><!-- note -->")
#' nodes <- html_children(html_children(html_root(doc))[2], FALSE)
#' nodes <- html_children(nodes, FALSE)
#' html_type(nodes)
#' html_name(nodes)
#' html_namespace(nodes)
html_name <- function(x) {
  call <- sys.call()
  n <- zuh_nodes(x, call = call)
  zuh_checked(.Call(C_zuh_node_name, n$doc$ptr, n$ids), n, call = call)
}

#' @rdname html_name
#' @export
html_namespace <- function(x) {
  call <- sys.call()
  n <- zuh_nodes(x, call = call)
  zuh_checked(.Call(C_zuh_node_namespace, n$doc$ptr, n$ids), n,
              call = call)
}

#' @rdname html_name
#' @export
html_type <- function(x) {
  call <- sys.call()
  n <- zuh_nodes(x, call = call)
  zuh_checked(.Call(C_zuh_node_type, n$doc$ptr, n$ids), n, call = call)
}
