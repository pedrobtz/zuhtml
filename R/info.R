#' Report the zuhtml build configuration
#'
#' Reports the bundled 'Gumbo' version and the local patches applied to it,
#' and runs two self-tests against the compiled parser. Intended for
#' diagnostics and bug reports: in a correct build both `parser_ok` and
#' `depth_limit_ok` are `TRUE`.
#'
#' @return An object of class `zuhtml_info`: a list with elements
#'   `zuhtml_version`, `gumbo_version`, `gumbo_patches` (a character vector
#'   of patch identifiers, in the order applied), `parser_ok` (the bundled
#'   parser builds the expected tree for a fixed document) and
#'   `depth_limit_ok` (the parse-time nesting limit stops a deeply nested
#'   document).
#' @family parsing
#' @export
#' @examples
#' zuhtml_info()
zuhtml_info <- function() {
  info <- .Call(C_zuhtml_info)
  out <- c(
    list(zuhtml_version = unname(getNamespaceVersion("zuhtml"))),
    info
  )
  structure(out, class = "zuhtml_info")
}

#' @export
print.zuhtml_info <- function(x, ...) {
  ok <- function(v) if (isTRUE(v)) "ok" else "FAILED"
  cat(
    sprintf("zuhtml %s\n", x$zuhtml_version),
    sprintf("Gumbo:        %s\n", x$gumbo_version),
    sprintf("Patches:      %s\n", paste(x$gumbo_patches, collapse = ", ")),
    sprintf("Parser:       %s\n", ok(x$parser_ok)),
    sprintf("Depth limit:  %s\n", ok(x$depth_limit_ok)),
    sep = ""
  )
  invisible(x)
}
