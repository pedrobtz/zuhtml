test_that("RFC 3986 section 5.4.1: normal examples", {
  base <- "http://a/b/c/d;p?q"
  # reference, expected result
  cases <- matrix(c(
    "g:h", "g:h",
    "g", "http://a/b/c/g",
    "./g", "http://a/b/c/g",
    "g/", "http://a/b/c/g/",
    "/g", "http://a/g",
    "//g", "http://g",
    "?y", "http://a/b/c/d;p?y",
    "g?y", "http://a/b/c/g?y",
    "#s", "http://a/b/c/d;p?q#s",
    "g#s", "http://a/b/c/g#s",
    "g?y#s", "http://a/b/c/g?y#s",
    ";x", "http://a/b/c/;x",
    "g;x", "http://a/b/c/g;x",
    "g;x?y#s", "http://a/b/c/g;x?y#s",
    "", "http://a/b/c/d;p?q",
    ".", "http://a/b/c/",
    "./", "http://a/b/c/",
    "..", "http://a/b/",
    "../", "http://a/b/",
    "../g", "http://a/b/g",
    "../..", "http://a/",
    "../../", "http://a/",
    "../../g", "http://a/g"
  ), ncol = 2, byrow = TRUE)
  expect_identical(zuhtml:::zuh_resolve(cases[, 1], base), cases[, 2])
})

test_that("RFC 3986 section 5.4.2: abnormal examples", {
  base <- "http://a/b/c/d;p?q"
  # reference, expected result
  cases <- matrix(c(
    "../../../g", "http://a/g",
    "../../../../g", "http://a/g",
    "/./g", "http://a/g",
    "/../g", "http://a/g",
    "g.", "http://a/b/c/g.",
    ".g", "http://a/b/c/.g",
    "g..", "http://a/b/c/g..",
    "..g", "http://a/b/c/..g",
    "./../g", "http://a/b/g",
    "./g/.", "http://a/b/c/g/",
    "g/./h", "http://a/b/c/g/h",
    "g/../h", "http://a/b/c/h",
    "g;x=1/./y", "http://a/b/c/g;x=1/y",
    "g;x=1/../y", "http://a/b/c/y",
    "g?y/./x", "http://a/b/c/g?y/./x",
    "g?y/../x", "http://a/b/c/g?y/../x",
    "g#s/./x", "http://a/b/c/g#s/./x",
    "g#s/../x", "http://a/b/c/g#s/../x",
    "http:g", "http:g"
  ), ncol = 2, byrow = TRUE)
  expect_identical(zuhtml:::zuh_resolve(cases[, 1], base), cases[, 2])
})

test_that("html_url() resolves against the parse-time base URL", {
  doc <- html_parse(
    "<a href='x/y?z#f'>1</a><a>2</a><a href='mailto:m@x.org'>3</a>",
    base_url = "https://example.org/dir/page.html"
  )
  a <- html_elements(doc, "a")
  expect_identical(
    html_url(a),
    c("https://example.org/dir/x/y?z#f", NA, "mailto:m@x.org")
  )
  expect_identical(html_url(a[c(1, NA)]),
                   c("https://example.org/dir/x/y?z#f", NA))
})

test_that("<base href> resolves against the parse-time URL and wins", {
  doc <- html_parse(
    "<base href='/other/'><base href='/ignored/'><a href='p'>x</a>",
    base_url = "https://example.org/dir/page.html"
  )
  expect_identical(html_url(html_elements(doc, "a")),
                   "https://example.org/other/p")
  # An explicit base_url overrides the document's.
  expect_identical(html_url(html_elements(doc, "a"), base_url = "http://q/r/"),
                   "http://q/r/p")
})

test_that("relative references without an absolute base are NA", {
  doc <- html_parse("<a href='rel'>r</a><a href='https://x.org/abs'>a</a>")
  expect_identical(html_url(html_elements(doc, "a")),
                   c(NA, "https://x.org/abs"))
  doc <- html_parse("<a href='rel'>r</a>", base_url = "not/absolute")
  expect_identical(html_url(html_elements(doc, "a")), NA_character_)
  # A relative <base> with no document URL falls back to nothing.
  doc <- html_parse("<base href='/b/'><a href='rel'>r</a>")
  expect_identical(html_url(html_elements(doc, "a")), NA_character_)
})

test_that("malformed references are NA; surrounding whitespace is ignored", {
  doc <- html_parse(paste0(
    "<a href='  p  '>1</a><a href='a b'>2</a><a href='1bad:x'>3</a>",
    "<a href='\tq\n'>4</a>"
  ), base_url = "http://h/d/")
  expect_identical(html_url(html_elements(doc, "a")),
                   c("http://h/d/p", NA, NA, "http://h/d/q"))
})

test_that("html_url() reads other attributes", {
  doc <- html_parse("<img src='i.png'><img>", base_url = "http://h/d/x")
  expect_identical(html_url(html_elements(doc, "img"), attr = "src"),
                   c("http://h/d/i.png", NA))
  expect_error(html_url(doc, attr = c("a", "b")), class = "zuhtml_input_error")
  expect_error(html_url(doc, base_url = 1), class = "zuhtml_input_error")
})

test_that("html_links() lists anchors and areas with href", {
  doc <- html_parse(paste0(
    "<nav><a href='/'>Home</a> <a href='about.html'>About <b>us</b></a>",
    "<a name=x>no href</a><a href='#top'>Top</a><a href='/'>Home</a>",
    "<map><area href='m.html' alt=m></map></nav>"
  ), base_url = "https://example.org/site/")
  l <- html_links(doc)
  expect_identical(names(l), c("text", "href", "url"))
  expect_identical(l$href, c("/", "about.html", "#top", "/", "m.html"))
  expect_identical(l$url, l$href)
  expect_identical(l$text, c("Home", "About us", "Top", "Home", ""))
  l <- html_links(doc, absolute = TRUE)
  expect_identical(l$url, c(
    "https://example.org/", "https://example.org/site/about.html",
    "https://example.org/site/#top", "https://example.org/",
    "https://example.org/site/m.html"
  ))
})

test_that("html_links() includes matching context nodes once", {
  doc <- html_parse("<a href='a'>a</a><div><a href='b'>b</a></div>")
  ctx <- c(html_elements(doc, "a")[1], html_elements(doc, "div"))
  expect_identical(html_links(ctx)$href, c("a", "b"))
})

test_that("no links give a typed zero-row frame", {
  l <- html_links(html_parse("<p>none</p>"))
  expect_identical(dim(l), c(0L, 3L))
  expect_type(l$url, "character")
})
