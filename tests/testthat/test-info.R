test_that("zuhtml_info() reports the pinned Gumbo and its patches", {
  info <- zuhtml_info()
  expect_s3_class(info, "zuhtml_info")
  expect_identical(info$gumbo_version, "0.14.0")
  expect_identical(
    info$gumbo_patches,
    c("0001-max-tree-depth", "0002-no-stdio", "0003-modification-notices")
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
