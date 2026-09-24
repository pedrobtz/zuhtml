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
