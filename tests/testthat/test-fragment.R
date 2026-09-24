test_that("a fragment is parsed in its context", {
  f <- html_fragment("<tr><td>1<td>2", context = "tbody")
  expect_identical(html_type(f), "fragment")
  r <- html_root(f)
  expect_identical(html_type(r), "fragment")
  tr <- html_children(r)
  expect_identical(html_name(tr), "tr")
  expect_identical(html_text(html_children(tr)), c("1", "2"))
})

test_that("the same markup in a div context loses the table structure", {
  f <- html_fragment("<tr><td>1<td>2")
  expect_identical(html_type(html_children(html_root(f), FALSE)), "text")
  expect_identical(html_text(html_root(f)), "12")
})

test_that("a fragment has no implied html, head or body", {
  f <- html_fragment("<p>a</p>text")
  expect_identical(html_type(html_children(html_root(f), FALSE)),
                   c("element", "text"))
  expect_true(is.na(.Call(zuhtml:::C_zuh_doc_meta, f$ptr)$root))
})

test_that("context names are validated against the parser's tags", {
  expect_error(html_fragment("x", context = "no-such-element"),
               class = "zuhtml_input_error")
  expect_error(html_fragment("x", context = c("div", "p")),
               class = "zuhtml_input_error")
  expect_error(html_fragment("x", context = NA_character_),
               class = "zuhtml_input_error")
  expect_identical(html_type(html_fragment("x", context = "TD")), "fragment")
})

test_that("html_fragment() passes named options on to the parser", {
  f <- html_fragment(as.raw(c(0x3c, 0x62, 0x3e, 0xe9)), encoding = "latin1",
                     comments = FALSE, base_url = "https://x.org/")
  expect_identical(html_text(html_root(f)), "é")
  expect_identical(html_info(f)$base_url, "https://x.org/")
  expect_error(html_fragment("x", "div", "extra"),
               class = "zuhtml_input_error")
  expect_error(html_fragment("x", bogus = 1), class = "zuhtml_input_error")
  expect_error(html_fragment(strrep("<b>", 20),
                             limits = html_limits(max_depth = 5)),
               class = "zuhtml_limit_error")
})

test_that("a fragment's quirks mode is defined (patch 0006)", {
  # Gumbo left it uninitialized for fragments; valgrind caught the read.
  f <- html_fragment("<p>a<table><tr><td>b</table>")
  expect_identical(html_info(f)$quirks_mode, "no-quirks")
  # In no-quirks mode <table> closes an open <p>.
  expect_identical(html_name(html_children(html_root(f))), c("p", "table"))
})

test_that("fragments print their context", {
  out <- capture.output(print(html_fragment("<td>x", context = "tr")))
  expect_match(out, "fragment: in <tr>", all = FALSE, fixed = TRUE)
})
