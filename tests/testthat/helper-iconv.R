# Whether this platform's iconv() converts from `enc`. Some builds, such as
# sanitizer containers, ship a minimal iconv without code pages; there a
# declared encoding is an encoding error, as documented.
iconv_has <- function(enc) {
  tryCatch(!is.na(iconv("a", enc, "UTF-8")), error = function(e) FALSE,
           warning = function(w) FALSE)
}

skip_without_iconv <- function(...) {
  for (e in c(...)) {
    if (!iconv_has(e)) testthat::skip(paste("iconv() lacks", e))
  }
}

# The encoding the prescan finds in a string's bytes; "UTF-8" if none.
sniffed <- function(s) {
  r <- zuh_prescan(charToRaw(s))
  if (is.null(r)) "UTF-8" else r$encoding
}

# The encoding names this platform's iconv() lists; empty where it cannot.
iconv_names <- function() {
  tryCatch(iconvlist(), error = function(e) character())
}

# Switch LC_CTYPE to the C locale until the calling test ends, or skip
# where the platform will not.
#
# The skip is on the platform, never on zuh_ascii_locale(), the code under
# test (#129): Windows reports no codeset for its C locale, so the #92 rule
# does not apply there yet (#122). Everywhere else the detector must see
# the C locale's ASCII, and a broken detector fails the calling test.
local_c_ctype <- function(env = parent.frame()) {
  testthat::skip_on_os("windows") # #122
  old <- Sys.getlocale("LC_CTYPE")
  set <- suppressWarnings(Sys.setlocale("LC_CTYPE", "C"))
  if (!nzchar(set)) testthat::skip("LC_CTYPE cannot be set to C")
  withr::defer(Sys.setlocale("LC_CTYPE", old), envir = env)
  testthat::expect_true(zuh_ascii_locale(),
                        label = "zuh_ascii_locale() in LC_CTYPE = C")
}

# The decoded UTF-8 bytes of raw input, or NULL for an encoding error.
decoded <- function(x, encoding = NULL) {
  tryCatch(
    zuh_decode(x, encoding, html_limits(), call = NULL)$bytes,
    zuhtml_encoding_error = function(e) NULL
  )
}
