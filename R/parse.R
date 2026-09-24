#' Parse HTML
#'
#' `html_parse()` parses one string or raw vector of HTML the way a browser
#' does: omitted end tags, unquoted attributes, character references and
#' misnested elements are repaired by the HTML parsing algorithm, never
#' rejected. `html_read()` reads and parses one local file.
#'
#' Neither function fetches anything. `html_parse()` never treats a string
#' as a file name or URL, and `html_read()` never downloads.
#'
#' @section Encoding:
#' A character string is taken as text: it is converted to UTF-8 with
#' [enc2utf8()], and `encoding` must be `NULL` or `"UTF-8"`. A string marked
#' as `"bytes"` is rejected; pass a raw vector instead.
#'
#' A raw vector is decoded with, in order of precedence, `encoding`, a
#' byte-order mark (UTF-8, UTF-16LE or UTF-16BE), or UTF-8. A byte-order mark
#' that contradicts `encoding` is an error, and so is any byte sequence that
#' is invalid in the chosen encoding: nothing is replaced silently.
#' `<meta charset>` declarations are not consulted. A fetcher that knows the
#' HTTP charset should pass it as `encoding`.
#'
#' A leading byte-order mark is removed. Input containing a NUL character
#' after decoding is rejected.
#'
#' @param x One string, or a raw vector of encoded bytes.
#' @param encoding The encoding of raw input, as a name [iconv()] accepts;
#'   `NULL` to use a byte-order mark or UTF-8.
#' @param base_url The document's URL, used to resolve relative links; `NULL`
#'   if unknown.
#' @param comments Whether to keep comment nodes.
#' @param limits Resource limits from [html_limits()].
#' @param path Path of one local file.
#' @param ... Arguments passed on to `html_parse()`.
#'
#' @return A `zuhtml_document`.
#' @seealso [html_problems()] for the parse errors that were repaired;
#'   [html_limits()]; [zuhtml-conditions] for the errors these functions
#'   raise.
#' @export
#' @examples
#' doc <- html_parse("<p>Hello <b>world</b>")
#' doc
#'
#' # Raw bytes in a declared encoding:
#' html_parse(as.raw(c(0x3c, 0x70, 0x3e, 0xe9)), encoding = "latin1")
#'
#' # From a file:
#' path <- tempfile(fileext = ".html")
#' writeLines("<title>Saved page</title><p>Text", path)
#' html_read(path)
html_parse <- function(x, encoding = NULL, base_url = NULL, comments = TRUE,
                       limits = html_limits()) {
  call <- sys.call()
  limits <- zuh_check_limits(limits, call = call)
  if (!is.logical(comments) || length(comments) != 1L || is.na(comments)) {
    zuh_input_error("comments", "`comments` must be TRUE or FALSE.",
                    call = call)
  }
  if (!is.null(base_url) &&
      (!is.character(base_url) || length(base_url) != 1L ||
       is.na(base_url))) {
    zuh_input_error("base_url", "`base_url` must be NULL or a single string.",
                    call = call)
  }
  input <- zuh_decode(x, encoding, limits, call)
  zuh_parse_bytes(input$bytes, input$encoding, base_url, limits, call = call)
}

#' @rdname html_parse
#' @export
html_read <- function(path, ...) {
  call <- sys.call()
  if (!is.character(path) || length(path) != 1L || is.na(path) ||
      !nzchar(path)) {
    zuh_input_error("path", "`path` must be a single file path.", call = call)
  }
  if (!file.exists(path) || dir.exists(path)) {
    zuh_input_error(
      "path", sprintf("Cannot read '%s': no such file.", path),
      call = call
    )
  }
  dots <- list(...)
  limits <- zuh_check_limits(
    if (is.null(dots$limits)) html_limits() else dots$limits,
    call = call
  )
  # Four bytes per character is the most any supported encoding needs, so a
  # larger file cannot decode to less than max_input. Checked before reading.
  size <- file.size(path)
  if (size > 4 * limits$max_input) {
    zuh_limit_error(
      "max_input", limits$max_input, size,
      sprintf("'%s' is %.0f bytes, too large for max_input = %.0f.",
              path, size, limits$max_input),
      call = call
    )
  }
  html_parse(readBin(path, "raw", n = size), ...)
}

