source("pre.R")
ok <- function(x, m, ...) !inherits(try_(html_parse(x, limits = html_limits(max_memory = m), ...)), "err")
for (x in list("", "<p>x", paste0(strrep("<p class=a>hello <b>w</b>", 200)), strrep("<div>", 300), paste0("<table>", strrep("<tr><td>1<td>2", 100)))) {
  lo <- 1; hi <- 2^30
  while (hi - lo > 1) { mid <- floor((lo + hi) / 2); if (ok(x, mid)) hi <- mid else lo <- mid }
  i <- html_info(html_parse(x))
  # monotonic check around
  around <- vapply(hi + (-5:5) * 1, function(m) ok(x, m), NA)
  far <- vapply(c(hi %/% 2, hi - 100, hi + 100, hi * 2), function(m) ok(x, m), NA)
  cat(nchar(x), "min max_memory:", hi, " peak:", i$parse_peak_bytes, " native:", i$native_bytes, " around:", paste(as.integer(around), collapse = ""), " far:", paste(as.integer(far), collapse=""), "\n")
  e <- tryCatch(html_parse(x, limits = html_limits(max_memory = hi - 1)), error = function(e) e); cat("   ", class(e)[1], e$limit, format(e$observed), "\n")
}
# interplay: which limit reports when several trip
x <- strrep("<div>", 600)
e <- tryCatch(html_parse(x, limits = html_limits(max_depth = 10, max_nodes = 5, max_input = 100)), error = function(e) e); cat(e$limit, format(e$observed), "\n")
e <- tryCatch(html_parse(x, limits = html_limits(max_depth = 10, max_nodes = 5)), error = function(e) e); cat(e$limit, format(e$observed), "\n")
e <- tryCatch(html_parse(strrep("<p>", 600), limits = html_limits(max_nodes = 5, max_memory = 5000)), error = function(e) e); cat(e$limit, format(e$observed), "\n")
# does a depth-truncated parse leak partial doc? and gc
for (i in 1:2000) try_(html_parse(x))
cat("after 2000 failed parses ok\n"); print(gc()[, 2])
