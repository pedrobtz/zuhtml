# The safety seam: every limit trips its own classed error, and a failed
# parse returns nothing. Leak-freedom is checked by tools/run-sanitizers,
# which runs the same fault injection under LeakSanitizer.

test_that("max_input trips on decoded size", {
  err <- expect_error(
    html_parse(strrep("x", 101), limits = html_limits(max_input = 100)),
    class = "zuhtml_limit_error"
  )
  expect_identical(err$limit, "max_input")
  expect_identical(err$maximum, 100)
  expect_identical(err$observed, 101)
  expect_s3_class(html_parse(strrep("x", 100),
                             limits = html_limits(max_input = 100)),
                  "zuhtml_document")
})

test_that("max_memory trips inside the parser", {
  err <- expect_error(
    html_parse(strrep("<p>text", 1000), limits = html_limits(max_memory = 1e4)),
    class = "zuhtml_limit_error"
  )
  expect_identical(err$limit, "max_memory")
  expect_identical(err$maximum, 1e4)
})

test_that("max_depth trips during parsing, not afterwards", {
  err <- expect_error(
    html_parse(strrep("<div>", 20), limits = html_limits(max_depth = 10)),
    class = "zuhtml_limit_error"
  )
  expect_identical(err$limit, "max_depth")
  expect_identical(err$maximum, 10)
  # html, body and the divs are all open elements.
  expect_s3_class(
    html_parse(strrep("<div>", 8), limits = html_limits(max_depth = 10)),
    "zuhtml_document"
  )
})

test_that("100,000 nested elements fail fast instead of taking 16 s", {
  elapsed <- system.time(
    err <- expect_error(html_parse(strrep("<div>", 1e5)),
                        class = "zuhtml_limit_error")
  )[["elapsed"]]
  expect_identical(err$limit, "max_depth")
  expect_lt(elapsed, 2)
})

test_that("the adoption-agency pattern fails fast too", {
  elapsed <- system.time(
    err <- expect_error(html_parse(strrep("<a><b>", 2e4)),
                        class = "zuhtml_limit_error")
  )[["elapsed"]]
  expect_identical(err$limit, "max_depth")
  expect_lt(elapsed, 2)
})

test_that("an allocation failure at any point is a clean max_memory error", {
  html <- "<!DOCTYPE html><table><tr><td>a<b>b</table><p id=x id=y>&amp;"
  lim <- html_limits()
  input <- zuhtml:::zuh_decode(html, NULL, lim, NULL)
  # Fail allocation k for k = 1, 2, ... until the parse makes fewer than k
  # allocations and succeeds. Every earlier k must be a max_memory error.
  k <- 1
  repeat {
    res <- tryCatch(
      zuhtml:::zuh_parse_bytes(input$bytes, "UTF-8", NULL, lim, fail_at = k),
      zuhtml_limit_error = function(e) e
    )
    if (inherits(res, "zuhtml_document")) break
    expect_identical(res$limit, "max_memory")
    k <- k + 1
    if (k > 1e4) fail("the parse never completed")
  }
  expect_gt(k, 10)
})

test_that("16 MiB of sawtooth nesting parses under the caps", {
  skip_on_cran()
  tooth <- paste0(strrep("<div>", 500), strrep("</div>", 500))
  html <- strrep(tooth, floor(16 * 1024^2 / nchar(tooth)))
  # About 1.5M elements, past the default max_nodes; see the roadmap's
  # Stage 3 status for why that default is not raised yet.
  lim <- html_limits(max_nodes = 2e6)
  elapsed <- system.time(doc <- html_parse(html, limits = lim))[["elapsed"]]
  expect_s3_class(doc, "zuhtml_document")
  # The time bound is a CI exit criterion (roadmap Stage 2). Not asserted
  # elsewhere: an emulated or instrumented build is several times slower.
  if (identical(Sys.getenv("CI"), "true") &&
      !identical(Sys.getenv("R_COVR"), "true")) {
    expect_lt(elapsed, 3)
  }
})

test_that("limit errors carry the zuhtml_error parent class", {
  err <- expect_error(
    html_parse("<p>", limits = html_limits(max_input = 1)),
    class = "zuhtml_error"
  )
  expect_s3_class(err, "error")
  expect_s3_class(err, "condition")
})
