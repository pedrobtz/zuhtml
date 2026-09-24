test_that("a <meta charset> decides the encoding of raw input", {
  skip_without_iconv("CP1252", "CP932")
  bytes <- c(charToRaw("<meta charset=\"ISO-8859-1\"><p>caf"), as.raw(0xe9),
             charToRaw(" "), as.raw(0x93), charToRaw("q"), as.raw(0x94))
  doc <- html_parse(bytes)
  # iso-8859-1 is windows-1252 in the Encoding Standard: 0x93 is a quote.
  expect_identical(html_text(html_element(doc, "p")),
                   "café “q”")
  info <- html_info(doc)
  expect_identical(info$encoding, "windows-1252")
  expect_identical(info$encoding_source, "meta")

  sjis <- c(charToRaw("<meta charset=shift_jis><p>"),
            as.raw(c(0x93, 0xfa, 0x96, 0x7b)))
  doc <- html_parse(sjis)
  expect_identical(html_text(html_element(doc, "p")), "日本")
  expect_identical(html_info(doc)$encoding, "Shift_JIS")
})

test_that("each source of the encoding is reported", {
  skip_without_iconv("latin1", "ISO-8859-2")
  src <- function(...) html_info(html_parse(...))$encoding_source
  expect_identical(src("<p>x"), "string")
  expect_identical(src(charToRaw("<p>x")), "default")
  expect_identical(src(charToRaw("<p>x"), encoding = "latin1"), "argument")
  expect_identical(src(c(as.raw(c(0xef, 0xbb, 0xbf)), charToRaw("<p>x"))),
                   "bom")
  expect_identical(src(charToRaw("<meta charset=utf-8><p>x")), "meta")
  expect_identical(html_info(html_parse(charToRaw("<p>x")))$encoding,
                   "UTF-8")
  frag <- html_fragment(charToRaw("<meta charset=latin2><b>x</b>"))
  expect_identical(html_info(frag)$encoding, "ISO-8859-2")
})

test_that("the prescan reads every declaration form", {
  enc <- sniffed
  expect_identical(enc("<meta charset=koi8-r>"), "KOI8-R")
  expect_identical(enc("<META CHARSET=' Windows-1251 '>"), "windows-1251")
  expect_identical(enc("<meta/charset=latin2>"), "ISO-8859-2")
  expect_identical(
    enc(paste0("<meta http-equiv=\"Content-Type\" ",
               "content=\"text/html; charset=windows-1250\">")),
    "windows-1250"
  )
  expect_identical(
    enc("<meta content='text/html;charset=\"gbk\"' http-equiv=content-type>"),
    "GBK"
  )
  # content without the http-equiv pragma is not a declaration.
  expect_identical(enc("<meta content='text/html; charset=gbk'>"), "UTF-8")
  # A label that names no encoding is skipped; the next one counts.
  expect_identical(enc("<meta charset=bogus><meta charset=latin2>"),
                   "ISO-8859-2")
  # The first charset attribute of an element wins.
  expect_identical(enc("<meta charset=latin2 charset=gbk>"), "ISO-8859-2")
  # A UTF-16 label means UTF-8, and x-user-defined means windows-1252.
  expect_identical(enc("<meta charset=utf-16le>"), "UTF-8")
  expect_identical(enc("<meta charset=x-user-defined>"), "windows-1252")
  expect_identical(enc("<meta charset=gb2312>"), "GBK")
  expect_identical(enc("<meta charset=us-ascii>"), "windows-1252")
})

test_that("the prescan skips comments and tags, not scripts, as browsers do", {
  enc <- sniffed
  expect_identical(enc("<!-- <meta charset=gbk> --><meta charset=koi8-r>"),
                   "KOI8-R")
  expect_identical(enc("<!--><meta charset=koi8-r>"), "KOI8-R")
  expect_identical(enc("<p title='<meta charset=gbk>'><meta charset=koi8-r>"),
                   "KOI8-R")
  expect_identical(enc("<?pi <meta charset=gbk>?><meta charset=koi8-r>"),
                   "KOI8-R")
  # The prescan does not know script: a <meta> in script text counts.
  expect_identical(
    enc("<script>'<meta charset=koi8-r>'</script><meta charset=gbk>"),
    "KOI8-R"
  )
})

test_that("only the first 1024 bytes are scanned", {
  enc <- sniffed
  pad <- function(k) strrep(" ", k)
  expect_identical(enc(paste0(pad(1000), "<meta charset=koi8-r>")), "KOI8-R")
  expect_identical(enc(paste0(pad(1004), "<meta charset=koi8-r>")), "UTF-8")
  expect_identical(enc(paste0("<!--", pad(1100), "--><meta charset=gbk>")),
                   "UTF-8")
})

test_that("a byte-order mark or the argument beats the declaration", {
  meta <- charToRaw("<meta charset=gbk><p>é")
  doc <- html_parse(c(as.raw(c(0xef, 0xbb, 0xbf)), meta))
  expect_identical(html_info(doc)$encoding, "UTF-8")
  expect_identical(html_text(html_element(doc, "p")), "é")
  doc <- html_parse(meta, encoding = "UTF-8")
  expect_identical(html_info(doc)$encoding_source, "argument")
  expect_identical(html_text(html_element(doc, "p")), "é")
})

test_that("a declared encoding that fails is an encoding error", {
  # Not valid Shift_JIS.
  err <- expect_error(
    html_parse(c(charToRaw("<meta charset=shift_jis><p>"), as.raw(0xa0))),
    class = "zuhtml_encoding_error"
  )
  expect_identical(err$encoding, "Shift_JIS")
  expect_match(conditionMessage(err), "pass that as `encoding`", fixed = TRUE)
  # A UTF-8 file with a stale declaration reads with `encoding`.
  stale <- c(charToRaw("<meta charset=gb2312><p>"),
             charToRaw("\u20ac"))
  expect_error(html_parse(stale), class = "zuhtml_encoding_error")
  expect_identical(
    html_text(html_element(html_parse(stale, encoding = "UTF-8"), "p")),
    "\u20ac"
  )
  err <- expect_error(html_parse(charToRaw("<meta charset=iso-2022-kr>")),
                      class = "zuhtml_encoding_error")
  expect_identical(err$encoding, "replacement")
  # An encoding this iconv() does not know.
  local_mocked_bindings(zuh_iconv_name = function(enc) "NO-SUCH-ENCODING")
  err <- expect_error(html_parse(charToRaw("<meta charset=koi8-r><p>x")),
                      class = "zuhtml_encoding_error")
  expect_identical(err$encoding, "KOI8-R")
})

test_that("html_read() sniffs files", {
  skip_without_iconv("CP1252")
  path <- withr::local_tempfile(fileext = ".html")
  writeBin(c(charToRaw("<meta charset=windows-1252><p>"), as.raw(0x80)),
           path)
  doc <- html_read(path)
  expect_identical(html_text(html_element(doc, "p")), "€")
  expect_identical(html_info(doc)$encoding_source, "meta")
})

test_that("every label maps to an encoding iconv() can use here", {
  # Windows' iconv lacks a few, and minimal builds lack code pages; there
  # they are encoding errors.
  skip_on_os("windows")
  skip_without_iconv("CP866", "CP1252", "KOI8-R")
  encs <- setdiff(unique(zuh_enc_labels),
                  c("replacement", "UTF-16BE", "UTF-16LE", "x-user-defined"))
  for (e in encs) {
    name <- zuh_iconv_name(e)
    expect_false(is.na(iconv("a", name, "UTF-8")), info = e)
  }
})
