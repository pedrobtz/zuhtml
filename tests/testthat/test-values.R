test_that("names, namespaces and types", {
  doc <- html_parse(paste0(
    "<!DOCTYPE html><p>t<!--c--></p><svg><foreignObject/></svg>",
    "<math><mi>x</mi></math><my-el/>"
  ))
  body <- body_of(doc)
  kids <- html_children(body)
  expect_identical(html_name(kids), c("p", "svg", "math", "my-el"))
  expect_identical(
    html_namespace(kids),
    c("http://www.w3.org/1999/xhtml", "http://www.w3.org/2000/svg",
      "http://www.w3.org/1998/Math/MathML", "http://www.w3.org/1999/xhtml")
  )
  expect_identical(html_name(html_children(kids[2])), "foreignObject")
  inner <- html_children(kids[1], elements_only = FALSE)
  expect_identical(html_type(inner), c("text", "comment"))
  expect_identical(html_name(inner), c(NA_character_, NA_character_))
  expect_identical(html_namespace(inner), c(NA_character_, NA_character_))
  dt <- html_children(doc, elements_only = FALSE)[1]
  expect_identical(html_type(dt), "doctype")
  expect_identical(html_name(dt), "html")
  expect_identical(html_text(dt), NA_character_)
})

test_that("processing instructions are a node type in foreign content", {
  doc <- html_parse("<svg><?pi data?></svg>")
  svg <- html_children(body_of(doc))
  pi <- html_children(svg, elements_only = FALSE)
  expect_identical(html_type(pi), "processing_instruction")
  expect_identical(html_text(pi), "pi data")
})

test_that("html_attr() reads decoded values with a default", {
  doc <- html_parse(
    "<a href='/x?a=1&amp;b=2' TITLE=t data-x=''>l</a><b>no attrs</b>"
  )
  kids <- html_children(body_of(doc))
  expect_identical(html_attr(kids, "href"), c("/x?a=1&b=2", NA))
  expect_identical(html_attr(kids, "href", default = ""), c("/x?a=1&b=2", ""))
  expect_identical(html_attr(kids, "title"), c("t", NA))
  expect_identical(html_attr(kids, "Title"), c("t", NA))
  expect_identical(html_attr(kids, "data-x"), c("", NA))
  text <- html_children(kids[1], elements_only = FALSE)
  expect_identical(html_attr(text, "href", default = "d"), "d")
})

test_that("the first of duplicate attributes wins", {
  doc <- html_parse("<p id=a id=b>")
  expect_identical(html_attr(html_children(body_of(doc)), "id"), "a")
})

test_that("foreign attributes match case-sensitively and by prefix", {
  doc <- html_parse("<svg viewBox='0 0 1 1'><a xlink:href=u /></svg>")
  svg <- html_children(body_of(doc))
  expect_identical(html_attr(svg, "viewBox"), "0 0 1 1")
  expect_identical(html_attr(svg, "viewbox"), NA_character_)
  a <- html_children(svg)
  expect_identical(html_attr(a, "xlink:href"), "u")
  expect_identical(html_attr(a, "href"), NA_character_)
  expect_identical(html_attrs(a), list(c(`xlink:href` = "u")))
})

test_that("html_attrs() keeps source order and empty values", {
  doc <- html_parse("<input type=checkbox checked data-z=1>")
  a <- html_attrs(html_children(body_of(doc)))
  expect_identical(a, list(c(type = "checkbox", checked = "", `data-z` = "1")))
  expect_identical(html_attrs(doc), list(setNames(character(), character())))
})

test_that("html_classes() splits on ASCII whitespace", {
  doc <- html_parse("<p class=' a  b\tc\n'>x</p><p>y</p>")
  p <- html_children(body_of(doc))
  expect_identical(html_classes(p), list(c("a", "b", "c"), character()))
  expect_identical(html_classes(p[NA_integer_]), list(NA_character_))
})

test_that("html_attr() validates its arguments", {
  doc <- html_parse("<p>")
  expect_error(html_attr(doc, c("a", "b")), class = "zuhtml_input_error")
  expect_error(html_attr(doc, NA_character_), class = "zuhtml_input_error")
  expect_error(html_attr(doc, "a", default = 1), class = "zuhtml_input_error")
  expect_error(html_attr(doc, "a", default = c("x", "y")),
               class = "zuhtml_input_error")
})

test_that("html_text() concatenates descendant text without separators", {
  doc <- html_parse(paste0(
    "<div>Hello <b>big</b>\n world<script>var x;</script>",
    "<!-- no --><template>no</template></div>"
  ))
  div <- html_children(body_of(doc))
  expect_identical(html_text(div), "Hello big\n worldvar x;")
  expect_identical(html_text(div, recursive = FALSE), "Hello \n world")
  expect_identical(html_text(html_children(div, FALSE)[5]), " no ")
  expect_identical(html_text(html_parse("<p>")), "")
})

test_that("html_text() keeps non-ASCII text", {
  doc <- html_parse("<p>café &mdash; 日本</p>")
  expect_identical(html_text(body_of(doc)), "café — 日本")
  expect_identical(Encoding(html_text(body_of(doc))), "UTF-8")
})
