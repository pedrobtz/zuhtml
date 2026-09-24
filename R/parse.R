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
#' @family parsing
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
  zuh_parse(x, encoding, base_url, comments, limits, call = sys.call())
}

# The shared body of html_parse() and html_fragment(). `fragment` is the
# context as c(tag, namespace) from zuh_fragment_context(), or NULL.
zuh_parse <- function(x, encoding, base_url, comments, limits,
                      fragment = NULL, call) {
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
  zuh_parse_bytes(input$bytes, input$encoding, base_url, limits,
                  comments = comments, fragment = fragment, call = call)
}

#' Parse an HTML fragment
#'
#' Parses markup as the contents of a given element, as a browser does for
#' `innerHTML`. The context matters: `"<tr><td>x"` is a table row in a
#' `"tbody"` context but only text in a `"div"`.
#'
#' @param x One string, or a raw vector of encoded bytes.
#' @param context The name of the context element, an HTML element the
#'   bundled parser knows, such as `"div"`, `"tbody"`, `"select"` or
#'   `"template"`.
#' @param ... Arguments passed on to [html_parse()]: `encoding`, `base_url`,
#'   `comments` and `limits`.
#'
#' @return A `zuhtml_document` whose document node is a fragment:
#'   [html_type()] reports `"fragment"`, and [html_root()] returns the
#'   fragment node, whose children are the parsed nodes.
#' @seealso [html_parse()] for whole documents.
#' @family parsing
#' @export
#' @examples
#' frag <- html_fragment("<tr><td>1<td>2", context = "tbody")
#' html_children(html_root(frag))
#' html_fragment("<tr><td>1<td>2")
html_fragment <- function(x, context = "div", ...) {
  call <- sys.call()
  fragment <- zuh_fragment_context(context, call)
  args <- list(...)
  unknown <- setdiff(names(args), c("encoding", "base_url", "comments",
                                    "limits"))
  if (length(args) && (is.null(names(args)) || any(!nzchar(names(args))) ||
                       length(unknown))) {
    zuh_input_error("...", paste0(
      "Arguments in `...` must be named: encoding, base_url, comments or ",
      "limits."
    ), call = call)
  }
  doc <- zuh_parse(
    x,
    encoding = args$encoding,
    base_url = args$base_url,
    comments = if (is.null(args$comments)) TRUE else args$comments,
    limits = if (is.null(args$limits)) html_limits() else args$limits,
    fragment = fragment,
    call = call
  )
  doc$context <- tolower(context)
  doc
}

