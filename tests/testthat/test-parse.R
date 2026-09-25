test_that("a string parses into a document", {
  doc <- html_parse("<p>Hello <b>world</b>")
  expect_s3_class(doc, "zuhtml_document")
  expect_identical(doc$encoding, "UTF-8")
})

test_that("empty input is a valid document", {
  expect_s3_class(html_parse(""), "zuhtml_document")
  expect_s3_class(html_parse(raw()), "zuhtml_document")
})

test_that("x must be one non-missing string or a raw vector", {
  bad <- list(NA_character_, c("<p>", "<p>"), character(), 1, list("<p>"),
              NULL)
  for (x in bad) {
    err <- expect_error(html_parse(x), class = "zuhtml_input_error")
    expect_identical(err$arg, "x")
  }
})

test_that("a string is never treated as a file or URL", {
  path <- withr::local_tempfile(fileext = ".html")
  writeLines("<p>file contents", path)
  doc <- html_parse(path)
  meta <- .Call(zuhtml:::C_zuh_doc_meta, doc$ptr)
  expect_identical(meta$input_bytes, as.double(nchar(path, "bytes")))
})

test_that("strings marked as bytes are rejected", {
  x <- "caf\xe9"
  Encoding(x) <- "bytes"
  expect_error(html_parse(x), class = "zuhtml_input_error")
})

test_that("latin1 strings are converted to UTF-8", {
  x <- "caf\xe9"
  Encoding(x) <- "latin1"
  doc <- html_parse(x)
  meta <- .Call(zuhtml:::C_zuh_doc_meta, doc$ptr)
  expect_identical(meta$input_bytes, 5)
})

test_that("encoding= is refused for strings unless it says UTF-8", {
  expect_error(html_parse("<p>", encoding = "latin1"),
               class = "zuhtml_input_error")
  expect_s3_class(html_parse("<p>", encoding = "utf-8"), "zuhtml_document")
})

test_that("raw input defaults to UTF-8 and must be valid", {
  doc <- html_parse(charToRaw("<p>café"))
  expect_identical(doc$encoding, "UTF-8")
  expect_error(html_parse(as.raw(c(0x3c, 0x70, 0x3e, 0xe9))),
               class = "zuhtml_encoding_error")
})

test_that("raw input is decoded with an explicit encoding", {
  doc <- html_parse(as.raw(c(0x3c, 0x70, 0x3e, 0xe9)), encoding = "latin1")
  expect_identical(doc$encoding, "latin1")
  meta <- .Call(zuhtml:::C_zuh_doc_meta, doc$ptr)
  expect_identical(meta$input_bytes, 5)
})

test_that("a UTF-8 byte-order mark is removed", {
  bytes <- c(as.raw(c(0xef, 0xbb, 0xbf)), charToRaw("<p>x"))
  doc <- html_parse(bytes)
  meta <- .Call(zuhtml:::C_zuh_doc_meta, doc$ptr)
  expect_identical(meta$input_bytes, 4)
  expect_identical(doc$encoding, "UTF-8")
})

test_that("a UTF-16 byte-order mark selects the decoder and is removed", {
  le <- c(as.raw(c(0xff, 0xfe)), as.raw(rbind(charToRaw("<p>x"), as.raw(0))))
  doc <- html_parse(le)
  expect_identical(doc$encoding, "UTF-16LE")
  expect_identical(.Call(zuhtml:::C_zuh_doc_meta, doc$ptr)$input_bytes, 4)

  be <- c(as.raw(c(0xfe, 0xff)), as.raw(rbind(as.raw(0), charToRaw("<p>x"))))
  doc <- html_parse(be)
  expect_identical(doc$encoding, "UTF-16BE")
  expect_identical(.Call(zuhtml:::C_zuh_doc_meta, doc$ptr)$input_bytes, 4)
})

test_that("an encoding contradicting the byte-order mark is an error", {
  bytes <- c(as.raw(c(0xef, 0xbb, 0xbf)), charToRaw("<p>x"))
  err <- expect_error(html_parse(bytes, encoding = "UTF-16LE"),
                      class = "zuhtml_encoding_error")
  expect_identical(err$encoding, "UTF-16LE")
  expect_s3_class(html_parse(bytes, encoding = "utf8"), "zuhtml_document")
})

test_that("unknown encodings and invalid sequences are encoding errors", {
  expect_error(html_parse(charToRaw("<p>"), encoding = "no-such-encoding"),
               class = "zuhtml_encoding_error")
  # A lone high surrogate is invalid UTF-16; 0x80 is not ASCII; a trailing
  # odd byte is a truncated UTF-16 code unit.
  bad <- list(
    list(as.raw(c(0x3c, 0x00, 0x00, 0xd8, 0x3e, 0x00)), "UTF-16LE"),
    list(as.raw(c(0x3c, 0x80, 0x3e)), "ASCII"),
    list(as.raw(c(0x3c, 0x00, 0x3e, 0x00, 0x3e)), "UTF-16LE")
  )
  for (b in bad) {
    err <- expect_error(html_parse(b[[1L]], encoding = b[[2L]]),
                        class = "zuhtml_encoding_error")
    expect_identical(err$encoding, b[[2L]])
  }
})

