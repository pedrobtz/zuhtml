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
local_c_ctype <- function(env = parent.frame()) {
  old <- Sys.getlocale("LC_CTYPE")
  set <- suppressWarnings(Sys.setlocale("LC_CTYPE", "C"))
  if (!nzchar(set)) testthat::skip("LC_CTYPE cannot be set to C")
  withr::defer(Sys.setlocale("LC_CTYPE", old), envir = env)
  # The #92 rule applies only where zuh_ascii_locale() sees an ASCII codeset;
  # Windows reports none, so its C locale keeps the old behaviour (#122).
  if (!zuh_ascii_locale()) {
    testthat::skip("LC_CTYPE = C is not an ASCII codeset zuhtml recognises here")
  }
}

# The decoded UTF-8 bytes of raw input, or NULL for an encoding error.
decoded <- function(x, encoding = NULL) {
  tryCatch(
    zuh_decode(x, encoding, html_limits(), call = NULL)$bytes,
    zuhtml_encoding_error = function(e) NULL
  )
}
