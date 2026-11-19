# The CommonMark round trip: the Markdown of a page, rendered by cmark-gfm
# (the commonmark package, in Suggests) and parsed again, against the page
# itself. Used by test-markdown-roundtrip.R.

# The rendered Markdown as a document.
md_back <- function(markdown) {
  html_parse(commonmark::markdown_html(
    markdown, extensions = c("table", "strikethrough")
  ))
}

# What the round trip must keep: the cleaned text, link and image targets,
# the number of lists and of list items that are written (empty ones are
# left out; an item with an image, a rule or a code block is not empty),
# and the text of inline code.
md_shape <- function(doc) {
  code <- html_elements(doc, "code, kbd, samp, tt")
  code <- html_text_clean(code[is.na(html_closest(code, "pre"))])
  written <- function(nodes) {
    html_text_clean(nodes) != "" |
      !is.na(html_element(nodes, "img[src], hr, pre"))
  }
  list(
    text = html_text_clean(doc),
    links = html_attr(html_elements(doc, "a[href]"), "href"),
    images = html_attr(html_elements(doc, "img[src]"), "src"),
    lists = sum(written(html_elements(doc, "ul, ol"))),
    items = sum(written(html_elements(doc, "li"))),
    code = code[code != ""]
  )
}

# The source document, its Markdown and the rendered document.
round_trip <- function(html) {
  src <- html_parse(html)
  out <- html_markdown(src)
  list(src = src, md = out, back = md_back(out))
}

expect_round_trip <- function(html) {
  r <- round_trip(html)
  expect_identical(md_shape(r$back), md_shape(r$src), label = r$md)
  invisible(r)
}

# Per non-whitespace character of the text: is it in emphasis, strong
# emphasis, inline code or a link? A data frame, one row per character.
styled_chars <- function(doc) {
  rows <- list()
  walk <- function(node, em, strong, code, link) {
    type <- html_type(node)
    if (type == "text") {
      ch <- strsplit(html_text(node), "")[[1]]
      ch <- ch[!grepl("[ \t\n\r\f]", ch)]
      if (length(ch) > 0) {
        rows[[length(rows) + 1]] <<- data.frame(
          ch = ch, em = em, strong = strong, code = code, link = link
        )
      }
      return(invisible())
    }
    if (type != "element" && type != "document") return(invisible())
    name <- if (type == "element") html_name(node) else ""
    em <- em || name %in% c("em", "i")
    strong <- strong || name %in% c("strong", "b")
    code <- code || name %in% c("code", "kbd", "samp", "tt")
    link <- link || (name == "a" && !is.na(html_attr(node, "href")))
    kids <- html_children(node, elements_only = FALSE)
    for (i in seq_along(kids)) walk(kids[i], em, strong, code, link)
  }
  walk(doc, FALSE, FALSE, FALSE, FALSE)
  if (length(rows) == 0) {
    return(data.frame(ch = character(), em = logical(), strong = logical(),
                      code = logical(), link = logical()))
  }
  do.call(rbind, rows)
}

# Emphasis may be dropped where it cannot be written safely, never added;
# links and code are kept exactly.
expect_styles_kept <- function(r) {
  a <- styled_chars(r$src)
  b <- styled_chars(r$back)
  expect_identical(b$ch, a$ch, label = r$md)
  if (identical(b$ch, a$ch)) {
    expect_false(any(b$em & !a$em), label = paste("added em:", r$md))
    expect_false(any(b$strong & !a$strong),
                 label = paste("added strong:", r$md))
    expect_identical(b$code, a$code, label = r$md)
    expect_identical(b$link, a$link, label = r$md)
  }
}

# The commonmark round trip needs commonmark, and is skipped under r-actions'
# gctorture job: there most of its cost is commonmark's own allocations, and it
# alone ran the job past its 120-minute limit (#117). zuhtml's Markdown writer
# is still tortured through test-markdown.R.
skip_without_round_trip <- function() {
  testthat::skip_if_not_installed("commonmark")
  if (identical(Sys.getenv("R_ACTIONS_WORKFLOW"), "gctorture")) {
    testthat::skip("the commonmark round trip is not run under gctorture")
  }
}
