test_that("subsetting keeps the class and the owner", {
  doc <- html_parse("<p>1</p><p>2</p><p>3</p>")
  p <- html_children(body_of(doc))
  expect_s3_class(p[2:3], "zuhtml_nodeset")
  expect_identical(html_text(p[2:3]), c("2", "3"))
  expect_identical(html_text(p[[3]]), "3")
  expect_identical(html_text(rev(p)), c("3", "2", "1"))
  expect_identical(html_document(p[1]), doc)
  expect_length(p[0], 0L)
})

test_that("out-of-range subsetting gives missing nodes", {
  doc <- html_parse("<p>1</p>")
  p <- html_children(body_of(doc))
  expect_identical(html_text(p[c(1, 5)]), c("1", NA))
})

test_that("c() combines nodes of one document and keeps duplicates", {
  doc <- html_parse("<p>1</p><p>2</p>")
  p <- html_children(body_of(doc))
  both <- c(p[2], p[1], p[2])
  expect_s3_class(both, "zuhtml_nodeset")
  expect_identical(html_text(both), c("2", "1", "2"))
})

test_that("c() refuses nodes from different documents", {
  a <- html_children(body_of(html_parse("<p>a")))
  b <- html_children(body_of(html_parse("<p>b")))
  expect_error(c(a, b), class = "zuhtml_input_error")
  expect_error(c(a, 1L), class = "zuhtml_input_error")
})

test_that("a nodeset keeps its document alive through garbage collection", {
  p <- local({
    doc <- html_parse("<p id=kept>alive</p>")
    html_children(body_of(doc))
  })
  gc()
  gc()
  expect_identical(html_text(p), "alive")
  expect_identical(html_attr(p, "id"), "kept")
})

test_that("finalization is idempotent and leaves a pointer error", {
  doc <- html_parse("<p>x</p>")
  p <- html_children(body_of(doc))
  .Call(zuhtml:::C_zuh_doc_release, doc$ptr)
  .Call(zuhtml:::C_zuh_doc_release, doc$ptr)
  expect_error(html_text(p), class = "zuhtml_pointer_error")
  expect_error(html_root(doc), class = "zuhtml_pointer_error")
  expect_error(html_info(doc), class = "zuhtml_pointer_error")
  gc()
})

test_that("a nodeset restored from a saved session is a pointer error", {
  doc <- html_parse("<p>x</p>")
  p <- unserialize(serialize(html_children(body_of(doc)), NULL))
  expect_error(html_name(p), class = "zuhtml_pointer_error")
})

test_that("a node ID outside its document is a pointer error", {
  doc <- html_parse("<p>x</p>")
  bogus <- zuhtml:::new_nodeset(1e6L, doc)
  expect_error(html_name(bogus), class = "zuhtml_pointer_error")
  expect_error(html_name(zuhtml:::new_nodeset(-1L, doc)),
               class = "zuhtml_pointer_error")
})

test_that("printing is bounded", {
  doc <- html_parse(strrep("<p class=c>paragraph text</p>", 50))
  p <- html_children(body_of(doc))
  out <- capture.output(print(p))
  expect_length(out, 12L)
  expect_match(out[[1L]], "zuhtml_nodeset[50]", fixed = TRUE)
  expect_match(out[[12L]], "and 40 more")
  expect_length(capture.output(print(p, n = 3)), 5L)
})

test_that("format() describes each kind of node", {
  doc <- html_parse(paste0(
    "<!DOCTYPE html><p id=a>", strrep("long text ", 20), "</p><!--c-->"
  ))
  nodes <- c(html_children(doc, elements_only = FALSE),
             html_children(body_of(doc), elements_only = FALSE))
  f <- format(c(nodes, html_children(nodes[3], FALSE), nodes[NA_integer_]))
  expect_identical(f[1:2], c("<!DOCTYPE html>", "<html>"))
  expect_identical(f[3:4], c("<p id=\"a\">", "<!--c-->"))
  expect_match(f[5], "^\"long text .*\\.\\.\\.\"$")
  expect_lte(nchar(f[5]), 60L)
  expect_identical(f[6], "<missing>")
  expect_identical(format(html_parent(nodes[2])), "<document>")
})

test_that("as.integer() exposes the document-local IDs", {
  doc <- html_parse("<p>")
  expect_identical(as.integer(html_root(doc)), 2L - 1L)
})

test_that("lapply() over a nodeset passes single nodes", {
  doc <- html_parse("<ul><li>a</ul><ul><li>b<li>c</ul>")
  lists <- html_elements(doc, "ul")
  expect_identical(lapply(lists, html_list), list("a", c("b", "c")))
  each <- as.list(lists)
  expect_length(each, 2L)
  expect_s3_class(each[[1L]], "zuhtml_nodeset")
  expect_identical(html_document(each[[2L]]), doc)
  expect_identical(vapply(lists, function(l) length(html_children(l)),
                          integer(1)), c(1L, 2L))
  expect_identical(as.list(lists[0]), list())
})

test_that("rep() and unique() keep the class and the owner", {
  doc <- html_parse("<p>1</p><p>2</p>")
  p <- html_elements(doc, "p")
  r <- rep(p, 2)
  expect_s3_class(r, "zuhtml_nodeset")
  expect_identical(html_text(r), c("1", "2", "1", "2"))
  expect_identical(html_text(rep(p, each = 2)), c("1", "1", "2", "2"))
  expect_identical(html_text(unique(r)), c("1", "2"))
  expect_identical(html_document(unique(r)), doc)
})
