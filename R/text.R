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

#' Cleaned text for extraction
#'
#' Text as a reader would want it from a page, rather than exactly as
#' parsed. It is not a browser's `innerText`: there is no layout or CSS, and
#' hidden elements are included. The rules are fixed and documented:
#' * text inside `<script>`, `<style>` and `<template>` is skipped, and so
#'   are comments;
#' * runs of whitespace (space, tab, newline, carriage return, form feed)
#'   collapse to a single space, except inside `<pre>`, `<textarea>`,
#'   `<listing>` and `<plaintext>`, where whitespace is kept;
#' * `<br>` is a line break; each block element is a line break before and
#'   after, and adjacent block boundaries give a single line break. The
#'   block elements are `address`, `article`, `aside`, `blockquote`, `body`,
#'   `caption`, `center`, `dd`, `details`, `dialog`, `dir`, `div`, `dl`,
#'   `dt`, `fieldset`, `figcaption`, `figure`, `footer`, `form`, `h1` to
#'   `h6`, `head`, `header`, `hgroup`, `hr`, `html`, `legend`, `li`,
#'   `listing`, `main`, `menu`, `nav`, `ol`, `optgroup`, `option`, `p`,
#'   `plaintext`, `pre`, `section`, `summary`, `table`, `tbody`, `tfoot`,
#'   `thead`, `title`, `tr`, `ul` and `xmp`;
#' * table cells (`<td>`, `<th>`) are separated by a space.
#'
#' @param x A `zuhtml_document` or `zuhtml_nodeset`.
#' @param trim If `TRUE`, no whitespace at the start or end. If `FALSE`,
#'   whitespace there is kept, collapsed to a single space.
#' @param nbsp If `TRUE`, treat non-breaking spaces (U+00A0) as whitespace,
#'   so they collapse like spaces; inside `<pre>` they become spaces.
#'
#' @return A character vector as long as `x`: the cleaned text of each
#'   element, document, fragment or text node; `NA` for other nodes and for
#'   missing nodes.
#' @family node values
#' @seealso [html_text()] for the text exactly as parsed.
#' @export
#' @examples
#' doc <- html_parse(paste0(
#'   "<div><h1>Title</h1>\n  <p>Some   <b>bold</b> text.<br>New line",
#'   "<script>ignored()</script></p><pre>  kept\n  as is</pre></div>"
#' ))
#' div <- html_element(doc, "div")
#' cat(html_text_clean(div))
#' html_text(div)
html_text_clean <- function(x, trim = TRUE, nbsp = TRUE) {
  call <- sys.call()
  zuh_check_flag(trim, "trim", call)
  zuh_check_flag(nbsp, "nbsp", call)
  zuh_clean(zuh_nodes(x, call = call), trim, nbsp, call = call)
}

zuh_clean <- function(nodes, trim = TRUE, nbsp = TRUE, skip_lists = FALSE,
                      skip_tables = FALSE, call = sys.call(-1L)) {
  zuh_checked(
    .Call(C_zuh_text_clean, nodes$doc$ptr, nodes$ids,
          c(trim, nbsp, skip_lists, skip_tables)),
    nodes, call = call
  )
}

#' Text pieces of nodes
#'
#' The text nodes of each node's subtree, in tree order, as separate
#' strings: the pieces [html_text()] concatenates. Boundaries between
#' elements are kept, which matters when the markup, not whitespace,
#' separates values (`<td>1</td><td>2</td>` is `"1"`, `"2"`, not `"12"`).
#' Text inside `<script>`, `<style>` and `<template>` is skipped, as are
#' comments.
#'
#' @param x A `zuhtml_document` or `zuhtml_nodeset`.
#' @param trim If `TRUE`, remove leading and trailing whitespace from each
#'   piece.
#' @param drop_empty If `TRUE`, drop pieces that are empty (after trimming,
#'   when `trim = TRUE`).
#'
#' @return A list as long as `x` of character vectors; `NA_character_` for
#'   a missing node. A text node is its own single piece.
#' @family node values
#' @export
#' @examples
#' doc <- html_parse("<p>One <b>two</b>\n  <i> three </i></p>")
#' p <- html_element(doc, "p")
#' html_strings(p)
#' html_strings(p, trim = TRUE, drop_empty = TRUE)
html_strings <- function(x, trim = FALSE, drop_empty = FALSE) {
  call <- sys.call()
  zuh_check_flag(trim, "trim", call)
  zuh_check_flag(drop_empty, "drop_empty", call)
  n <- zuh_nodes(x, call = call)
  out <- zuh_checked(.Call(C_zuh_node_strings, n$doc$ptr, n$ids), n,
                     call = call)
  missing <- vapply(out, function(v) length(v) == 1L && is.na(v), NA) &
    is.na(n$ids)
  out <- lapply(out, function(v) {
    if (trim) v <- trimws(v, whitespace = "[ \t\n\r\f]")
    if (drop_empty) v <- v[nzchar(v)]
    v
  })
  out[missing] <- list(NA_character_)
  out
}
