.libPaths(c(Sys.getenv("HL"), .libPaths()))  # HL: a library with zuhtml at b181a95
suppressPackageStartupMessages(library(zuhtml))
tr <- function(expr) withCallingHandlers(
  tryCatch(expr, error = function(e) structure(list(cls = class(e)[1], msg = conditionMessage(e), e = e), class = "ERR")),
  warning = function(w) { cat("  [warning] ", conditionMessage(w), "\n", sep = ""); if (getOption("warn") < 2) invokeRestart("muffleWarning") })
print.ERR <- function(x, ...) cat("<", x$cls, "> ", x$msg, "\n", sep = "")
p <- function(label, expr) { cat("---", label, "\n"); r <- tr(expr); print(r); invisible(r) }
