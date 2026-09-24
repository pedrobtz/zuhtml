#' Attributes of elements
#'
#' `html_attr()` reads one attribute from every node; `html_attrs()` reads
#' all of them; `html_classes()` splits the `class` attribute into tokens.
#' Values are decoded (`&amp;` becomes `&`). An attribute that is present
#' but empty is `""`, distinct from an absent one: test a boolean attribute
#' such as `disabled` by presence, `!is.na(html_attr(x, "disabled"))`.
#'
#' Attribute names on HTML elements match regardless of ASCII case, as in a
#' browser; on SVG and MathML elements they match exactly (`viewBox`).
#' Namespaced attributes in foreign content are named with their prefix, as
#' in `"xlink:href"`. Where an element has the same attribute more than
#' once, the first wins, as the HTML parser decides.
#'
#' @param x A `zuhtml_document` or `zuhtml_nodeset`.
#' @param name The attribute name: a single string.
#' @param default The value for nodes that lack the attribute, including
#'   nodes that are not elements: a single string, possibly `NA`.
#'
#' @return
#' * `html_attr()`: a character vector as long as `x`; `NA` for missing
#'   nodes.
#' * `html_attrs()`: a list as long as `x` of named character vectors, in
#'   source order; `NA_character_` for missing nodes.
#' * `html_classes()`: a list as long as `x` of character vectors of class
#'   tokens; `NA_character_` for missing nodes.
#' @family node values
#' @export
#' @examples
#' doc <- html_parse(
#'   "<a href='/x' class='btn  primary' data-id=7>Go</a><input disabled>"
#' )
#' body <- html_children(html_root(doc))[2]
#' nodes <- html_children(body)
#' html_attr(nodes, "href")
#' html_attr(nodes, "href", default = "")
#' html_attrs(nodes)
#' html_classes(nodes)
#' !is.na(html_attr(nodes, "disabled"))
html_attr <- function(x, name, default = NA_character_) {
  call <- sys.call()
  if (!is.character(name) || length(name) != 1L || is.na(name) ||
      !nzchar(name)) {
    zuh_input_error("name", "`name` must be a single attribute name.",
                    call = call)
  }
  if (length(default) != 1L ||
      !(is.character(default) || identical(default, NA))) {
    zuh_input_error("default", "`default` must be a single string or NA.",
                    call = call)
  }
  n <- zuh_nodes(x, call = call)
  zuh_checked(
    .Call(C_zuh_node_attr, n$doc$ptr, n$ids, enc2utf8(name),
          enc2utf8(as.character(default))),
    n, call = call
  )
}

#' @rdname html_attr
#' @export
html_attrs <- function(x) {
  call <- sys.call()
  n <- zuh_nodes(x, call = call)
  zuh_checked(.Call(C_zuh_node_attrs, n$doc$ptr, n$ids), n, call = call)
}

#' @rdname html_attr
#' @export
html_classes <- function(x) {
  # With a "" default, NA marks exactly the missing nodes.
  cls <- html_attr(x, "class", default = "")
  out <- lapply(strsplit(cls, "[ \t\n\f\r]+"), function(v) v[nzchar(v)])
  out[is.na(cls)] <- list(NA_character_)
  out
}