test_that("UTF-16 is decoded strictly and without iconv", {
  u16 <- function(cps, big = FALSE) {
    hi <- cps %/% 256L
    lo <- cps %% 256L
    as.raw(if (big) rbind(hi, lo) else rbind(lo, hi))
  }
  # A surrogate pair: U+1F600.
  doc <- html_parse(u16(c(0x3c, 0x70, 0x3e, 0xD83D, 0xDE00)),
                    encoding = "UTF-16LE")
  expect_identical(.Call(zuhtml:::C_zuh_doc_meta, doc$ptr)$input_bytes, 7)
  doc <- html_parse(u16(c(0x3c, 0x70, 0x3e, 0xe9), big = TRUE),
                    encoding = "UTF-16BE")
  expect_identical(.Call(zuhtml:::C_zuh_doc_meta, doc$ptr)$input_bytes, 5)
  # Plain "UTF-16" without a BOM is big-endian.
  doc <- html_parse(u16(c(0x3c, 0x70, 0x3e), big = TRUE), encoding = "UTF-16")
  expect_identical(.Call(zuhtml:::C_zuh_doc_meta, doc$ptr)$input_bytes, 3)
  # A lone low surrogate, and a high surrogate at the end.
  expect_error(html_parse(u16(c(0x3c, 0xDE00)), encoding = "UTF-16LE"),
               class = "zuhtml_encoding_error")
  expect_error(html_parse(u16(c(0x3c, 0xD83D)), encoding = "UTF-16LE"),
               class = "zuhtml_encoding_error")
})

test_that("NUL is rejected before and after decoding", {
  expect_error(html_parse(as.raw(c(0x3c, 0x00, 0x3e))),
               class = "zuhtml_input_error")
  nul16 <- as.raw(c(0x3c, 0x00, 0x00, 0x00))
  expect_error(html_parse(nul16, encoding = "UTF-16LE"),
               class = "zuhtml_input_error")
})

test_that("comments and base_url are validated", {
  expect_error(html_parse("<p>", comments = NA), class = "zuhtml_input_error")
  expect_error(html_parse("<p>", base_url = c("a", "b")),
               class = "zuhtml_input_error")
  doc <- html_parse("<p>", base_url = "https://example.org/")
  expect_identical(doc$base_url, "https://example.org/")
})

test_that("html_read() reads one local file as raw bytes", {
  path <- withr::local_tempfile(fileext = ".html")
  writeBin(c(as.raw(c(0xef, 0xbb, 0xbf)), charToRaw("<p>café")), path)
  doc <- html_read(path)
  expect_s3_class(doc, "zuhtml_document")
  expect_identical(.Call(zuhtml:::C_zuh_doc_meta, doc$ptr)$input_bytes, 8)
})

test_that("html_read() passes arguments on to html_parse()", {
  path <- withr::local_tempfile(fileext = ".html")
  writeBin(as.raw(c(0x3c, 0x70, 0x3e, 0xe9)), path)
  doc <- html_read(path, encoding = "latin1", base_url = "https://x.org/")
  expect_identical(doc$encoding, "latin1")
  expect_identical(doc$base_url, "https://x.org/")
})

test_that("html_read() rejects missing files, directories and bad input", {
  expect_error(html_read(file.path(tempdir(), "no-such-file.html")),
               class = "zuhtml_input_error")
  expect_error(html_read(tempdir()), class = "zuhtml_input_error")
  expect_error(html_read(""), class = "zuhtml_input_error")
  expect_error(html_read(1L), class = "zuhtml_input_error")
  expect_error(html_read(c("a", "b")), class = "zuhtml_input_error")
  expect_error(html_read(NA_character_), class = "zuhtml_input_error")
})

test_that("html_read() refuses a file too large before reading it", {
  path <- withr::local_tempfile(fileext = ".html")
  writeLines(strrep("x", 100), path)
  err <- expect_error(html_read(path, limits = html_limits(max_input = 10)),
                      class = "zuhtml_limit_error")
  expect_identical(err$limit, "max_input")
})

test_that("a document prints a short summary", {
  out <- capture.output(print(html_parse("<!DOCTYPE html><p></div>")))
  expect_match(out[[1L]], "zuhtml_document")
  expect_match(out, "problems: 1", all = FALSE)
})

test_that("a document restored from a saved session is a pointer error", {
  doc <- html_parse("<p>x")
  restored <- unserialize(serialize(doc, NULL))
  expect_error(html_problems(restored), class = "zuhtml_pointer_error")
  expect_match(capture.output(print(restored)), "no longer available",
               all = FALSE)
})

test_that("functions taking a document reject other objects", {
  expect_error(html_problems("<p>"), class = "zuhtml_input_error")
  expect_error(html_problems(list(ptr = NULL)), class = "zuhtml_input_error")
})
