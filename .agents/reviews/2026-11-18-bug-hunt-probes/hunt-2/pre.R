.libPaths(c(Sys.getenv("HL"), .libPaths()))  # HL: a library with zuhtml at b181a95
suppressPackageStartupMessages(library(zuhtml))
try_ <- function(expr) tryCatch(expr, error = function(e) structure(list(cls = class(e), msg = conditionMessage(e)), class = "err"))
print.err <- function(x, ...) cat("ERR[", paste(x$cls, collapse = ","), "]: ", x$msg, "\n", sep = "")
txt <- function(d) if (inherits(d, "err")) { print(d); invisible(NA) } else html_text(html_root(d))
r <- function(...) as.raw(c(...))
s <- function(x) charToRaw(x)
show <- function(label, expr) { cat("--", label, "\n"); v <- try_(expr); if (inherits(v, "err")) print(v) else print(v); invisible(v) }
cp <- function(d) if (inherits(d, "err")) d else sprintf("U+%04X", utf8ToInt(html_text(html_root(d))))