# c(tag, namespace) for an HTML context element name, or an input error.
# `namespace` and `allow_unknown` are for the conformance runner only: the
# public API parses in HTML contexts the bundled parser knows.
zuh_fragment_context <- function(context, call, namespace = 0L,
                                 allow_unknown = FALSE) {
  if (!is.character(context) || length(context) != 1L || is.na(context) ||
      !nzchar(context)) {
    zuh_input_error("context", "`context` must be a single element name.",
                    call = call)
  }
  tag <- .Call(C_zuh_tag_lookup, enc2utf8(context), allow_unknown)
  if (tag < 0L) {
    zuh_input_error(
      "context",
      sprintf("\"%s\" is not an element the bundled parser knows.", context),
      call = call
    )
  }
  c(tag, as.integer(namespace))
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
    if (zuh_canon_enc(used) %in% c("UTF16", "UTF16LE", "UTF16BE")) {
      bytes <- zuh_utf16(x, used, bom, call)
    } else if (zuh_canon_enc(used) == "UTF8") {
      bytes <- zuh_strip_bom(x)
      if (any(bytes == as.raw(0L))) {
        zuh_input_error("x", "The input contains a NUL byte.", call = call)
      }
      if (!validUTF8(rawToChar(bytes))) {
        zuh_abort("encoding", "The input is not valid UTF-8.",
                  encoding = used, call = call)
      }
    } else {
      if (any(x == as.raw(0L))) {
        zuh_input_error("x", "The input contains a NUL byte.", call = call)
      }
      bytes <- zuh_iconv(x, used, call)
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

# UTF-16 is decoded here rather than by iconv(), whose handling of invalid
# UTF-16 differs across platforms (see zuh_iconv()). Strict: an odd byte
# count and any unpaired surrogate are errors.
zuh_utf16 <- function(x, encoding, bom, call) {
  bad <- function() {
    zuh_abort(
      "encoding",
      sprintf("The input is not valid in encoding \"%s\".", encoding),
      encoding = encoding, call = call
    )
  }
  # A BOM decides the byte order of plain "UTF-16"; without one it is
  # big-endian, as the Unicode standard specifies.
  enc <- zuh_canon_enc(encoding)
  big <- if (enc == "UTF16") !identical(bom, "UTF-16LE") else enc == "UTF16BE"
  if (!is.na(bom) && bom %in% c("UTF-16LE", "UTF-16BE")) x <- x[-(1:2)]
  if (length(x) %% 2L != 0L) bad()
  if (length(x) == 0L) return(raw())
  b <- as.integer(x)
  odd <- b[c(TRUE, FALSE)]
  even <- b[c(FALSE, TRUE)]
  u <- if (big) odd * 256L + even else even * 256L + odd
  hi <- which(u >= 0xD800L & u <= 0xDBFFL)
  lo <- which(u >= 0xDC00L & u <= 0xDFFFL)
  if (length(hi) != length(lo) || any(lo != hi + 1L)) bad()
  if (length(hi)) {
    u[hi] <- 0x10000L + (u[hi] - 0xD800L) * 1024L + (u[lo] - 0xDC00L)
    u <- u[-lo]
  }
  if (any(u == 0L)) {
    zuh_input_error("x", "The input contains a NUL character.", call = call)
  }
  zuh_strip_bom(charToRaw(intToUtf8(u)))
}

# Every encoding that reaches here is ASCII-compatible (UTF-16 is decoded
# by zuh_utf16(), and input with a NUL byte is rejected before). R's iconv()
# does not reliably report invalid input when converting raw vectors: some
# builds hand back the original bytes unchanged, or with a NUL in them. So
# a conversion fails if two runs with different substitution bytes differ,
# if the output is identical to input with non-ASCII bytes (a real
# conversion changes those), if the output has a NUL (the input had none),
# or if the output is not valid UTF-8.
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
  out <- a[[1L]]
  if (is.null(out) || !identical(out, b[[1L]]) ||
      (identical(out, x) && any(x >= as.raw(0x80L))) ||
      any(out == as.raw(0L)) || !validUTF8(rawToChar(out))) {
    zuh_abort(
      "encoding",
      sprintf("The input is not valid in encoding \"%s\".", from),
      encoding = from, call = call
    )
  }
  zuh_strip_bom(out)
}

# Status codes of zuh_status in src/zuh_status.h, in enum order.
zuh_status_names <- c(
  "ok", "limit_input", "limit_memory", "limit_depth", "limit_nodes",
  "internal"
)

# Parse decoded UTF-8 bytes. fail_at > 0 injects an allocation failure at
# that allocation index; tests use it, html_parse() never does.
zuh_parse_bytes <- function(bytes, encoding, base_url, limits,
                            comments = TRUE, fragment = NULL, fail_at = 0,
                            call = sys.call(-1L)) {
  ptr <- .Call(C_zuh_doc_new)
  res <- .Call(
    C_zuh_parse, ptr, bytes,
    c(limits$max_input, limits$max_memory, limits$max_depth,
      limits$max_errors, limits$max_nodes),
    comments,
    if (is.null(fragment)) c(-1L, 0L) else as.integer(fragment),
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
#' @param x A `zuhtml_document`, or a `zuhtml_nodeset` for the document
#'   that owns it.
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
  call <- sys.call()
  p <- .Call(C_zuh_doc_problems,
             zuh_doc_ptr(zuh_nodes(x, call = call)$doc, call = call))
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
  if (m$is_fragment) {
    cat(sprintf("fragment: in <%s>\n", x$context))
  } else if (!is.na(m$root)) {
    kids <- html_children(html_root(x))
    cat(sprintf("root:     <html> with %s\n",
                paste0("<", html_name(kids), ">", collapse = ", ")))
  }
  cat(sprintf("nodes:    %.0f\n", m$n_nodes))
  cat(sprintf("input:    %.0f bytes (%s)\n", m$input_bytes, x$encoding))
  cat(sprintf("problems: %.0f%s\n", m$n_problems,
              if (m$problems_truncated) " (truncated)" else ""))
  invisible(x)
}

#' Information about a parsed document
#'
#' @param x A `zuhtml_document`, or a `zuhtml_nodeset` for the document
#'   that owns it.
#'
#' @return An object of class `zuhtml_doc_info`: a list with
#'   * `type`: `"document"` or `"fragment"`;
#'   * `context`: a fragment's context element, `NA` for a document;
#'   * `nodes`, `attributes`: counts;
#'   * `native_bytes`: memory the document owns, outside R's heap;
#'   * `parse_peak_bytes`: the most memory the parser held at once;
#'   * `input_bytes`: size of the decoded UTF-8 input;
#'   * `encoding`: the encoding the input was decoded from;
#'   * `base_url`: the `base_url` given to [html_parse()], or `NA`;
#'   * `quirks_mode`: `"no-quirks"`, `"quirks"` or `"limited-quirks"`, as
#'     the doctype selected;
#'   * `problems`: the number of parse problems kept, and
#'     `problems_truncated`: whether more occurred than `max_errors`.
#' @family parsing
#' @export
#' @examples
#' html_info(html_parse("<!DOCTYPE html><title>t</title><p>Hello"))
html_info <- function(x) {
  call <- sys.call()
  doc <- zuh_nodes(x, call = call)$doc
  m <- .Call(C_zuh_doc_meta, zuh_doc_ptr(doc, call = call))
  structure(
    list(
      type = if (m$is_fragment) "fragment" else "document",
      context = if (is.null(doc$context)) NA_character_ else doc$context,
      nodes = m$n_nodes,
      attributes = m$n_attrs,
      native_bytes = m$frozen_bytes,
      parse_peak_bytes = m$parse_peak_bytes,
      input_bytes = m$input_bytes,
      encoding = doc$encoding,
      base_url = if (is.null(doc$base_url)) NA_character_ else doc$base_url,
      quirks_mode = m$quirks_mode,
      problems = m$n_problems,
      problems_truncated = m$problems_truncated
    ),
    class = "zuhtml_doc_info"
  )
}

#' @export
print.zuhtml_doc_info <- function(x, ...) {
  cat("<zuhtml_doc_info>\n")
  w <- max(nchar(names(x)))
  for (nm in names(x)) {
    v <- x[[nm]]
    if (is.numeric(v)) v <- format(v, big.mark = ",", scientific = FALSE)
    cat(sprintf("  %-*s %s\n", w, nm, v))
  }
  invisible(x)
}
