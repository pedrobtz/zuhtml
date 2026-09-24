test_that("html_closest() finds the nearest inclusive ancestor, aligned", {
  doc <- html_parse(paste0(
    "<div class=card id=c1><table><tr id=r1><td>1<td><b>x</b></tr></table>",
    "</div><p><b>y</b></p>"
  ))
  b <- html_elements(doc, "b")
  expect_identical(html_attr(html_closest(b, "tr"), "id"), c("r1", NA))
  expect_identical(html_attr(html_closest(b, ".card"), "id"), c("c1", NA))
  expect_identical(html_name(html_closest(b, "td, p")), c("td", "p"))
  # The node itself counts, and :scope is the node.
  expect_identical(html_name(html_closest(b, "b")), c("b", "b"))
  expect_identical(html_name(html_closest(b, ":scope")), c("b", "b"))
  expect_identical(html_name(html_closest(b[c(1, NA)], "tr")), c("tr", NA))
  expect_length(html_closest(b[0], "tr"), 0L)
})

test_that("html_closest() starts from a text node's parent and stops at the root", {
  doc <- html_parse("<ul><li>item <i>i</i></li></ul>")
  text <- html_children(html_element(doc, "li"), elements_only = FALSE)[1]
  expect_identical(html_name(html_closest(text, "ul")), "ul")
  expect_identical(html_name(html_closest(text, "html")), "html")
  expect_true(is.na(unclass(html_closest(text, "section"))))
  expect_true(is.na(unclass(html_closest(doc, "*"))))
  expect_error(html_closest(doc, "li:has(i)"), class = "zuhtml_selector_error")
})

test_that("html_strings() keeps the boundaries html_text() joins", {
  doc <- html_parse("<table><tr><td>1<td>2</table><p>a <b>b</b>\n <i> c </i>")
  expect_identical(html_text(html_element(doc, "tr")), "12")
  expect_identical(html_strings(html_element(doc, "tr")), list(c("1", "2")))
  p <- html_element(doc, "p")
  expect_identical(html_strings(p), list(c("a ", "b", "\n ", " c ")))
  expect_identical(html_strings(p, trim = TRUE), list(c("a", "b", "", "c")))
  expect_identical(html_strings(p, trim = TRUE, drop_empty = TRUE),
                   list(c("a", "b", "c")))
})

test_that("html_strings() skips script, style, template and comments", {
  doc <- html_parse(paste0(
    "<div>x<script>s()</script><style>p{}</style>",
    "<template>t</template><!--c-->y</div>"
  ))
  expect_identical(html_strings(html_element(doc, "div")), list(c("x", "y")))
  expect_identical(html_strings(html_element(doc, "script")), list(character()))
})

test_that("html_strings() is vectorized with missing nodes and text nodes", {
  doc <- html_parse("<p>a</p><p></p>")
  p <- html_elements(doc, "p")
  expect_identical(html_strings(p[c(1, NA, 2)]),
                   list("a", NA_character_, character()))
  text <- html_children(p[1], elements_only = FALSE)
  expect_identical(html_strings(text), list("a"))
  expect_error(html_strings(doc, trim = NA), class = "zuhtml_input_error")
})

test_that("pretty serialization indents blocks and keeps inline content", {
  doc <- html_parse(paste0(
    "<!DOCTYPE html><title>T</title><div><p>One <b>two</b></p>",
    "<ul><li>x</li></ul></div>"
  ))
  out <- strsplit(html_serialize(doc, pretty = TRUE), "\n")[[1L]]
  expect_identical(out, c(
    "<!DOCTYPE html>", "<html>", "  <head>", "    <title>T</title>",
    "  </head>", "  <body>", "    <div>", "      <p>One <b>two</b></p>",
    "      <ul>", "        <li>x</li>", "      </ul>", "    </div>",
    "  </body>", "</html>"
  ))
})

test_that("pretty serialization leaves whitespace-sensitive content alone", {
  pre <- "  a\n    b  "
  doc <- html_parse(paste0(
    "<div><pre>", pre, "</pre><textarea> t\n x</textarea>",
    "<script>if (a) {\n  b();\n}</script></div>"
  ))
  out <- html_serialize(html_element(doc, "div"), pretty = TRUE)
  expect_match(out, paste0("<pre>", pre, "</pre>"), fixed = TRUE)
  expect_match(out, "<textarea> t\n x</textarea>", fixed = TRUE)
  expect_match(out, "<script>if (a) {\n  b();\n}</script>", fixed = TRUE)
  # The tree inside them survives a round trip even when pretty.
  again <- html_parse(out)
  expect_identical(html_text(html_element(again, "pre")),
                   html_text(html_element(doc, "pre")))
})

test_that("pretty serialization drops whitespace-only text between blocks", {
  doc <- html_parse("<div>\n   <p>a</p>\n   <p>b</p>\n</div>")
  expect_identical(
    html_serialize(html_element(doc, "div"), pretty = TRUE),
    "<div>\n  <p>a</p>\n  <p>b</p>\n</div>"
  )
  # A space between inline elements is kept.
  doc <- html_parse("<p><b>a</b> <i>b</i></p>")
  expect_identical(html_serialize(html_element(doc, "p"), pretty = TRUE),
                   "<p><b>a</b> <i>b</i></p>")
  expect_error(html_serialize(doc, pretty = "yes"),
               class = "zuhtml_input_error")
})
