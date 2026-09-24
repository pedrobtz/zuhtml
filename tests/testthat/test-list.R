test_that("text mode gives one string per item, nested lists excluded", {
  doc <- html_parse("<ul><li>Apples<li>Tools<ul><li>Hammer<li>Saw</ul></ul>")
  expect_identical(html_list(html_element(doc, "ul")), c("Apples", "Tools"))
  # Text on both sides of a nested list stays apart.
  doc <- html_parse("<ul><li>before<ul><li>n</ul>after</ul>")
  expect_identical(html_list(html_element(doc, "ul")), "before\nafter")
})

test_that("empty and duplicate items are kept, formatting included", {
  doc <- html_parse("<ol><li>a <b>bold</b><li><li>a <b>bold</b></ol>")
  expect_identical(html_list(html_element(doc, "ol")),
                   c("a bold", "", "a bold"))
})

test_that("lists inside wrapper elements belong to their item", {
  doc <- html_parse(paste0(
    "<ul><li>One<div class=w><ul><li>1a<li>1b</ul></div>",
    "<li>Two<ol><li>2a<ul><li>2a-i</ul></ol></ul>"
  ))
  l <- html_element(doc, "ul")
  expect_identical(html_list(l), c("One", "Two"))
  tree <- html_list(l, mode = "tree")
  expect_s3_class(tree, "zuhtml_list")
  expect_identical(tree$type, "ul")
  expect_length(tree$items, 2L)
  one <- tree$items[[1L]]
  expect_identical(one$text, "One")
  expect_length(one$children, 1L)
  expect_identical(vapply(one$children[[1L]]$items, `[[`, "", "text"),
                   c("1a", "1b"))
  two <- tree$items[[2L]]
  expect_identical(two$children[[1L]]$type, "ol")
  inner <- two$children[[1L]]$items[[1L]]
  expect_identical(inner$text, "2a")
  # The grandchild list is 2a's child, not copied into Two's.
  expect_length(two$children, 1L)
  expect_identical(inner$children[[1L]]$items[[1L]]$text, "2a-i")
})

test_that("an item with two nested lists owns both, in order", {
  doc <- html_parse("<ul><li>x<ul><li>a</ul><ol><li>b</ol></ul>")
  tree <- html_list(html_element(doc, "ul"), "tree")
  kids <- tree$items[[1L]]$children
  expect_identical(vapply(kids, `[[`, "", "type"), c("ul", "ol"))
})

test_that("an empty list has no items", {
  doc <- html_parse("<ul></ul>")
  expect_identical(html_list(html_element(doc, "ul")), character())
  expect_length(html_list(html_element(doc, "ul"), "tree")$items, 0L)
})

test_that("the tree prints with indentation", {
  doc <- html_parse("<ol><li>a<ul><li>b</ul></ol>")
  out <- capture.output(print(html_list(html_element(doc, "ol"), "tree")))
  expect_identical(out, c("<zuhtml_list ol, 1 items>", "1. a", "  - b"))
})

test_that("html_list() needs exactly one list element", {
  doc <- html_parse("<ul><li>a</ul><ul><li>b</ul><p>x</p>")
  expect_error(html_list(doc), class = "zuhtml_input_error")
  expect_error(html_list(html_elements(doc, "ul")),
               class = "zuhtml_input_error")
  expect_error(html_list(html_element(doc, "p")), class = "zuhtml_input_error")
  expect_error(html_list(html_element(doc, "table")),
               class = "zuhtml_input_error")
  expect_error(html_list(html_element(doc, "ul"), mode = "data.frame"),
               class = "zuhtml_input_error")
})
