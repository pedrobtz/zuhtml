#' Convert HTML to Markdown
#'
#' Writes each node as CommonMark text, for reading, for notes, or as input
#' to a language model. Text is skipped and collapsed as
#' [html_text_clean()] does, and Markdown-significant characters in it are
#' escaped, so the text reads back as written.
#'
#' The conversion covers:
#' * headings (`#` to `######`), paragraphs and the other block elements
#'   (separated by blank lines), and thematic breaks (`<hr>`, as `---`);
#' * emphasis (`<em>`, `<i>`) as `*...*` and strong (`<strong>`, `<b>`) as
#'   `**...**`, and inline code (`<code>`, `<kbd>`, `<samp>`, `<tt>`) as a
#'   code span;
#' * `<pre>` as a fenced code block, with its language when a
#'   `language-*` or `lang-*` class names one;
#' * block quotes, and ordered and unordered lists, nested, with `start`,
#'   `reversed` and `value` honored; empty list items are left out;
#' * links and images, their URLs resolved against the document's base URL
#'   as [html_url()] does, or as written where that is not possible; `<a>`
#'   without `href` is plain text, and `<img>` without `src` is left out;
#' * `<br>` as a hard line break;
#' * data tables as GFM pipe tables: tables in which no cell spans rows or
#'   columns and every cell holds only inline content (no paragraphs,
#'   lists, headings, `<div>`s, code blocks or tables). The first row is
#'   the header row, and cell contents stay on one line. Other tables,
#'   such as tables used for page layout, are written as their content,
#'   one paragraph per row, with cells separated by spaces.
#'
#' `<head>`, `<script>`, `<style>`, `<template>`, `<iframe>`, `<svg>` and
#' comments are left out. Other elements contribute their text only. Markup
#' that crosses block boundaries, such as `<b>` around two paragraphs, is
#' closed and reopened in each block.
#'
#' @param x A `zuhtml_document` or `zuhtml_nodeset`.
#'
#' @return A character vector as long as `x`: the Markdown of each element,
#'   document, fragment or text node, without a trailing newline; `NA` for
#'   other nodes and for missing nodes.
#' @family node values
#' @seealso [html_text_clean()] for plain text.
#' @export
#' @examples
#' doc <- html_parse(paste0(
#'   "<h1>Release notes</h1>",
#'   "<p>Version <b>2.0</b> adds <code>fetch()</code>. ",
#'   "See <a href='changes.html'>the changes</a>.</p>",
#'   "<ul><li>Faster parsing</li><li>New <i>options</i>:",
#'   "<ol><li>limits</li><li>encoding</li></ol></li></ul>",
#'   "<table><tr><th>Item</th><th>Cost</th></tr>",
#'   "<tr><td>Tea</td><td>3</td></tr></table>"
#' ), base_url = "https://example.org/docs/")
#' cat(html_markdown(doc))
html_markdown <- function(x) {
  call <- sys.call()
  n <- zuh_nodes(x, call = call)
  refs <- zuh_select_including(x, "a[href], img[src]", call)
  is_img <- html_name(refs) == "img"
  urls <- rep(NA_character_, length(refs))
  urls[!is_img] <- html_url(refs[!is_img], "href")
  urls[is_img] <- html_url(refs[is_img], "src")
  zuh_checked(
    .Call(C_zuh_markdown, n$doc$ptr, n$ids, as.integer(refs), urls), n,
    call = call
  )
}
