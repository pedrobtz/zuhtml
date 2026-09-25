test_that("html_read() reads a path, a file:// URL and a connection alike", {
  path <- withr::local_tempfile(fileext = ".html")
  html <- paste0("<ul>", strrep("<li><a href='x.html'>item</a>", 20000),
                 "</ul>")
  writeLines(html, path)
  # Several 64 KiB reads.
  expect_gt(file.size(path), 3 * 65536)
  ref <- html_serialize(html_parse(readBin(path, "raw", file.size(path))))
  for (doc in list(html_read(path), html_read(file_url(path)),
                   html_read(file(path)))) {
    expect_identical(html_serialize(doc), ref)
    expect_length(html_elements(doc, "li"), 20000L)
  }
})

test_that("a URL is recognised by scheme and becomes the base URL", {
  path <- withr::local_tempfile(fileext = ".html")
  writeLines("<a href='sub/page.html'>x</a>", path)
  url <- file_url(path)
  doc <- html_read(url)
  expect_identical(doc$base_url, url)
  expect_identical(html_url(html_element(doc, "a")),
                   paste0(dirname(url), "/sub/page.html"))
  upper <- sub("^file", "FILE", url)
  expect_identical(html_read(upper)$base_url, url)
  # An explicit base_url wins, and NULL keeps none.
  expect_identical(html_read(url, base_url = "https://x.test/")$base_url,
                   "https://x.test/")
  expect_null(html_read(url, base_url = NULL)$base_url)
  # A path is not a URL, and gets no base URL.
  expect_null(html_read(path)$base_url)
})

test_that("a path that only contains :// is a path", {
  # Windows forbids ":" in a directory name.
  skip_on_os("windows")
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "http:"))
  path <- file.path(dir, "http:", "x.html")
  writeBin(charToRaw("<p>y"), path)
  expect_identical(html_text(html_element(html_read(path), "p")), "y")
})

test_that("an unopened connection is opened in binary mode and closed", {
  path <- withr::local_tempfile(fileext = ".html")
  writeBin(charToRaw("<p>x"), path)
  before <- nrow(showConnections())
  con <- file(path)
  expect_identical(html_text(html_element(html_read(con), "p")), "x")
  expect_identical(nrow(showConnections()), before)
})

test_that("an open binary connection is read from its position and kept", {
  path <- withr::local_tempfile(fileext = ".html")
  writeBin(charToRaw("junk<p>x"), path)
  con <- file(path, "rb")
  withr::defer(close(con))
  expect_identical(readBin(con, "raw", 4L), charToRaw("junk"))
  doc <- html_read(con)
  expect_identical(html_text(html_element(doc, "p")), "x")
  expect_identical(html_text_clean(doc), "x")
  expect_true(isOpen(con))
})

test_that("compressed files and raw connections are read", {
  path <- withr::local_tempfile(fileext = ".html.gz")
  con <- gzfile(path, "wb")
  writeLines("<meta charset=latin1><p>caf", con)
  close(con)
  expect_identical(html_info(html_read(gzfile(path)))$encoding,
                   "windows-1252")
  # rawConnection() returns an open connection, which stays the caller's.
  rc <- rawConnection(charToRaw("<b>raw</b>"))
  withr::defer(close(rc))
  doc <- html_read(rc)
  expect_identical(html_text(html_element(doc, "b")), "raw")
  empty <- rawConnection(raw())
  withr::defer(close(empty))
  expect_identical(html_info(html_read(empty))$nodes, 4)
})

test_that("text-mode and closed connections are refused", {
  path <- withr::local_tempfile(fileext = ".html")
  writeLines("<p>x", path)
  con <- file(path, "r")
  withr::defer(close(con))
  expect_error(html_read(con), class = "zuhtml_input_error")
  # A file never blocks, so a non-blocking file handle reads whole.
  nb <- file(path, "rb", blocking = FALSE)
  withr::defer(close(nb))
  expect_identical(html_text_clean(html_read(nb)), "x")
  closed <- file(path, "rb")
  close(closed)
  expect_error(html_read(closed))
})

test_that("unreadable URLs are input errors", {
  missing <- file.path(withr::local_tempdir(), "none.html")
  url <- paste0(file_url(dirname(missing)), "/none.html")
  expect_error(html_read(url), class = "zuhtml_input_error")
})

test_that("reading stops at four times max_input", {
  lim <- html_limits(max_input = 1000)
  # A connection has no size to check first: the read stops early.
  big <- rawConnection(charToRaw(strrep("<p>x", 2000)))
  err <- expect_error(html_read(big, limits = lim),
                      class = "zuhtml_limit_error")
  expect_identical(err$limit, "max_input")
  expect_gt(err$observed, 4000)
  close(big)
  ok <- rawConnection(charToRaw(strrep("<p>x", 200)))
  withr::defer(close(ok))
  expect_s3_class(html_read(ok, limits = lim), "zuhtml_document")
  # A file's size is checked before reading.
  path <- withr::local_tempfile(fileext = ".html")
  writeLines(strrep("x", 5000), path)
  err <- expect_error(html_read(file_url(path), limits = lim),
                      class = "zuhtml_limit_error")
  expect_identical(err$limit, "max_input")
})