# Decode `x` to UTF-8 bytes per the contract documented in html_parse().
# Returns list(bytes = <raw>, encoding = <name used>).
zuh_decode <- function(x, encoding, limits, call) {
  if (!is.null(encoding) &&
      (!is.character(encoding) || length(encoding) != 1L ||
       is.na(encoding) || !nzchar(encoding))) {
    zuh_input_error("encoding", "`encoding` must be NULL or a single string.",
                    call = call)
  }
  if (is.character(x)) {
    if (length(x) != 1L || is.na(x)) {
      zuh_input_error(
        "x", "`x` must be a single non-missing string or a raw vector.",
        call = call
      )
    }
    if (!is.null(encoding) && zuh_canon_enc(encoding) != "UTF8") {
      zuh_input_error(
        "encoding",
        paste0("`encoding` applies to raw input only: a string is already ",
               "decoded. Pass the bytes as a raw vector instead."),
        call = call
      )
    }
    if (Encoding(x) == "bytes") {
      zuh_input_error(
        "x", "`x` is marked as \"bytes\"; pass a raw vector instead.",
        call = call
      )
    }
    x <- enc2utf8(x)
    if (!validUTF8(x)) {
      zuh_abort("encoding", "`x` is not valid UTF-8.", encoding = "UTF-8",
                call = call)
    }
    bytes <- zuh_strip_bom(charToRaw(x))
    used <- "UTF-8"
  } else if (is.raw(x)) {
    bom <- zuh_bom(x)
    used <- if (!is.null(encoding)) encoding else if (!is.na(bom)) bom else
      "UTF-8"
    if (!is.null(encoding) && !is.na(bom) &&
        !zuh_bom_matches(bom, encoding)) {
      zuh_abort(
        "encoding",
        sprintf("The byte-order mark says %s but `encoding` is \"%s\".",
                bom, encoding),
        encoding = encoding, call = call
      )
    }
    if (length(x) > 4 * limits$max_input) {
      zuh_limit_error(
        "max_input", limits$max_input, length(x),
        sprintf("Input of %.0f bytes is too large for max_input = %.0f.",
                length(x), limits$max_input),
        call = call
      )
    }
    if (zuh_canon_enc(used) == "UTF8") {
      bytes <- zuh_strip_bom(x)
      if (any(bytes == as.raw(0L))) {
        zuh_input_error("x", "The input contains a NUL byte.", call = call)
      }
      if (!validUTF8(rawToChar(bytes))) {
        zuh_abort("encoding", "The input is not valid UTF-8.",
                  encoding = used, call = call)
      }
    } else {
      bytes <- zuh_iconv(x, used, call)
      if (any(bytes == as.raw(0L))) {
        zuh_input_error("x", "The input contains a NUL character.",
                        call = call)
      }
    }
  } else {
    zuh_input_error(
      "x", "`x` must be a single non-missing string or a raw vector.",
      call = call
    )
  }
  if (length(bytes) > limits$max_input) {
    zuh_limit_error(
      "max_input", limits$max_input, length(bytes),
      sprintf("Decoded input of %.0f bytes exceeds max_input = %.0f.",
              length(bytes), limits$max_input),
      call = call
    )
  }
  list(bytes = bytes, encoding = used)
}

zuh_canon_enc <- function(enc) toupper(gsub("[-_ ]", "", enc))

# The encoding a leading byte-order mark names, or NA.
zuh_bom <- function(x) {
  n <- length(x)
  if (n >= 3L && x[1L] == as.raw(0xef) && x[2L] == as.raw(0xbb) &&
      x[3L] == as.raw(0xbf)) {
    return("UTF-8")
  }
  if (n >= 2L && x[1L] == as.raw(0xfe) && x[2L] == as.raw(0xff)) {
    return("UTF-16BE")
  }
  if (n >= 2L && x[1L] == as.raw(0xff) && x[2L] == as.raw(0xfe)) {
    return("UTF-16LE")
  }
  NA_character_
}

zuh_bom_matches <- function(bom, encoding) {
  enc <- zuh_canon_enc(encoding)
  b <- zuh_canon_enc(bom)
  enc == b || (enc == "UTF16" && b %in% c("UTF16LE", "UTF16BE"))
}

zuh_strip_bom <- function(bytes) {
  if (length(bytes) >= 3L && bytes[1L] == as.raw(0xef) &&
      bytes[2L] == as.raw(0xbb) && bytes[3L] == as.raw(0xbf)) {
    bytes <- bytes[-(1:3)]
  }
  bytes
}

# R's iconv() does not reliably report invalid input when converting raw
# vectors: with the default `sub = NA` some builds hand back the original
# bytes unchanged. Converting twice with two different substitution bytes
# does: the results differ exactly when something was substituted.
zuh_iconv <- function(x, from, call) {
  convert <- function(sub) {
    tryCatch(
      iconv(list(x), from = from, to = "UTF-8", toRaw = TRUE, sub = sub),
      error = function(e) NULL,
      warning = function(w) NULL
    )
  }
  a <- convert("\001")
  b <- convert("\002")
  if (is.null(a) || is.null(b)) {
    zuh_abort(
      "encoding", sprintf("Encoding \"%s\" is not supported.", from),
      encoding = from, call = call
    )
  }
  if (is.null(a[[1L]]) || !identical(a[[1L]], b[[1L]])) {
    zuh_abort(
      "encoding",
      sprintf("The input is not valid in encoding \"%s\".", from),
      encoding = from, call = call
    )
  }
  zuh_strip_bom(a[[1L]])
}

