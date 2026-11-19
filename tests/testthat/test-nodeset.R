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

test_that("[<- and [[<- take nodes of the same document", {
  doc <- html_parse("<p>a</p><p>b</p><p>c</p>")
  p <- html_elements(doc, "p")
  x <- p
  x[1] <- p[3]
  expect_s3_class(x, "zuhtml_nodeset")
  expect_identical(html_text(x), c("c", "b", "c"))
  x[[2]] <- p[[1]]
  expect_identical(html_text(x), c("c", "a", "c"))
  x[2] <- NA
  expect_identical(html_text(x), c("c", NA, "c"))
  x[[3]] <- NA_integer_
  expect_identical(html_text(x), c("c", NA, NA))
  x[5] <- p[2]
  expect_identical(html_text(x), c("c", NA, NA, NA, "b"))
  expect_identical(html_document(x), doc)
})

test_that("[<- and [[<- refuse nodes of another document", {
  a <- html_elements(html_parse("<p>a</p><p>b</p>"), "p")
  b <- html_elements(html_parse("<div><i>x</i><b>y</b></div>"), "i, b")
  expect_error(a[1] <- b[2], class = "zuhtml_input_error")
  expect_error(a[[2]] <- b[[1]], class = "zuhtml_input_error")
  expect_identical(html_text(a), c("a", "b"))
})

test_that("[<- and [[<- refuse values that are not nodes", {
  a <- html_elements(html_parse("<p>a</p><p>b</p>"), "p")
  expect_error(a[1] <- 1L, class = "zuhtml_input_error")
  expect_error(a[[1]] <- 3L, class = "zuhtml_input_error")
  expect_error(a[1] <- "x", class = "zuhtml_input_error")
  expect_error(a[1] <- html_document(a), class = "zuhtml_input_error")
  expect_error(a[[1]] <- a, class = "zuhtml_input_error")
  expect_identical(html_text(a), c("a", "b"))
})

test_that("arithmetic and comparison on a nodeset are refused", {
  p <- html_elements(html_parse("<p>a</p><p>b</p>"), "p")
  expect_error(p + 1L, class = "zuhtml_input_error")
  expect_error(1L - p, class = "zuhtml_input_error")
  expect_error(p < p, class = "zuhtml_input_error")
  expect_error(p >= p, class = "zuhtml_input_error")
  expect_error(-p, class = "zuhtml_input_error")
  expect_error(!p, class = "zuhtml_input_error")
  expect_error(p & p, class = "zuhtml_input_error")
  expect_error(abs(p), class = "zuhtml_input_error")
  expect_identical(as.integer(p) + 1L, as.vector(unclass(p)) + 1L)
})

test_that("== and != compare nodes of one document by identity (#151)", {
  doc <- html_parse("<div><p>a</p><p>a</p></div><div><p>a</p></div>")
  p <- html_elements(doc, "p")
  parent <- html_parent(p)
  expect_identical(parent == parent[1], c(TRUE, TRUE, FALSE))
  expect_identical(parent != parent[3], c(TRUE, TRUE, FALSE))
  # Equal text and markup, different nodes.
  expect_identical(p[1] == p[2], FALSE)
  expect_identical(p == rev(p), c(FALSE, TRUE, FALSE))
  # A missing node compares as NA.
  expect_identical(p[c(1, 4)] == p[1], c(TRUE, NA))
  expect_identical(p[0] == p, logical())
})

test_that("== and != refuse nodes of another document and numbers (#151)", {
  a <- html_elements(html_parse("<p>a</p>"), "p")
  b <- html_elements(html_parse("<p>a</p>"), "p")
  expect_identical(as.integer(a), as.integer(b))
  expect_error(a == b, class = "zuhtml_input_error")
  expect_error(a != b, class = "zuhtml_input_error")
  expect_error(a == as.integer(a), class = "zuhtml_input_error")
  expect_error(as.integer(a) != a, class = "zuhtml_input_error")
  expect_error(a == NA, class = "zuhtml_input_error")
})

