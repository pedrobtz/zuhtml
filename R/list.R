#' Extract an HTML list
#'
#' Reads one `<ul>` or `<ol>` element. In `"text"` mode, the result has one
#' string per item: the item's cleaned text (see [html_text_clean()]),
#' without the text of any list nested inside it, so child items do not
#' leak into their parent. A nested list still separates the text around
#' it with a line break. In `"tree"` mode, nested lists become children
#' of the item that contains them, including lists inside wrapper elements
#' such as `<div>`.
#'
#' Items are the `<li>` children of the list, in source order; empty items
#' are `""` and duplicates are kept.
#'
#' @param x A `zuhtml_nodeset` holding exactly one `<ul>` or `<ol>` element,
#'   as from [html_element()].
#' @param mode `"text"` or `"tree"`.
#'
#' @return
#' * `"text"`: a character vector, one string per item.
#' * `"tree"`: an object of class `zuhtml_list`, a list with `type` (`"ul"`
#'   or `"ol"`) and `items`, a list with one element per item; each item is
#'   a list with `text` (as in text mode) and `children` (a list of
#'   `zuhtml_list` objects, one per list nested in the item).
#' @family extraction
#' @export
#' @examples
#' doc <- html_parse("<ul><li>Apples<li>Tools<ul><li>Hammer<li>Saw</ul></ul>")
#' items <- html_element(doc, "ul")
#' html_list(items)
#' html_list(items, mode = "tree")
html_list <- function(x, mode = c("text", "tree")) {
  call <- sys.call()
  if (!is.character(mode) || !(length(mode) == 1L || identical(mode, c("text", "tree"))) ||
      !(mode[[1L]] %in% c("text", "tree"))) {
    zuh_input_error("mode", "`mode` must be \"text\" or \"tree\".",
                    call = call)
  }
  mode <- mode[[1L]]
  l <- zuh_one_element(x, c("ul", "ol"), call)
  if (mode == "text") zuh_list_text(l) else zuh_list_tree(l)
}

zuh_xhtml <- "http://www.w3.org/1999/xhtml"

# x as a single, non-missing HTML element of one of the given names.
zuh_one_element <- function(x, names, call) {
  what <- paste0("<", names, ">", collapse = " or ")
  if (!inherits(x, "zuhtml_nodeset") || length(x) != 1L ||
      is.na(unclass(x))) {
    zuh_input_error(
      "x", sprintf("`x` must be a nodeset holding exactly one %s element.",
                   what),
      call = call
    )
  }
  if (!(html_name(x) %in% names) || !identical(html_namespace(x), zuh_xhtml)) {
    zuh_input_error("x", sprintf("`x` must be a %s element.", what),
                    call = call)
  }
  x
}

zuh_list_items <- function(l) {
  kids <- html_children(l)
  kids[html_name(kids) %in% "li" & html_namespace(kids) %in% zuh_xhtml]
}

zuh_list_text <- function(l) {
  items <- zuh_list_items(l)
  zuh_clean(zuh_nodes(items), skip_lists = TRUE)
}

# The lists an item owns: the outermost <ul>/<ol> elements inside it.
zuh_owned_lists <- function(li) {
  cand <- html_elements(li, "ul, ol")
  cand <- cand[html_namespace(cand) %in% zuh_xhtml]
  n <- zuh_nodes(cand)
  new_nodeset(zuh_checked(.Call(C_zuh_outermost, n$doc$ptr, n$ids), n),
              n$doc)
}

zuh_list_tree <- function(l) {
  items <- zuh_list_items(l)
  texts <- zuh_clean(zuh_nodes(items), skip_lists = TRUE)
  structure(
    list(
      type = html_name(l),
      items = lapply(seq_along(items), function(i) {
        owned <- zuh_owned_lists(items[i])
        list(
          text = texts[[i]],
          children = lapply(seq_along(owned), function(k) {
            zuh_list_tree(owned[k])
          })
        )
      })
    ),
    class = "zuhtml_list"
  )
}

#' @export
print.zuhtml_list <- function(x, n = 20L, ...) {
  shown <- 0L
  walk <- function(l, depth) {
    pad <- strrep("  ", depth)
    ord <- identical(l$type, "ol")
    for (i in seq_along(l$items)) {
      if (shown >= n) return(invisible())
      it <- l$items[[i]]
      mark <- if (ord) paste0(i, ".") else "-"
      text <- gsub("\n", " ", it$text, fixed = TRUE)
      if (nchar(text) > 60L) text <- paste0(substr(text, 1L, 57L), "...")
      cat(pad, mark, " ", text, "\n", sep = "")
      shown <<- shown + 1L
      for (ch in it$children) walk(ch, depth + 1L)
    }
  }
  count <- function(l) {
    length(l$items) +
      sum(vapply(l$items, function(it) {
        sum(vapply(it$children, count, integer(1)))
      }, integer(1)))
  }
  cat(sprintf("<zuhtml_list %s, %d items>\n", x$type, length(x$items)))
  walk(x, 0L)
  total <- count(x)
  if (total > shown) cat(sprintf("... and %d more\n", total - shown))
  invisible(x)
}
