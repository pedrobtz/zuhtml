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

test_that("limits and document info print with a comma decimal mark (#110)", {
  withr::local_options(OutDec = ",", warn = 2)
  out <- capture.output(print(html_limits()))
  expect_match(out, "16,777,216", fixed = TRUE, all = FALSE)
  out <- capture.output(print(html_info(html_parse("<p>x"))))
  expect_match(out, "input_bytes", fixed = TRUE, all = FALSE)
})

test_that("max_selector_length given at parse time bounds selectors (#83)", {
  doc <- html_parse("<p title=x>",
                    limits = html_limits(max_selector_length = 8))
  err <- expect_error(html_elements(doc, "p[title=x]"),
                      class = "zuhtml_limit_error")
  expect_identical(err$limit, "max_selector_length")
  expect_identical(err$maximum, 8)
  expect_length(html_elements(doc, "p"), 1L)
  # A document's nodes carry its limits.
  expect_error(html_matches(html_elements(doc, "p"), "p[title=x]"),
               class = "zuhtml_limit_error")
  long <- sprintf("p[title=\"%s\"]", strrep("x", 20000))
  expect_error(html_elements(html_parse("<p>"), long),
               class = "zuhtml_limit_error")
  roomy <- html_parse("<p>", limits = html_limits(max_selector_length = 1e5))
  expect_length(html_elements(roomy, long), 0L)
})

test_that("the package's own selectors ignore max_selector_length (#124)", {
  h <- paste0(
    "<html><head><title>T</title><base href='http://e.test/'>",
    "<meta name=description content=d>",
    "<script type='application/ld+json'>{\"a\":1}</script></head><body>",
    "<div itemscope><span itemprop=n>x</span></div>",
    "<form action=f><input name=q value=1></form>",
    "<ul><li>a<ul><li>b</ul></ul>",
    "<table><tr><th>h<tr><td><a href=x>l</a></table></body></html>"
  )
  doc <- html_parse(h, limits = html_limits(max_selector_length = 1))
  # The one-byte selector "*" reaches every element without a longer one.
  all <- html_elements(doc, "*")
  tab <- all[html_name(all) == "table"]
  ul <- all[html_name(all) == "ul"][1L]
  a <- all[html_name(all) == "a"]
  expect_identical(html_title(doc), "T")
  expect_identical(nrow(html_meta(doc)), 1L)
  expect_length(html_json_ld(doc), 1L)
  expect_length(html_microdata(doc), 1L)
  expect_identical(html_forms(doc)[[1]]$action, "http://e.test/f")
  expect_identical(html_links(doc, absolute = TRUE)$url, "http://e.test/x")
  expect_identical(html_url(a), "http://e.test/x")
  expect_match(html_markdown(doc), "[l](http://e.test/x)", fixed = TRUE)
  expect_length(html_tables(doc), 1L)
  expect_identical(nrow(html_table_cells(tab)), 2L)
  tree <- html_list(ul, mode = "tree")
  expect_identical(tree$items[[1]]$children[[1]]$items[[1]]$text, "b")
})

test_that("max_selector_length is straddled for the caller's selectors (#124)", {
  doc <- html_parse("<table><tr><td><p title=x>1</table>",
                    limits = html_limits(max_selector_length = 10))
  p <- html_elements(doc, "p")
  at <- "p[title=x]"
  over <- "p[title=xx]"
  expect_identical(nchar(c(at, over), type = "bytes"), c(10L, 11L))
  expect_length(html_elements(doc, at), 1L)
  expect_length(html_element(doc, at), 1L)
  expect_true(html_matches(p, at))
  expect_length(html_filter(p, at), 1L)
  expect_length(html_closest(p, at), 1L)
  for (f in list(html_elements, html_element, html_closest)) {
    expect_error(f(doc, over), class = "zuhtml_limit_error")
  }
  expect_error(html_matches(p, over), class = "zuhtml_limit_error")
  expect_error(html_filter(p, over), class = "zuhtml_limit_error")
  # html_tables()'s css is the caller's when given, the package's otherwise.
  short <- html_parse("<table><tr><td>1</table>",
                      limits = html_limits(max_selector_length = 4))
  expect_length(html_tables(short), 1L)
  expect_error(html_tables(short, css = "table"),
               class = "zuhtml_limit_error")
})
