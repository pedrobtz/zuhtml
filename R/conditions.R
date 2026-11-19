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
#'   Nothing is returned and all native memory is released. Three fixed
#'   limits use the same class: `"arena"`, the most attributes or
#'   string-pool bytes one document can hold (just under \eqn{2^{32}});
#'   `"string_length"`, R's limit on the bytes of one string; and
#'   `"memory"`, when a result being built grows past what a size can
#'   count. Results (text, Markdown, serialized HTML, table grids) are built
#'   in memory R allocates, so running out of memory there is not a
#'   `zuhtml_error`: it is R's own error, such as "cannot allocate vector of
#'   size ...", and R releases what was allocated. Only parsing has a
#'   native memory budget, `max_memory`.
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

# The condition for a status a native entry point returned, by its name in
# zuh_status_names. Parsing maps its own limit statuses with the limits in
# hand (zuh_parse_bytes()); these are the ones that need none.
zuh_status_error <- function(status, observed, call) {
  observed <- as.double(observed)
  if (is.na(status)) status <- "unknown"
  switch(
    status,
    limit_memory = zuh_limit_error(
      "memory", NA_real_, NA_real_,
      "Native memory ran out while building the result.",
      call = call
    ),
    limit_arena = zuh_limit_error(
      "arena", 2^32 - 2, observed,
      sprintf(paste0("The document needs %.0f attribute or string-pool ",
                     "entries; a document holds at most %.0f, whatever ",
                     "max_memory allows."), observed, 2^32 - 2),
      call = call
    ),
    limit_string = zuh_limit_error(
      "string_length", .Machine$integer.max, observed,
      sprintf(paste0("The result is %.0f bytes long; an R string holds at ",
                     "most %.0f."), observed, .Machine$integer.max),
      call = call
    ),
    zuh_abort("parse", sprintf("Internal error (%s); please report it.",
                               status), call = call)
  )
}

zuh_limit_error <- function(limit, maximum, observed, message,
                            call = sys.call(-1L)) {
  zuh_abort(
    "limit", message,
    limit = limit, maximum = as.double(maximum),
    observed = as.double(observed), call = call
  )
}
