.libPaths(c(Sys.getenv("HL"), .libPaths()))  # HL: a library with zuhtml at b181a95
suppressPackageStartupMessages(library(zuhtml))
try_ <- function(e) tryCatch(e, error = function(c) structure(paste0("<ERR ", class(c)[1], ": ", conditionMessage(c), if (!is.null(c$position)) paste0(" @", c$position), ">"), class="errstr"))
print.errstr <- function(x, ...) cat(unclass(x), "\n")
sel <- function(doc, css) { r <- try_(html_elements(doc, css)); if (inherits(r, "errstr")) unclass(r) else paste(vapply(seq_along(r), function(i) { a <- html_attr(r[i], "id"); if (is.na(a)) html_name(r[i]) else a }, ""), collapse=",") }
