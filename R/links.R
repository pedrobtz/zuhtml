#' Resolve URLs in attributes
#'
#' Reads a URL-valued attribute from each node and resolves it against the
#' document's base URL with the reference-resolution algorithm of RFC 3986,
#' section 5 (<https://www.rfc-editor.org/rfc/rfc3986#section-5>): dot
#' segments are removed and relative, query-only, fragment-only and
#' protocol-relative references are handled. Nothing is fetched.
#'
#' The base URL is `base_url` if given; otherwise the document's first
#' `<base href>` resolved against the `base_url` given to [html_parse()];
#' otherwise that `base_url` alone.
#'
#' This is RFC 3986, not the WHATWG URL Standard browsers implement: there
#' is no IDNA processing, no percent-encoding of characters that need it,
#' and no special handling of backslashes. Leading and trailing ASCII
#' whitespace is removed from the attribute; a reference that still
#' contains whitespace or a control character, or whose scheme is invalid,
#' is malformed.
#'
#' @param x A `zuhtml_document` or `zuhtml_nodeset`.
#' @param attr The attribute holding the URL.
#' @param base_url The base URL to resolve against, overriding the
#'   document's; `NULL` to use the document's.
#'
#' @return A character vector as long as `x`: the resolved URL of each
#'   node. `NA` where the node lacks the attribute, the reference is
#'   malformed, or a relative reference has no absolute base URL to resolve
#'   against; and for missing nodes. The original attribute value stays
#'   available through [html_attr()].
#' @family extraction
#' @export
#' @examples
#' doc <- html_parse(
#'   "<a href='../img/a.png'>A</a><a href='//cdn.example.org/b'>B</a>",
#'   base_url = "https://example.org/docs/page.html"
#' )
#' html_url(html_elements(doc, "a"))
#' html_url(html_elements(doc, "a"), base_url = "http://other.test/x/")
html_url <- function(x, attr = "href", base_url = NULL) {
  call <- sys.call()
  n <- zuh_nodes(x, call = call)
  if (!is.character(attr) || length(attr) != 1L || is.na(attr) ||
      !nzchar(attr)) {
    zuh_input_error("attr", "`attr` must be a single attribute name.",
                    call = call)
  }
  if (!is.null(base_url) &&
      (!is.character(base_url) || length(base_url) != 1L ||
       is.na(base_url))) {
    zuh_input_error("base_url", "`base_url` must be NULL or a single string.",
                    call = call)
  }
  base <- if (is.null(base_url)) zuh_doc_base(n$doc) else base_url
  zuh_resolve(html_attr(x, attr), base)
}

#' Links in a document
#'
#' Finds the `<a>` and `<area>` elements with an `href` below the given
#' nodes (and the nodes themselves), in document order, without
#' duplicates. Duplicate destinations are kept, and so are fragment,
#' `mailto:` and `tel:` links.
#'
#' @param x A `zuhtml_document` or `zuhtml_nodeset`.
#' @param absolute If `TRUE`, `url` is resolved with [html_url()];
#'   otherwise it is `href` unchanged.
#'
#' @return A data frame with one row per link and character columns `text`
#'   (the link's cleaned text, see [html_text_clean()]), `href` (the
#'   attribute as written, decoded) and `url`.
#' @family extraction
#' @export
#' @examples
#' doc <- html_parse(
#'   "<nav><a href='/'>Home</a> <a href='about.html'>About</a></nav>",
#'   base_url = "https://example.org/site/"
#' )
#' html_links(doc)
#' html_links(doc, absolute = TRUE)
html_links <- function(x, absolute = FALSE) {
  call <- sys.call()
  zuh_check_flag(absolute, "absolute", call)
  nodes <- zuh_select_including(x, "a[href], area[href]", call)
  href <- html_attr(nodes, "href")
  data.frame(
    text = html_text_clean(nodes),
    href = href,
    url = if (absolute) html_url(nodes) else href,
    stringsAsFactors = FALSE
  )
}

# The document's base URL: the first <base href>, resolved against the
# parse-time base_url, or that base_url alone. NA if there is none.
zuh_doc_base <- function(doc) {
  given <- if (is.null(doc$base_url)) NA_character_ else doc$base_url
  b <- html_element(doc, "base[href]")
  if (!is.na(unclass(b))) {
    r <- zuh_resolve(html_attr(b, "href"), given)
    if (!is.na(r)) return(r)
  }
  given
}

