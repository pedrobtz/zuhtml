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

test_that("windows-1255 and windows-1258 decode the last byte too (#89)", {
  # libiconv holds back a base character in case a combining mark follows,
  # and iconv() never flushes it. A byte at the end of the input must
  # decode as it does in the middle.
  for (enc in c("windows-1255", "windows-1258", "cp1258")) {
    lost <- integer()
    for (b in 1:255) {
      x <- c(charToRaw(strrep("abc", 3)), as.raw(b))
      whole <- decoded(c(x, charToRaw("z")), enc)
      end <- decoded(x, enc)
      if (!identical(is.null(whole), is.null(end)) ||
          (!is.null(whole) && !identical(c(end, charToRaw("z")), whole))) {
        lost <- c(lost, b)
      }
    }
    expect_identical(lost, integer(), label = enc)
  }
  x <- c(charToRaw("<meta charset=windows-1258><p>"), charToRaw("Hello"))
  expect_identical(html_text(html_element(html_parse(x), "p")), "Hello")
  # A base letter and a combining mark stay two code points, as in the
  # WHATWG indexes: windows-1258 0xEC is U+0301 and 0xD2 is U+0309;
  # windows-1255 0xE0 is U+05D0 and 0xC4 is U+05B4.
  expect_identical(
    utf8ToInt(rawToChar(decoded(as.raw(c(0x61, 0xec, 0x6f, 0xd2)),
                                "windows-1258"))),
    c(0x61L, 0x301L, 0x6fL, 0x309L)
  )
  expect_identical(
    utf8ToInt(rawToChar(decoded(as.raw(c(0xe0, 0xc4)), "windows-1255"))),
    c(0x5d0L, 0x5b4L)
  )
  # A byte the index leaves unmapped is invalid, not dropped.
  err <- expect_error(html_parse(as.raw(c(0x3c, 0xd9)),
                                 encoding = "windows-1255"),
                      class = "zuhtml_encoding_error")
  expect_identical(err$encoding, "windows-1255")
})

test_that("unmarked non-ASCII strings are UTF-8 in a C locale (#92)", {
  # As readLines() returns a UTF-8 file's lines in a C locale: unmarked.
  x <- "<p title=t>caf\xc3\xa9</p>"
  l1 <- "caf\xe9"
  Encoding(l1) <- "latin1"
  local_c_ctype()
  doc <- html_parse(x)
  expect_identical(html_text(html_element(doc, "p")), "café")
  expect_identical(html_info(doc)$input_bytes, 20)
  # A latin1-marked string is still converted.
  expect_identical(html_info(html_parse(l1))$input_bytes, 5)
  # Invalid UTF-8 is still refused.
  expect_error(html_parse("caf\xe9"), class = "zuhtml_encoding_error")
})

test_that("an argument marked as bytes is an input error (#84)", {
  # Only a string with a non-ASCII byte can be marked.
  enc <- "latin\xb91"
  Encoding(enc) <- "bytes"
  expect_error(html_parse(as.raw(c(0x3c, 0xe9)), encoding = enc),
               class = "zuhtml_input_error")
  ctx <- "d\xc3\xa9v"
  Encoding(ctx) <- "bytes"
  expect_error(html_fragment("<p>", context = ctx),
               class = "zuhtml_input_error")
})

test_that("encodings that are not ASCII-compatible are refused by name (#94)", {
  le16 <- as.raw(rbind(charToRaw("<p>hi"), as.raw(0)))
  known <- iconv_names()
  for (enc in intersect(c("UCS-2LE", "UTF-32LE", "UCS-4LE"), known)) {
    err <- expect_error(html_parse(le16, encoding = enc),
                        class = "zuhtml_encoding_error")
    expect_identical(err$encoding, enc)
    expect_match(conditionMessage(err), enc, fixed = TRUE)
  }
  skip_without_iconv("UTF-8-MAC")
  doc <- html_parse(charToRaw("<p>café"), encoding = "UTF-8-MAC")
  expect_identical(html_text(html_element(doc, "p")), "café")
})

test_that("every iconv() name decodes ASCII markup or is an encoding error", {
  skip_on_cran()
  known <- iconv_names()
  skip_if(length(known) == 0L, "iconvlist() is not available")
  bad <- character()
  for (enc in known) {
    res <- tryCatch(
      html_text(html_element(html_parse(charToRaw("<p>hi"), encoding = enc),
                             "p")),
      zuhtml_encoding_error = function(e) "encoding error",
      error = function(e) conditionMessage(e)
    )
    if (!identical(res, "hi") && !identical(res, "encoding error")) {
      bad <- c(bad, enc)
    }
  }
  expect_identical(bad, character())
})

test_that("one byte-order mark is removed, whatever the encoding (#95)", {
  bom8 <- as.raw(c(0xef, 0xbb, 0xbf))
  utf8 <- function(n) c(rep(bom8, n), charToRaw("A"))
  le <- function(n) c(rep(as.raw(c(0xff, 0xfe)), n), as.raw(c(0x41, 0)))
  be <- function(n) c(rep(as.raw(c(0xfe, 0xff)), n), as.raw(c(0, 0x41)))
  for (n in 0:2) {
    want <- c(rep(bom8, max(n - 1L, 0L)), charToRaw("A"))
    expect_identical(decoded(utf8(n)), want)
    expect_identical(decoded(le(n), if (n == 0L) "UTF-16LE"), want)
    expect_identical(decoded(be(n), if (n == 0L) "UTF-16BE"), want)
  }
  # A string is text already: one leading U+FEFF goes, a second stays.
  expect_identical(html_info(html_parse("\ufeff\ufeffA"))$input_bytes, 4)
})

test_that("the raw-input bound is reported as four times max_input (#85)", {
  skip_without_iconv("ISO-2022-JP")
  # Escape sequences of a stateful encoding decode to nothing, so raw input
  # can be far longer than its decoding; the raw bound is a bound of its
  # own, and its message says so.
  x <- charToRaw(paste0(strrep("\033(B", 20), "ab"))
  lim <- html_limits(max_input = 10)
  err <- expect_error(html_parse(x, encoding = "ISO-2022-JP", limits = lim),
                      class = "zuhtml_limit_error")
  expect_identical(err$limit, "max_input")
  expect_identical(err$observed, 62)
  expect_match(conditionMessage(err), "four times max_input", fixed = TRUE)
  # Within the raw bound, the decoded size is what counts.
  doc <- html_parse(x[-(1:30)], encoding = "ISO-2022-JP", limits = lim)
  expect_identical(html_info(doc)$input_bytes, 2)
})

test_that("the raw-input bound admits exactly four times max_input (#132)", {
  skip_without_iconv("ISO-2022-JP")
  # Each escape is three bytes that decode to nothing, so both inputs
  # decode to well within max_input; only the raw bound separates them.
  lim <- html_limits(max_input = 10)
  at <- charToRaw(paste0(strrep("\033(B", 12), "abcd"))
  over <- charToRaw(paste0(strrep("\033(B", 13), "ab"))
  expect_length(at, 40L)
  expect_length(over, 41L)
  doc <- html_parse(at, encoding = "ISO-2022-JP", limits = lim)
  expect_identical(html_info(doc)$input_bytes, 4)
  err <- expect_error(html_parse(over, encoding = "ISO-2022-JP", limits = lim),
                      class = "zuhtml_limit_error")
  expect_identical(err$limit, "max_input")
  expect_identical(err$observed, 41)
})
