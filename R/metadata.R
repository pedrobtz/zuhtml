#' Document title
#'
#' The document's title as the HTML standard defines `document.title`: the
#' text of the first `<title>` element in the HTML namespace, with leading
#' and trailing whitespace removed and runs of whitespace collapsed to one
#' space. An SVG `<title>` does not count.
#'
#' @param x A `zuhtml_document`, or a `zuhtml_nodeset` whose document is
#'   used.
#'
#' @return A single string, `NA` when the document has no `<title>`.
#' @family metadata
#' @export
#' @examples
#' html_title(html_parse("<title>  Annual\n  report </title><p>Body"))
#' html_title(html_parse("<p>No title"))
html_title <- function(x) {
  call <- sys.call()
  n <- zuh_nodes(x, call = call)
  titles <- html_elements(n$doc, "title")
  titles <- titles[html_namespace(titles) == zuh_xhtml]
  if (length(titles) == 0L) return(NA_character_)
  t <- paste(html_text(titles[1L]), collapse = "")
  gsub("[ \t\n\r\f]+", " ", trimws(t, whitespace = "[ \t\n\r\f]"))
}

#' Meta tags
#'
#' One row per `<meta>` element below the given nodes (and the nodes
#' themselves), in document order. Duplicates are kept, so OpenGraph
#' (`og:*` in `property`), Twitter cards and Dublin Core (`name`) come out
#' as rows to filter.
#'
#' @param x A `zuhtml_document` or `zuhtml_nodeset`.
#'
#' @return A data frame with character columns `name`, `property`,
#'   `http_equiv`, `charset` and `content`, each the attribute as written
#'   (decoded) or `NA` when absent. `name`, `property` and `http_equiv` keep
#'   their case; compare with [tolower()].
#' @family metadata
#' @export
#' @examples
#' doc <- html_parse(paste0(
#'   "<meta charset='utf-8'>",
#'   "<meta name='description' content='A page.'>",
#'   "<meta property='og:title' content='Title'>",
#'   "<meta property='og:image' content='a.png'>",
#'   "<meta property='og:image' content='b.png'>"
#' ))
#' meta <- html_meta(doc)
#' meta
#' meta$content[meta$property %in% "og:image"]
html_meta <- function(x) {
  call <- sys.call()
  m <- zuh_select_including(x, "meta", call)
  data.frame(
    name = html_attr(m, "name"),
    property = html_attr(m, "property"),
    http_equiv = html_attr(m, "http-equiv"),
    charset = html_attr(m, "charset"),
    content = html_attr(m, "content"),
    stringsAsFactors = FALSE
  )
}

#' JSON-LD blocks
#'
#' The structured data pages embed as JSON-LD: the text of each
#' `<script type="application/ld+json">` below the given nodes (and the
#' nodes themselves), in document order. The type is matched as a MIME
#' type: case-insensitively, ignoring surrounding whitespace and any
#' parameters.
#'
#' @param x A `zuhtml_document` or `zuhtml_nodeset`.
#' @param parse If `TRUE`, parse each block with [jsonlite::fromJSON()]
#'   (with `simplifyVector = FALSE`, so objects are named lists and arrays
#'   are lists). This needs the jsonlite package. A wrapper around the
#'   whole block, `<![CDATA[ ... ]]>` or `<!-- ... -->`, optionally
#'   commented out with `//` or `/* */` as pages often do, is removed first.
#'
#' @return With `parse = FALSE`, a character vector: the text of each
#'   block, exactly as written. With `parse = TRUE`, a list as long as that
#'   vector: each block's parsed value, or `NULL` for a block that is not
#'   valid JSON; the texts are kept in its attribute `"json"`.
#' @family metadata
#' @export
#' @examples
#' doc <- html_parse(paste0(
#'   "<script type='application/ld+json'>",
#'   '{"@context": "https://schema.org", "@type": "Person", "name": "Ada"}',
#'   "</script>"
#' ))
#' html_json_ld(doc)
#' if (requireNamespace("jsonlite", quietly = TRUE)) {
#'   html_json_ld(doc, parse = TRUE)[[1]]$name
#' }
html_json_ld <- function(x, parse = FALSE) {
  call <- sys.call()
  zuh_check_flag(parse, "parse", call)
  if (parse && !requireNamespace("jsonlite", quietly = TRUE)) {
    zuh_input_error(
      "parse", "`parse = TRUE` needs the jsonlite package; install it.",
      call = call
    )
  }
  s <- zuh_select_including(x, "script[type]", call)
  mime <- tolower(trimws(sub(";.*$", "", html_attr(s, "type")),
                         whitespace = "[ \t\n\r\f]"))
  text <- html_text(s[mime == "application/ld+json"])
  if (!parse) return(text)
  out <- lapply(text, function(t) {
    tryCatch(jsonlite::fromJSON(zuh_unwrap_json(t), simplifyVector = FALSE),
             error = function(e) NULL)
  })
  attr(out, "json") <- text
  out
}

# Remove one wrapper around a whole script body: <![CDATA[ ... ]]> or
# <!-- ... -->, each marker optionally behind // or inside /* */.
zuh_unwrap_json <- function(t) {
  ws <- "[ \t\n\r\f]*"
  open <- paste0("^", ws, "(//|/\\*)?", ws, "(<!\\[CDATA\\[|<!--)",
                 ws, "(\\*/)?")
  m <- regmatches(t, regexec(open, t))[[1L]]
  if (length(m) == 0L) return(t)
  close <- if (m[[3L]] == "<!--") "-->" else "\\]\\]>"
  t <- substring(t, nchar(m[[1L]]) + 1L)
  sub(paste0("(//|/\\*)?", ws, close, ws, "(\\*/)?", ws, "$"), "", t)
}

