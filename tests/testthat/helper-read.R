# A file:// URL for a local path, on every platform.
file_url <- function(path) {
  p <- normalizePath(path, winslash = "/", mustWork = TRUE)
  paste0("file://", if (!startsWith(p, "/")) "/", p)
}
