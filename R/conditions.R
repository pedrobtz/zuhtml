#' Conditions raised by zuhtml
#'
#' Every error zuhtml raises is a condition of class `zuhtml_error` with one
#' more specific subclass. Handle them by class, for example with
#' `tryCatch(..., zuhtml_limit_error = function(e) ...)`, never by matching
#' the message text, which may change.
#'
#' * `zuhtml_input_error`: an argument is invalid, for example `x` is not a
#'   single string or raw vector, a file does not exist, a URL or connection
#'   cannot be opened or read, or a limit is not a whole number in range. Field `arg` names the argument.
#' * `zuhtml_encoding_error`: raw input cannot be decoded: an unknown
#'   encoding, a byte sequence invalid in the declared encoding, or a
#'   byte-order mark that contradicts `encoding`. Field `encoding`.
#' * `zuhtml_limit_error`: a resource limit from [html_limits()] was
#'   exceeded. Fields `limit` (its name, such as `"max_depth"`), `maximum`
#'   (its value) and `observed` (the value that tripped it, where known).
#'   Nothing is returned and all native memory is released.
#' * `zuhtml_parse_error`: an internal invariant of the parser failed. This
#'   is a bug; please report it.
#' * `zuhtml_pointer_error`: a document is no longer available, for example
#'   because it was restored from a saved R session. Parse the HTML again.
#'
#' Recoverable HTML errors, such as a missing end tag, are not conditions:
#' they are repaired as a browser would repair them and recorded for
#' [html_problems()].
#'
#' @name zuhtml-conditions
NULL

zuh_condition <- function(kind, message, ..., call = NULL) {
  structure(
    class = c(paste0("zuhtml_", kind, "_error"), "zuhtml_error", "error",
              "condition"),
    list(message = message, call = call, ...)
  )
}

zuh_abort <- function(kind, message, ..., call = sys.call(-1L)) {
  stop(zuh_condition(kind, message, ..., call = call))
}

zuh_input_error <- function(arg, message, call = sys.call(-1L)) {
  zuh_abort("input", message, arg = arg, call = call)
}

zuh_limit_error <- function(limit, maximum, observed, message,
                            call = sys.call(-1L)) {
  zuh_abort(
    "limit", message,
    limit = limit, maximum = as.double(maximum),
    observed = as.double(observed), call = call
  )
}