#' Microdata items
#'
#' The top-level microdata items (elements with `itemscope` and no
#' `itemprop`) below the given nodes (and the nodes themselves), in document
#' order, with their properties collected by the HTML standard's algorithm
#' (<https://html.spec.whatwg.org/multipage/microdata.html>), including
#' properties pulled in by `itemref`. RDFa is not read.
#'
#' Each property's value follows the standard: a nested item for an element
#' with `itemscope`; the `content` attribute of `<meta>`; the resolved
#' `src` of `<audio>`, `<embed>`, `<iframe>`, `<img>`, `<source>`, `<track>`
#' and `<video>`, `href` of `<a>`, `<area>` and `<link>`, and `data` of
#' `<object>` (resolved as [html_url()] does, `""` when that fails); the
#' `value` attribute of `<data>` and `<meter>`; the `datetime` attribute of
#' `<time>` when present. Otherwise it is the element's text, which here is
#' cleaned as [html_text_clean()] does, not the raw `textContent`. An item
#' that is its own ancestor through `itemref` is `NULL`.
#'
#' @param x A `zuhtml_document` or `zuhtml_nodeset`.
#'
#' @return A list of items. Each item is a list with `type` (the tokens of
#'   `itemtype`, a character vector, possibly empty), `id` (`itemid`
#'   resolved as a URL, `NA` when absent or without `itemtype`) and
#'   `properties`: a named list, in document order of first appearance, of
#'   lists of values, since a name may occur more than once. A value is a
#'   string or a nested item.
#' @family metadata
#' @export
#' @examples
#' doc <- html_parse(paste0(
#'   "<div itemscope itemtype='https://schema.org/Book'>",
#'   "<span itemprop='name'>Dune</span>",
#'   "<div itemprop='author' itemscope itemtype='https://schema.org/Person'>",
#'   "<span itemprop='name'>Frank Herbert</span></div>",
#'   "<meta itemprop='isbn' content='9780441013593'>",
#'   "</div>"
#' ))
#' book <- html_microdata(doc)[[1]]
#' book$type
#' book$properties$name[[1]]
#' book$properties$author[[1]]$properties$name[[1]]
html_microdata <- function(x) {
  call <- sys.call()
  tops <- zuh_select_including(x, "[itemscope]:not([itemprop])", call)
  base <- zuh_doc_base(zuh_owner(tops))
  lapply(seq_along(tops), function(i) zuh_item(tops[i], base, integer()))
}

zuh_ws_tokens <- function(s) {
  if (is.na(s)) return(character())
  t <- strsplit(s, "[ \t\n\r\f]+")[[1L]]
  unique(t[nzchar(t)])
}

# The properties of one item, per "the properties of an item" in the HTML
# standard, as a nodeset in tree order. Node IDs are preorder, so an
# ancestor has a smaller ID than its descendants; that turns "nearest
# itemscope ancestor lies inside E's subtree" into a comparison.
zuh_item_props <- function(item) {
  doc <- zuh_owner(item)
  root <- as.integer(item)
  found <- zuh_scope_props(item, root, own = TRUE)
  for (id in zuh_ws_tokens(html_attr(item, "itemref"))) {
    e <- html_element(doc, paste0("[id=\"", zuh_css_string(id), "\"]"))
    if (is.na(unclass(e)) || as.integer(e) == root) next
    found <- c(found, zuh_scope_props(e, as.integer(e), own = FALSE))
  }
  found <- zuh_set(found[found != root])
  new_nodeset(found, doc)
}

zuh_scope_props <- function(e, start, own) {
  cand <- html_elements(e, "[itemprop]")
  near <- as.integer(html_closest(html_parent(cand), "[itemscope]"))
  keep <- if (own) near %in% start else is.na(near) | near < start
  ids <- as.integer(cand)[keep]
  if (!own && !is.na(html_attr(e, "itemprop"))) ids <- c(start, ids)
  ids
}

zuh_css_string <- function(s) gsub("([\\\\\"])", "\\\\\\1", s)

zuh_item <- function(item, base, seen) {
  id <- as.integer(item)
  if (id %in% seen) return(NULL)
  seen <- c(seen, id)
  type <- zuh_ws_tokens(html_attr(item, "itemtype"))
  itemid <- NA_character_
  if (length(type) && !is.na(html_attr(item, "itemid"))) {
    itemid <- zuh_resolve(html_attr(item, "itemid"), base)
  }
  props <- zuh_item_props(item)
  properties <- structure(list(), names = character())
  for (i in seq_along(props)) {
    p <- props[i]
    value <- if (!is.na(html_attr(p, "itemscope"))) {
      list(zuh_item(p, base, seen))
    } else {
      list(zuh_prop_value(p, base))
    }
    for (name in zuh_ws_tokens(html_attr(p, "itemprop"))) {
      properties[[name]] <- c(properties[[name]], value)
    }
  }
  list(type = type, id = itemid, properties = properties)
}

zuh_url_props <- c(
  audio = "src", embed = "src", iframe = "src", img = "src",
  source = "src", track = "src", video = "src", a = "href", area = "href",
  link = "href", object = "data"
)

zuh_prop_value <- function(p, base) {
  name <- html_name(p)
  if (name == "meta") return(html_attr(p, "content", default = ""))
  if (name %in% names(zuh_url_props)) {
    u <- zuh_resolve(html_attr(p, zuh_url_props[[name]], default = ""), base)
    return(if (is.na(u)) "" else u)
  }
  if (name %in% c("data", "meter")) {
    return(html_attr(p, "value", default = ""))
  }
  if (name == "time" && !is.na(html_attr(p, "datetime"))) {
    return(html_attr(p, "datetime"))
  }
  html_text_clean(p)
}
