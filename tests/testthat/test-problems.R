test_that("html_problems() lists repaired errors with positions", {
  doc <- html_parse("<!DOCTYPE html><p>One</div><p id=a id=b>Two")
  p <- html_problems(doc)
  expect_s3_class(p, "data.frame")
  expect_named(p, c("stage", "code", "line", "column", "byte_offset"))
  expect_identical(p$code, c("unexpected-end-tag", "duplicate-attr"))
  expect_identical(p$stage, c("parser", "tokenizer"))
  expect_identical(p$line, c(1L, 1L))
  expect_identical(p$byte_offset[[1L]], 21L)
  expect_false(attr(p, "truncated"))
})

test_that("a clean document has a typed zero-row problems frame", {
  p <- html_problems(html_parse("<!DOCTYPE html><title>t</title><p>x"))
  expect_identical(nrow(p), 0L)
  expect_type(p$code, "character")
  expect_type(p$line, "integer")
  expect_false(attr(p, "truncated"))
})

test_that("problems are truncated at max_errors, and parsing continues", {
  html <- paste0("<!DOCTYPE html>", strrep("</x>", 20))
  p <- html_problems(html_parse(html, limits = html_limits(max_errors = 5)))
  expect_identical(nrow(p), 5L)
  expect_true(attr(p, "truncated"))

  p <- html_problems(html_parse(html, limits = html_limits(max_errors = 0)))
  expect_identical(nrow(p), 0L)
  expect_true(attr(p, "truncated"))
})

test_that("line and column follow newlines", {
  p <- html_problems(html_parse("<!DOCTYPE html>\n<p>\n  </div>"))
  expect_identical(p$line, 3L)
  expect_identical(p$column, 3L)
  expect_identical(p$byte_offset, 22L)
})

test_that("every code is a package-owned kebab-case name", {
  html <- paste0(
    "<p id=a id=b>&notanentity;&#0;</p></div><!-- a --!>",
    "<br/><div/><table>x</table><",
    "<!DOCTYPE html>"
  )
  p <- html_problems(html_parse(html))
  expect_gt(nrow(p), 3L)
  expect_true(all(grepl("^[a-z0-9]+(-[a-z0-9]+)*$", p$code)))
  expect_true(all(p$stage %in% c("tokenizer", "parser")))
})
