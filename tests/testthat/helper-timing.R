# Time bounds are asserted only where the workflow asks for them
# (R-CMD-check.yaml sets ZUHTML_TIMING_TESTS=true). Emulated, sanitized,
# valgrind, gctorture and coverage builds run many times slower, and a
# bound that fails there says nothing about the code.
timing_asserted <- function() {
  identical(Sys.getenv("ZUHTML_TIMING_TESTS"), "true")
}