# RFC 3986 appendix B, with the undefined/empty distinction kept.
zuh_uri_split <- function(s) {
  m <- regmatches(
    s, regexec("^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\\?([^#]*))?(#(.*))?$",
               s)
  )[[1L]]
  list(
    scheme = if (nzchar(m[[2L]])) m[[3L]] else NA_character_,
    authority = if (nzchar(m[[4L]])) m[[5L]] else NA_character_,
    path = m[[6L]],
    query = if (nzchar(m[[7L]])) m[[8L]] else NA_character_,
    fragment = if (nzchar(m[[9L]])) m[[10L]] else NA_character_
  )
}

zuh_uri_ok <- function(s) {
  !is.na(s) && !grepl("[\001-\040\177]", s, useBytes = TRUE)
}

zuh_scheme_ok <- function(scheme) {
  is.na(scheme) || grepl("^[A-Za-z][A-Za-z0-9+.-]*$", scheme)
}

# RFC 3986 section 5.2.4.
zuh_remove_dots <- function(path) {
  input <- path
  out <- character()
  while (nzchar(input)) {
    if (startsWith(input, "../")) {
      input <- substring(input, 4L)
    } else if (startsWith(input, "./")) {
      input <- substring(input, 3L)
    } else if (startsWith(input, "/./")) {
      input <- substring(input, 3L)
    } else if (input == "/.") {
      input <- "/"
    } else if (startsWith(input, "/../")) {
      input <- substring(input, 4L)
      if (length(out)) out <- out[-length(out)]
    } else if (input == "/..") {
      input <- "/"
      if (length(out)) out <- out[-length(out)]
    } else if (input %in% c(".", "..")) {
      input <- ""
    } else {
      start <- if (startsWith(input, "/")) 2L else 1L
      rest <- substring(input, start)
      cut <- regexpr("/", rest, fixed = TRUE)
      seg_end <- if (cut > 0L) start - 1L + cut - 1L else nchar(input)
      out <- c(out, substr(input, 1L, seg_end))
      input <- substring(input, seg_end + 1L)
    }
  }
  paste(out, collapse = "")
}

zuh_uri_join <- function(u) {
  paste0(
    if (!is.na(u$scheme)) paste0(u$scheme, ":") else "",
    if (!is.na(u$authority)) paste0("//", u$authority) else "",
    u$path,
    if (!is.na(u$query)) paste0("?", u$query) else "",
    if (!is.na(u$fragment)) paste0("#", u$fragment) else ""
  )
}

# Resolve each reference against one base (RFC 3986 section 5.2.2,
# strict). NA for a missing or malformed reference, and for a relative one
# without an absolute base.
zuh_resolve <- function(refs, base) {
  refs <- sub("^[\t\n\f\r ]+", "", sub("[\t\n\f\r ]+$", "", refs))
  b <- if (zuh_uri_ok(base)) zuh_uri_split(base) else NULL
  if (!is.null(b) && (is.na(b$scheme) || !zuh_scheme_ok(b$scheme))) b <- NULL
  vapply(refs, function(ref) {
    if (!zuh_uri_ok(ref)) return(NA_character_)
    r <- zuh_uri_split(ref)
    if (!zuh_scheme_ok(r$scheme)) return(NA_character_)
    if (!is.na(r$scheme)) {
      r$path <- zuh_remove_dots(r$path)
      return(zuh_uri_join(r))
    }
    if (is.null(b)) return(NA_character_)
    t <- list(scheme = b$scheme, fragment = r$fragment)
    if (!is.na(r$authority)) {
      t$authority <- r$authority
      t$path <- zuh_remove_dots(r$path)
      t$query <- r$query
    } else {
      t$authority <- b$authority
      if (!nzchar(r$path)) {
        t$path <- b$path
        t$query <- if (!is.na(r$query)) r$query else b$query
      } else {
        if (startsWith(r$path, "/")) {
          t$path <- zuh_remove_dots(r$path)
        } else {
          merged <- if (!is.na(b$authority) && !nzchar(b$path)) {
            paste0("/", r$path)
          } else {
            paste0(sub("[^/]*$", "", b$path), r$path)
          }
          t$path <- zuh_remove_dots(merged)
        }
        t$query <- r$query
      }
    }
    zuh_uri_join(t[c("scheme", "authority", "path", "query", "fragment")])
  }, character(1), USE.NAMES = FALSE)
}
