# Long loops over a frozen document poll for interrupts; setTimeLimit()
# is enforced at those polls, which is how these tests stand in for a
# user pressing Ctrl-C. After an interrupt the document is intact and
# nothing native has leaked (tools/run-sanitizers and the valgrind job
# check the latter).

test_that("a long selector search can be interrupted", {
  skip_on_cran()
  doc <- big_doc()
  roots <- rep(html_root(doc), 200)
  expect_true(interrupted(
    html_elements(roots, "div div div div div div div div span")
  ))
  # The document still works afterwards.
  expect_length(html_elements(doc, "span"), 50000L)
})

test_that("long text extraction and serialization can be interrupted", {
  skip_on_cran()
  doc <- big_doc()
  divs <- html_elements(doc, "div")
  many <- divs[rep(seq_along(divs), 40)]
  expect_true(interrupted(html_text_clean(many)))
  expect_true(interrupted(html_serialize(rep(html_root(doc), 2000))))
  expect_identical(html_text_clean(divs[1]), "x\ny")
})
