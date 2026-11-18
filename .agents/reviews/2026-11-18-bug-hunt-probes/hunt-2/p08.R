source("pre.R")
maxdepth <- function(d) { e <- html_elements(d, "*"); max(vapply(seq_along(e), function(i) length(html_ancestors(e[i])), 0L)) + 1 }
res <- function(expr) { v <- tryCatch(expr, error=function(e) e); if (inherits(v,"error")) paste0("ERR ", class(v)[1], " ", v$limit, " obs=", format(v$observed)) else paste0("ok nodes=", html_info(v)$nodes, " depth=", maxdepth(v)) }
Ld <- html_limits(max_depth = 10)
for (k in 3:12) cat(k, res(html_parse(paste0(strrep("<b><p>", k), strrep("</b>", k)), limits = Ld)), "\n")
cat("misnested a/table foster\n")
for (k in 2:8) cat(k, res(html_parse(paste0(strrep("<table><a>", k)), limits = Ld)), "\n")
for (k in 2:12) cat(k, res(html_parse(paste0(strrep("<a><p>", k), "</a>"), limits = Ld)), "\n")
for (k in 2:12) cat(k, res(html_parse(paste0("<b>", strrep("<div>", k), "</b>x"), limits = Ld)), "\n")
for (k in 2:12) cat(k, res(html_parse(paste0(strrep("<i>", k), "<p>", strrep("<p>x", 3)), limits = Ld)), "\n")
