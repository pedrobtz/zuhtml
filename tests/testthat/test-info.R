test_that("zuhtml_info() reports the pinned Gumbo and its patches", {
  info <- zuhtml_info()
  expect_s3_class(info, "zuhtml_info")
  expect_identical(info$gumbo_version, "0.14.0")
  expect_identical(
    info$gumbo_patches,
    c("0001-max-tree-depth", "0002-no-stdio", "0003-modification-notices",
      "0004-selectedcontent-descendant", "0005-selectedcontent-end-tag",
      "0006-document-quirks-init")
  )
  expect_identical(
    info$zuhtml_version,
    as.character(utils::packageVersion("zuhtml"))
  )
})

test_that("the bundled parser is linked and builds the expected tree", {
  expect_true(zuhtml_info()$parser_ok)
})

test_that("the parse-time depth limit (patch 0001) is in effect", {
  expect_true(zuhtml_info()$depth_limit_ok)
})

test_that("zuhtml_info() prints every field and returns invisibly", {
  info <- zuhtml_info()
  out <- capture.output(res <- withVisible(print(info)))
  expect_false(res$visible)
  expect_match(out, "Gumbo:\\s+0\\.14\\.0", all = FALSE)
  expect_match(out, "Parser:\\s+ok", all = FALSE)
  expect_match(out, "Depth limit:\\s+ok", all = FALSE)
})

test_that("html_info() describes a document", {
  doc <- html_parse("<!DOCTYPE html><p id=a>x", base_url = "https://e.org/")
  i <- html_info(doc)
  expect_s3_class(i, "zuhtml_doc_info")
  expect_identical(i$type, "document")
  expect_identical(i$context, NA_character_)
  expect_identical(i$nodes, 7)
  expect_identical(i$attributes, 1)
  expect_identical(i$encoding, "UTF-8")
  expect_identical(i$base_url, "https://e.org/")
  expect_identical(i$quirks_mode, "no-quirks")
  expect_identical(i$problems, 0)
  expect_false(i$problems_truncated)
  expect_gt(i$native_bytes, 0)
  expect_identical(html_info(html_root(doc))$nodes, 7)
  expect_match(capture.output(print(i)), "quirks_mode", all = FALSE)
})
