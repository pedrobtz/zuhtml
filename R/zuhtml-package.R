#' zuhtml: parse HTML with a bundled Gumbo parser
#'
#' zuhtml parses real-world HTML the way a browser does, with a bundled copy
#' of the 'Gumbo' parser, and extracts ordinary R objects from it: nodes
#' selected by a documented subset of CSS, attributes, text, lists, tables
#' and links. It needs no system library and has no hard dependencies.
#'
#' It does not fetch, run JavaScript, sanitize, edit documents or support
#' XPath: a fetcher hands it a string.
#'
#' @section Getting started:
#' * Parse with [html_parse()], [html_read()] or [html_fragment()].
#' * Select elements with [html_elements()] and [html_element()], or move
#'   around with [html_children()] and friends.
#' * Read values with [html_text_clean()], [html_attr()] and
#'   [html_serialize()]; extract structures with [html_table()],
#'   [html_list()], [html_links()] and [html_url()].
#' * Every call runs under [html_limits()], and every error is a classed
#'   condition: see [zuhtml-conditions].
#'
#' `vignette("zuhtml")` walks through a complete extraction.
#'
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @useDynLib zuhtml, .registration = TRUE
## usethis namespace: end
NULL
