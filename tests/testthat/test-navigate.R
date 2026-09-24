test_that("a document stands for its document node", {
  doc <- html_parse("<!DOCTYPE html><p>x")
  expect_identical(html_type(doc), "document")
  kids <- html_children(doc)
  expect_identical(html_name(kids), "html")
  expect_identical(html_type(html_children(doc, elements_only = FALSE)),
                   c("doctype", "element"))
})

test_that("html_root() is the <html> element of a document", {
  doc <- html_parse("<p>x")
  r <- html_root(doc)
  expect_s3_class(r, "zuhtml_nodeset")
  expect_length(r, 1L)
  expect_identical(html_name(r), "html")
  expect_identical(html_type(html_parent(r)), "document")
  expect_identical(html_name(html_root(html_children(r))), "html")
})

test_that("html_document() returns the owner", {
  doc <- html_parse("<p>x")
  expect_identical(html_document(html_root(doc)), doc)
  expect_identical(html_document(doc), doc)
})

test_that("children are a set in document order", {
  doc <- html_parse("<div><p>a<b>b</b></p><p>c</p></div>")
  div <- html_children(body_of(doc))
  ps <- html_children(div)
  expect_identical(html_name(ps), c("p", "p"))
  # Children of nested contexts interleave in document order, once each.
  both <- c(ps[1], div, ps[1])
  expect_identical(html_name(html_children(both)), c("p", "b", "p"))
  expect_identical(html_type(html_children(ps[1], elements_only = FALSE)),
                   c("text", "element"))
})

test_that("parent and siblings are aligned and keep missing nodes", {
  doc <- html_parse("<ul><li>1</li>text<li>2</li></ul>")
  li <- html_children(html_children(body_of(doc)))
  expect_length(li, 2L)
  expect_identical(html_name(html_parent(li)), c("ul", "ul"))
  nxt <- html_next_sibling(li)
  expect_identical(html_name(nxt), c("li", NA))
  expect_identical(html_type(html_next_sibling(li, elements_only = FALSE)),
                   c("text", NA))
  prv <- html_previous_sibling(li)
  expect_identical(html_name(prv), c(NA, "li"))
  expect_identical(html_type(html_parent(doc)), NA_character_)
})

test_that("missing nodes propagate through aligned operations", {
  doc <- html_parse("<p>a</p>")
  p <- html_children(body_of(doc))
  x <- p[c(1, NA, 1)]
  expect_length(x, 3L)
  expect_identical(is.na(unclass(html_parent(x))), c(FALSE, TRUE, FALSE))
  expect_identical(html_name(x), c("p", NA, "p"))
  expect_identical(html_text(x), c("a", NA, "a"))
  expect_identical(html_attr(x, "id", default = "none"), c("none", NA, "none"))
  expect_length(html_children(x), 0L)
})

test_that("zero-length input gives zero-length output", {
  doc <- html_parse("<p>")
  none <- html_children(html_children(body_of(doc)))
  expect_length(none, 0L)
  expect_length(html_parent(none), 0L)
  expect_identical(html_name(none), character())
  expect_identical(html_attrs(none), list())
})

test_that("ancestors are a set in document order, without the document", {
  doc <- html_parse("<div><p><b>x</b></p></div>")
  b <- html_children(html_children(html_children(body_of(doc))))
  expect_identical(html_name(html_ancestors(b)),
                   c("html", "body", "div", "p"))
  both <- c(b, html_parent(b))
  expect_identical(html_name(html_ancestors(both)),
                   c("html", "body", "div", "p"))
})

test_that("template contents are children, reached explicitly", {
  doc <- html_parse("<template><p>inert</p></template>")
  tmpl <- html_children(html_children(html_root(doc))[1])
  expect_identical(html_name(tmpl), "template")
  expect_identical(html_name(html_children(tmpl)), "p")
  expect_identical(html_name(html_template_content(tmpl)), "p")
  expect_length(html_template_content(html_root(doc)), 0L)
  expect_identical(html_text(tmpl), "")
  expect_identical(html_text(html_root(doc)), "")
})

test_that("navigation rejects things that are not nodes", {
  expect_error(html_children("<p>"), class = "zuhtml_input_error")
  expect_error(html_children(html_parse("<p>"), elements_only = NA),
               class = "zuhtml_input_error")
})