test_that("Summary functions, mean() and diff() on a nodeset are refused (#128)", {
  p <- html_elements(html_parse("<p>a</p><p>b</p><p>c</p>"), "p")
  for (f in list(sum, max, min, range, prod, any, all)) {
    expect_error(f(p), class = "zuhtml_input_error")
  }
  expect_error(max(p, 1L), class = "zuhtml_input_error")
  expect_error(mean(p), class = "zuhtml_input_error")
  expect_error(median(p), class = "zuhtml_input_error")
  expect_error(diff(p), class = "zuhtml_input_error")
})

test_that("match() and %in% compare nodes, not their markup (#128)", {
  doc <- html_parse("<p>a</p><p>a</p><p>b</p>")
  p <- html_elements(doc, "p")
  expect_identical(match(p, p[2:3]), c(NA, 1L, 2L))
  expect_identical(p %in% p[1], c(TRUE, FALSE, FALSE))
  expect_identical(html_text(setdiff(p, p[1])), c("a", "b"))
  expect_identical(match(p[c(1, 4)], p[c(4, 1)]), c(2L, 1L))
})

test_that("match() and %in% find no node of another document (#128)", {
  a <- html_elements(html_parse("<p>a</p><p>b</p>"), "p")
  b <- html_elements(html_parse("<p>a</p><p>b</p>"), "p")
  expect_identical(as.integer(a), as.integer(b))
  expect_identical(match(a, b), c(NA_integer_, NA_integer_))
  expect_identical(a %in% b, c(FALSE, FALSE))
  expect_identical(setdiff(a, b), a)
})

test_that("xtfrm(), order() and sort() follow document order (#128)", {
  doc <- html_parse("<p>1</p><p>2</p><p>3</p>")
  p <- html_elements(doc, "p")
  x <- p[c(3, 1, 2)]
  expect_identical(xtfrm(x), as.integer(x))
  expect_identical(order(x), c(2L, 3L, 1L))
  expect_identical(sort(x), p)
  expect_identical(html_text(sort(x, decreasing = TRUE)), c("3", "2", "1"))
  expect_identical(html_document(sort(x)), doc)
})

test_that("rank() needs ordering, which stays refused (#151)", {
  p <- html_elements(html_parse("<p>1</p><p>2</p>"), "p")
  expect_error(rank(p), class = "zuhtml_input_error")
  expect_identical(rank(as.integer(p[2:1])), c(2, 1))
})

test_that("assigning NA with a number into a nodeset is refused (#128)", {
  p <- html_elements(html_parse("<p>a</p><p>b</p>"), "p")
  expect_error(p[1:2] <- c(NA, 1L), class = "zuhtml_input_error")
  expect_error(p[[1]] <- c(NA, 1L), class = "zuhtml_input_error")
  expect_identical(html_text(p), c("a", "b"))
})

test_that("length<- keeps the class and pads with missing nodes", {
  doc <- html_parse("<p>a</p><p>b</p>")
  p <- html_elements(doc, "p")
  length(p) <- 3
  expect_s3_class(p, "zuhtml_nodeset")
  expect_identical(html_text(p), c("a", "b", NA))
  length(p) <- 1
  expect_identical(html_text(p), "a")
  expect_identical(html_document(p), doc)
})

test_that("print() shows a newline in text as one escaped newline", {
  doc <- html_parse("<p>line1\nline2</p>")
  x <- html_children(html_element(doc, "p"), FALSE)
  expect_identical(format(x), "\"line1\\nline2\"")
  expect_identical(capture.output(print(x))[[2L]], "[1] \"line1\\nline2\"")
})

test_that("print() checks n before printing anything", {
  p <- html_elements(html_parse("<p>a</p><p>b</p>"), "p")
  for (bad in list(1.5, NA, c(1, 2), -1, "2", NULL)) {
    expect_error(capture.output(print(p, n = bad)),
                 class = "zuhtml_input_error")
  }
  expect_length(capture.output(print(p, n = 0)), 2L)
  expect_length(capture.output(print(p, n = Inf)), 3L)
  expect_length(capture.output(print(p, n = 1L)), 3L)
})
