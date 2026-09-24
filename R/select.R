#' Select elements with CSS selectors
#'
#' `html_elements()` finds every element matching a selector below the
#' given nodes; `html_element()` finds the first below each node, keeping
#' one result per input so that extracted columns stay aligned.
#' `html_matches()` tests nodes themselves, and `html_filter()` keeps the
#' ones that match.
#'
#' Searching a document includes its `<html>` element. Searching below an
#' element excludes the element itself unless the selector uses `:scope`
#' for it, as in `":scope > li"` or `":scope.active"`. Matching elsewhere in
#' the selector is against the whole document, as in a browser: `"div p"`
#' below a `<section>` finds a `<p>` whose `<div>` ancestor is outside the
#' section. Template contents are never searched.
#'
#' @section Supported selectors:
#' A deliberately small subset of CSS Selectors Level 4, and nothing else:
#' * type (`p`) and universal (`*`) selectors;
#' * `#id` and `.class`;
#' * attributes: `[a]`, `[a=v]`, `[a~=v]`, `[a|=v]`, `[a^=v]`, `[a$=v]` and
#'   `[a*=v]`, with an optional `i` or `s` flag, as in `[type=text i]`;
#' * combinators: descendant (space), child (`>`), next sibling (`+`) and
#'   later sibling (`~`), and selector lists (`,`);
#' * `:scope`, `:root`, `:empty`, `:first-child`, `:last-child`,
#'   `:only-child`, `:nth-child(an+b)`, `:nth-of-type(an+b)`, and `:not()`
#'   with one compound selector.
#'
#' Anything else -- `:has()`, other pseudo-classes, pseudo-elements,
#' namespace prefixes, the `of S` form of `:nth-child()` -- is an error of
#' class `zuhtml_selector_error`, never a silent partial match.
#'
#' Case follows HTML documents in a browser: element and attribute names
#' match HTML elements regardless of ASCII case and SVG or MathML elements
#' exactly; IDs and classes are case-sensitive; attribute values are
#' case-sensitive except for the attributes HTML lists as case-insensitive
#' (such as `type` and `lang`), and an `i` or `s` flag overrides both.
#' Structural pseudo-classes count element siblings only. `:empty` is true
#' for an element with no element or text children; comments do not count,
#' whitespace does.
#'
#' @param x A `zuhtml_document` or `zuhtml_nodeset`.
#' @param css A CSS selector: a single string.
#'
#' @return
#' * `html_elements()`: a `zuhtml_nodeset` of the matching elements below
#'   any node of `x`, without duplicates, in document order.
#' * `html_element()`: a `zuhtml_nodeset` as long as `x`: for each node,
#'   the first matching element below it in document order, or a missing
#'   node.
#' * `html_matches()`: a logical vector as long as `x`; `NA` for missing
#'   nodes, `FALSE` for nodes that are not elements.
#' * `html_filter()`: the nodes of `x` that match, in their order.
#' @family selection
#' @export
#' @examples
#' doc <- html_parse(paste0(
#'   "<div class=card><h2>Tea</h2><span class=price>3.50</span></div>",
#'   "<div class=card><h2>Cake</h2></div>"
#' ))
#' cards <- html_elements(doc, ".card")
#' html_text(html_element(cards, "h2"))
#' html_text(html_element(cards, ".price"))
#' html_elements(doc, "div > h2:first-child")
#' html_matches(html_elements(doc, "div, h2"), ".card")
#' html_filter(html_elements(doc, "div, h2"), "h2")
#'
#' try(html_elements(doc, "div:has(h2)"))
html_elements <- function(x, css) {
  call <- sys.call()
  n <- zuh_nodes(x, call = call)
  res <- zuh_select(n, css, 0L, call)
  new_nodeset(res, n$doc)
}

#' @rdname html_elements
#' @export
html_element <- function(x, css) {
  call <- sys.call()
  n <- zuh_nodes(x, call = call)
  new_nodeset(zuh_select(n, css, 1L, call), n$doc)
}

#' @rdname html_elements
#' @export
html_matches <- function(x, css) {
  call <- sys.call()
  zuh_select(zuh_nodes(x, call = call), css, 2L, call)
}

#' @rdname html_elements
#' @export
html_filter <- function(x, css) {
  call <- sys.call()
  if (!inherits(x, "zuhtml_nodeset")) {
    zuh_input_error("x", "`x` must be a zuhtml_nodeset.", call = call)
  }
  x[html_matches(x, css) %in% TRUE]
}

# A bound on matching work per call, in compound-selector tests. Matching is
# near-linear in practice; this stops a pathological selector and document
# pair long before it would stall a session.
zuh_selector_work_limit <- 1e9

zuh_select <- function(nodes, css, mode, call) {
  if (!is.character(css) || length(css) != 1L || is.na(css)) {
    zuh_input_error("css", "`css` must be a single selector string.",
                    call = call)
  }
  css <- enc2utf8(css)
  max_len <- html_limits()$max_selector_length
  if (nchar(css, type = "bytes") > max_len) {
    zuh_limit_error(
      "max_selector_length", max_len, nchar(css, type = "bytes"),
      sprintf("The selector is longer than max_selector_length = %.0f bytes.",
              max_len),
      call = call
    )
  }
  res <- zuh_checked(
    .Call(C_zuh_select, nodes$doc$ptr, nodes$ids, css, mode,
          zuh_selector_work_limit),
    nodes, call = call
  )
  if (is.list(res)) zuh_selector_failure(res, css, call)
  res
}

zuh_selector_failure <- function(res, css, call) {
  if (identical(res$error, "work")) {
    zuh_limit_error(
      "selector_work", zuh_selector_work_limit, NA_real_,
      "Matching this selector took too much work; simplify it.",
      call = call
    )
  }
  if (identical(res$error, "no_memory")) {
    zuh_abort("selector", "Out of memory compiling the selector.",
              selector = css, position = NA_integer_, call = call)
  }
  bytes <- charToRaw(css)
  pos <- nchar(rawToChar(bytes[seq_len(res$position)]), type = "chars") + 1L
  zuh_abort(
    "selector",
    sprintf("Invalid selector at position %d: %s.\n  %s\n  %s^",
            pos, res$reason, css, strrep(" ", pos - 1L)),
    selector = css, position = pos, reason = res$reason,
    unsupported = identical(res$error, "unsupported"),
    call = call
  )
}
