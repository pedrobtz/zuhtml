#' Resource limits for parsing and extraction
#'
#' Every parse and extraction runs under explicit limits, so that untrusted
#' HTML cannot exhaust memory or time. Limits are per call, not global
#' options: pass the result to the `limits` argument of [html_parse()] and
#' the extraction functions. Exceeding one raises a `zuhtml_limit_error`
#' (see [zuhtml-conditions]) after all native memory is released.
#'
#' The memory limit is the real guard; the input limit is a cheap check
#' before parsing starts. The parser needs about 17 bytes of native memory
#' per input byte on ordinary markup and up to about 47 on markup dense with
#' formatting elements, so a large enough page can reach `max_memory` before
#' `max_input`.
#'
#' @param max_input Largest input, in bytes of UTF-8 after decoding.
#' @param max_memory Largest native memory the parser may hold at once, in
#'   bytes.
#' @param max_depth Deepest nesting of open elements. Parsing time grows
#'   with the square of nesting depth, so this bounds it; it is enforced
#'   while parsing, not afterwards.
#' @param max_nodes Most nodes a document may have.
#' @param max_errors Most parse problems kept for [html_problems()]. Parsing
#'   continues past it; only the record is truncated.
#' @param max_table_cells Most cells a table may expand to, spans included.
#' @param max_selector_length Longest CSS selector, in bytes.
#'
#' @return An object of class `zuhtml_limits`: a named list of the limits,
#'   as doubles.
#' @export
#' @examples
#' html_limits()
#'
#' # A tighter nesting limit for a service parsing untrusted pages:
#' lim <- html_limits(max_depth = 128)
#' try(html_parse(strrep("<div>", 200), limits = lim))
html_limits <- function(max_input = 16 * 1024^2,
                        max_memory = 512 * 1024^2,
                        max_depth = 512,
                        max_nodes = 1e6,
                        max_errors = 100,
                        max_table_cells = 1e6,
                        max_selector_length = 16 * 1024) {
  zuh_check_limits(list(
    max_input = max_input,
    max_memory = max_memory,
    max_depth = max_depth,
    max_nodes = max_nodes,
    max_errors = max_errors,
    max_table_cells = max_table_cells,
    max_selector_length = max_selector_length
  ))
}

# Lower and upper bounds of each limit. Upper bounds keep every value exact
# in a double and representable where it is used: input offsets and node IDs
# are R integers, and the largest integer is reserved for NA.
zuh_limit_bounds <- list(
  max_input = c(1, .Machine$integer.max),
  max_memory = c(1, 2^53),
  max_depth = c(1, .Machine$integer.max),
  max_nodes = c(1, .Machine$integer.max - 1),
  max_errors = c(0, .Machine$integer.max - 1),
  max_table_cells = c(1, .Machine$integer.max),
  max_selector_length = c(1, .Machine$integer.max)
)

zuh_check_limits <- function(x, call = sys.call(-1L)) {
  if (!is.list(x) || !identical(names(x), names(zuh_limit_bounds))) {
    zuh_input_error(
      "limits", "`limits` must be created by html_limits().",
      call = call
    )
  }
  for (nm in names(zuh_limit_bounds)) {
    v <- x[[nm]]
    b <- zuh_limit_bounds[[nm]]
    ok <- is.numeric(v) && length(v) == 1L && !is.na(v) && is.finite(v) &&
      v == trunc(v) && v >= b[1L] && v <= b[2L]
    if (!ok) {
      zuh_input_error(
        nm,
        sprintf(
          "`%s` must be a single whole number between %.0f and %.0f.",
          nm, b[1L], b[2L]
        ),
        call = call
      )
    }
    x[[nm]] <- as.double(v)
  }
  structure(x, class = "zuhtml_limits")
}

#' @export
print.zuhtml_limits <- function(x, ...) {
  cat("<zuhtml_limits>\n")
  w <- max(nchar(names(x)))
  for (nm in names(x)) {
    cat(sprintf("  %-*s %s\n", w, nm, format(x[[nm]], big.mark = ",",
                                              scientific = FALSE)))
  }
  invisible(x)
}