# Status codes of zuh_status in src/zuh_status.h, in enum order.
zuh_status_names <- c(
  "ok", "limit_input", "limit_memory", "limit_depth", "limit_nodes",
  "internal"
)

# Parse decoded UTF-8 bytes. fail_at > 0 injects an allocation failure at
# that allocation index; tests use it, html_parse() never does.
zuh_parse_bytes <- function(bytes, encoding, base_url, limits, fail_at = 0,
                            call = sys.call(-1L)) {
  ptr <- .Call(C_zuh_doc_new)
  res <- .Call(
    C_zuh_parse, ptr, bytes,
    c(limits$max_input, limits$max_memory, limits$max_depth,
      limits$max_errors),
    as.double(fail_at)
  )
  status <- zuh_status_names[res[[1L]] + 1L]
  observed <- res[[2L]]
  switch(
    status,
    ok = NULL,
    limit_input = zuh_limit_error(
      "max_input", limits$max_input, observed,
      sprintf("Input of %.0f bytes exceeds max_input = %.0f.",
              observed, limits$max_input),
      call = call
    ),
    limit_memory = zuh_limit_error(
      "max_memory", limits$max_memory, NA_real_,
      sprintf(paste0("Parsing needed more native memory than ",
                     "max_memory = %.0f bytes allows."), limits$max_memory),
      call = call
    ),
    limit_depth = zuh_limit_error(
      "max_depth", limits$max_depth, observed,
      sprintf("Elements are nested deeper than max_depth = %.0f.",
              limits$max_depth),
      call = call
    ),
    limit_nodes = zuh_limit_error(
      "max_nodes", limits$max_nodes, observed,
      sprintf("The document has more than max_nodes = %.0f nodes.",
              limits$max_nodes),
      call = call
    ),
    zuh_abort("parse", "Internal parser error; please report it.",
              call = call)
  )
  structure(
    list(ptr = ptr, encoding = encoding, base_url = base_url),
    class = "zuhtml_document"
  )
}

# The external pointer of a document, checked to be alive.
zuh_doc_ptr <- function(x, arg = "x", call = sys.call(-1L)) {
  if (!inherits(x, "zuhtml_document")) {
    zuh_input_error(arg, sprintf("`%s` must be a zuhtml_document.", arg),
                    call = call)
  }
  if (!.Call(C_zuh_doc_alive, x$ptr)) {
    zuh_abort(
      "pointer",
      paste0("This document is no longer available, for example because ",
             "it was restored from a saved session. Parse the HTML again."),
      call = call
    )
  }
  x$ptr
}

#' Parse problems recorded for a document
#'
#' HTML parsing never fails on malformed markup: the parser repairs it as a
#' browser would. `html_problems()` lists what was repaired, which is useful
#' for diagnosing why a tree looks the way it does. Real pages nearly always
#' have some. This is not a conformance validator.
#'
#' @param x A `zuhtml_document`.
#'
#' @return A data frame with one row per problem, in input order, and
#'   columns `stage` (`"tokenizer"` or `"parser"`), `code` (a stable
#'   package-owned name, such as `"unexpected-end-tag"` or
#'   `"duplicate-attr"`), `line` and `column` (1-based) and `byte_offset`
#'   (0-based, into the decoded UTF-8 input). At most `max_errors` problems
#'   are kept (see [html_limits()]); attribute `"truncated"` is `TRUE` when
#'   more occurred.
#' @export
#' @examples
#' doc <- html_parse("<p>One</div><p id=a id=b>Two")
#' html_problems(doc)
html_problems <- function(x) {
  p <- .Call(C_zuh_doc_problems, zuh_doc_ptr(x))
  out <- data.frame(
    stage = p$stage,
    code = p$code,
    line = p$line,
    column = p$column,
    byte_offset = p$byte_offset,
    stringsAsFactors = FALSE
  )
  attr(out, "truncated") <- p$truncated
  out
}

#' @export
print.zuhtml_document <- function(x, ...) {
  cat("<zuhtml_document>\n")
  if (!.Call(C_zuh_doc_alive, x$ptr)) {
    cat("(no longer available)\n")
    return(invisible(x))
  }
  m <- .Call(C_zuh_doc_meta, x$ptr)
  cat(sprintf("input:    %.0f bytes (%s)\n", m$input_bytes, x$encoding))
  cat(sprintf("problems: %.0f%s\n", m$n_problems,
              if (m$problems_truncated) " (truncated)" else ""))
  invisible(x)
}
