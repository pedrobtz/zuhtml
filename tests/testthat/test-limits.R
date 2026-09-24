test_that("html_limits() has the documented defaults", {
  lim <- html_limits()
  expect_s3_class(lim, "zuhtml_limits")
  expect_identical(
    names(lim),
    c("max_input", "max_memory", "max_depth", "max_nodes", "max_errors",
      "max_table_cells", "max_selector_length")
  )
  expect_identical(lim$max_input, 16 * 1024^2)
  expect_identical(lim$max_memory, 512 * 1024^2)
  expect_identical(lim$max_depth, 512)
  expect_identical(lim$max_nodes, 4e6)
  expect_identical(lim$max_errors, 100)
  expect_identical(lim$max_table_cells, 1e6)
  expect_identical(lim$max_selector_length, 16 * 1024)
})

test_that("limits are stored as doubles whatever numeric type was given", {
  lim <- html_limits(max_depth = 10L)
  expect_identical(lim$max_depth, 10)
})

test_that("invalid limit values are rejected with an input error", {
  bad <- list(-1, NA_real_, Inf, NaN, 1.5, "10", c(1, 2), numeric(), TRUE)
  for (v in bad) {
    err <- expect_error(html_limits(max_depth = v),
                        class = "zuhtml_input_error")
    expect_identical(err$arg, "max_depth")
  }
})

test_that("each limit has its lower bound", {
  expect_error(html_limits(max_input = 0), class = "zuhtml_input_error")
  expect_error(html_limits(max_depth = 0), class = "zuhtml_input_error")
  expect_no_error(html_limits(max_errors = 0))
})

test_that("values too large to represent are rejected", {
  expect_error(html_limits(max_input = 2^31), class = "zuhtml_input_error")
  expect_error(html_limits(max_nodes = .Machine$integer.max),
               class = "zuhtml_input_error")
  expect_error(html_limits(max_memory = 2^60), class = "zuhtml_input_error")
})

test_that("html_parse() rejects a limits object not made by html_limits()", {
  expect_error(html_parse("<p>", limits = list(max_depth = 5)),
               class = "zuhtml_input_error")
  lim <- html_limits()
  lim$max_depth <- -1
  expect_error(html_parse("<p>", limits = lim), class = "zuhtml_input_error")
})

test_that("limits print one line each", {
  out <- capture.output(print(html_limits()))
  expect_length(out, 8L)
  expect_match(out[[1L]], "zuhtml_limits")
})
