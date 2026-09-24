# A document large enough that the loops over it poll for interrupts many
# times, and a runner that reports whether an expression was stopped by an
# elapsed-time limit, enforced where those loops poll.
big_doc <- function() {
  html_parse(strrep("<div class=a><p>x</p><span>y</span></div>", 50000),
             limits = html_limits(max_nodes = 4e6))
}

interrupted <- function(expr) {
  setTimeLimit(elapsed = 0.2, transient = TRUE)
  on.exit(setTimeLimit(elapsed = Inf))
  tryCatch({
    force(expr)
    FALSE
  }, error = function(e) grepl("time limit", conditionMessage(e)))
}
