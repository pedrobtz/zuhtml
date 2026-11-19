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
  if (timing_asserted()) expect_lt(elapsed, 2)
})

test_that("the adoption-agency pattern fails fast too", {
  elapsed <- system.time(
    err <- expect_error(html_parse(strrep("<a><b>", 2e4)),
                        class = "zuhtml_limit_error")
  )[["elapsed"]]
  expect_identical(err$limit, "max_depth")
  if (timing_asserted()) expect_lt(elapsed, 2)
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

test_that("16 MiB of sawtooth nesting parses under the default caps", {
  skip_on_cran()
  tooth <- paste0(strrep("<div>", 500), strrep("</div>", 500))
  html <- strrep(tooth, floor(16 * 1024^2 / nchar(tooth)))
  elapsed <- system.time(doc <- html_parse(html))[["elapsed"]]
  expect_s3_class(doc, "zuhtml_document")
  # The time bound is a CI exit criterion (roadmap Stage 2).
  if (timing_asserted()) expect_lt(elapsed, 3)
})

test_that("limit errors carry the zuhtml_error parent class", {
  err <- expect_error(
    html_parse("<p>", limits = html_limits(max_input = 1)),
    class = "zuhtml_error"
  )
  expect_s3_class(err, "error")
  expect_s3_class(err, "condition")
})

test_that("parse_peak_bytes is the smallest max_memory that parses (#130)", {
  # The oracle is a bisection on max_memory itself. The ledger counts
  # every block with its header and conversion checks the frozen arrays
  # with Gumbo's tree, and parse_peak_bytes records the larger of the two,
  # so the agreement is exact, with no tolerance.
  html <- strrep("<p>text", 200)
  parses <- function(m) {
    tryCatch({
      html_parse(html, limits = html_limits(max_memory = m))
      TRUE
    }, zuhtml_limit_error = function(e) FALSE)
  }
  lo <- 1024
  hi <- html_limits()$max_memory
  while (hi - lo > 1) {
    mid <- floor((lo + hi) / 2)
    if (parses(mid)) hi <- mid else lo <- mid
  }
  peak <- html_info(html_parse(html))$parse_peak_bytes
  expect_identical(peak, hi)
  # One byte less trips at exactly that peak.
  err <- expect_error(
    html_parse(html, limits = html_limits(max_memory = hi - 1)),
    class = "zuhtml_limit_error"
  )
  expect_identical(err$limit, "max_memory")
  expect_identical(err$observed, hi)
  expect_match(conditionMessage(err),
               sprintf("ran past max_memory = %.0f bytes at %.0f bytes",
                       hi - 1, hi), fixed = TRUE)
})

test_that("a max_memory breach reports where it tripped, not the need (#130)", {
  html <- strrep("<p>text", 200)
  err <- expect_error(
    html_parse(html, limits = html_limits(max_memory = 1e4)),
    class = "zuhtml_limit_error"
  )
  need <- html_info(html_parse(html))$parse_peak_bytes
  # The live bytes the refused allocation would have made: past the
  # limit, and a lower bound on what the parse needs.
  expect_gt(err$observed, 1e4)
  expect_lte(err$observed, need)
  expect_match(conditionMessage(err),
               sprintf("ran past max_memory = 10000 bytes at %.0f bytes",
                       err$observed), fixed = TRUE)
  expect_match(conditionMessage(err), "needs at least that", fixed = TRUE)
})

test_that("an injected allocation failure has no observed size", {
  lim <- html_limits()
  input <- zuhtml:::zuh_decode("<p>x", NULL, lim, NULL)
  err <- expect_error(
    zuhtml:::zuh_parse_bytes(input$bytes, "UTF-8", NULL, lim, fail_at = 1),
    class = "zuhtml_limit_error"
  )
  expect_identical(err$limit, "max_memory")
  expect_identical(err$observed, NA_real_)
})

test_that("every native status maps to a classed condition", {
  # zuh_r_status() objects, as the C entry points return them; the
  # conditions they stand for (strings over 2^31 - 1 bytes, documents over
  # 2^32 pool bytes) cannot be built in a test.
  doc <- html_parse("<p>x")
  n <- zuhtml:::zuh_nodes(doc)
  status <- function(name, observed) {
    structure(c(match(name, zuhtml:::zuh_status_names) - 1, observed),
              class = "zuhtml_status")
  }
  err <- expect_error(zuhtml:::zuh_checked(status("limit_string", 3e9), n),
                      class = "zuhtml_limit_error")
  expect_identical(err$limit, "string_length")
  expect_identical(err$maximum, 2147483647)
  expect_identical(err$observed, 3e9)
  err <- expect_error(zuhtml:::zuh_checked(status("limit_arena", 5e9), n),
                      class = "zuhtml_limit_error")
  expect_identical(err$limit, "arena")
  expect_identical(err$observed, 5e9)
  # limit_memory from a result builder cannot be reached from R (#126):
  # the builders' zuh_buf and table grid are R_alloc-backed, and R_alloc
  # long-jumps with R's own error instead of returning NULL, so the status
  # comes only from a size_t overflow in zuh_buf_put(), past what a 64-bit
  # build can allocate. ?zuhtml-conditions says R's error is what users
  # see; the mapping is checked here by a synthetic status.
  err <- expect_error(zuhtml:::zuh_checked(status("limit_memory", NA), n),
                      class = "zuhtml_limit_error")
  expect_identical(err$limit, "memory")
  for (s in c("internal", "limit_depth", "table_overlap")) {
    expect_error(zuhtml:::zuh_checked(status(s, NA), n),
                 class = "zuhtml_parse_error")
  }
  expect_error(zuhtml:::zuh_checked(structure(c(99, NA), class =
                                                "zuhtml_status"), n),
               class = "zuhtml_parse_error")
  # The table statuses keep their place after the parse ones, as in
  # src/zuh_status.h.
  expect_identical(zuhtml:::zuh_status_names[7:10],
                   c("limit_table", "table_overlap", "limit_arena",
                     "limit_string"))
})

test_that("the tree dump is a string, through the cleanup-safe path", {
  # Only the path that returns: the cleanup that frees the malloc'd dump
  # runs when R fails to allocate the string, which no test can force
  # (#86, #126; alloc-failure, gap #62 in .agents/assurance.md).
  doc <- html_parse("<p>x")
  out <- .Call(zuhtml:::C_zuh_doc_dump, doc$ptr)
  expect_type(out, "character")
  expect_match(out, "| <html>", fixed = TRUE)
})

test_that("an uncountable memory request is reported as such, not as 1.8e19 bytes (#130)", {
  # The ledger sets observed to SIZE_MAX when a request is too large to
  # count (src/zuh_memory.c); no input reaches that from R, so the wording
  # is tested on the helper the parser uses.
  huge <- zuh_memory_message(1e6, 2^64)
  expect_match(huge, "more native memory than can be counted", fixed = TRUE)
  expect_no_match(huge, "18446744073709551616", fixed = TRUE)
  expect_match(zuh_memory_message(1e6, 2e6), "at 2000000 bytes", fixed = TRUE)
})
