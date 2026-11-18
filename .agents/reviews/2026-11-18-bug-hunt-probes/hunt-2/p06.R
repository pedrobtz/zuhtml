source("pre.R")
res <- function(expr) { v <- tryCatch(expr, error=function(e) e); if (inherits(v,"error")) paste0("ERR ", class(v)[1], " limit=", format(v$limit), " observed=", format(v$observed), " | ", conditionMessage(v)) else paste0("ok input_bytes=", html_info(v)$input_bytes, " nodes=", html_info(v)$nodes) }
L <- function(n) html_limits(max_input = n)
td <- tempfile("h2"); dir.create(td)
routes <- function(bytes, n, ...) {
  f <- file.path(td, "f.html"); writeBin(bytes, f)
  gz <- file.path(td, "f.html.gz"); g <- gzfile(gz, "wb"); writeBin(bytes, g); close(g)
  oc <- file(f, "rb"); on.exit(close(oc))
  c(raw = res(html_parse(bytes, limits = L(n), ...)),
    path = res(html_read(f, limits = L(n), ...)),
    url = res(html_read(paste0("file://", f), limits = L(n), ...)),
    conn = res(html_read(file(f), limits = L(n), ...)),
    open = res(html_read(oc, limits = L(n), ...)),
    gz = res(html_read(gzfile(gz), limits = L(n), ...)),
    rawc = {rc <- rawConnection(bytes); on.exit(close(rc), add=TRUE); res(html_read(rc, limits = L(n), ...))})
}
cat("== ascii 99/100/101 at max_input=100\n")
for (k in c(99,100,101)) { cat(k, "\n"); print(routes(s(strrep("a", k)), 100)); cat(" chr:", res(html_parse(strrep("a",k), limits=L(100))), "\n") }
cat("== UTF-8 BOM + 100 bytes\n"); print(routes(c(r(0xef,0xbb,0xbf), s(strrep("a",100))), 100))
cat("== UTF-8 multibyte 50 x e-acute (100 bytes) / 51\n")
cat(res(html_parse(strrep("é", 50), limits=L(100))), "\n", res(html_parse(strrep("é", 51), limits=L(100))), "\n")
cat("== latin1 raw 50 bytes -> 100 decoded; 51\n")
cat(res(html_parse(rep(r(0xe9), 50), encoding="latin1", limits=L(100))), "\n", res(html_parse(rep(r(0xe9), 51), encoding="latin1", limits=L(100))), "\n")
cat("== UTF-16LE: 100 ascii chars=200 raw; 101; 400raw/401\n")
u16 <- function(n) as.vector(rbind(s(strrep("a", n)), as.raw(0)))
for (k in c(100,101,200,201)) cat(k, res(html_parse(u16(k), encoding="UTF-16LE", limits=L(100))), "\n")
cat("== raw 400/401 bytes latin1 (4x cap)\n")
for (k in c(400,401)) cat(k, res(html_parse(s(strrep("a",k)), encoding="latin1", limits=L(100))), "\n")
cat("== routes 400/401\n"); print(routes(s(strrep("a",400)), 100)); print(routes(s(strrep("a",401)), 100))
cat("== iso-2022-jp escapes: 402 raw bytes decode to 0\n")
x <- rep(r(0x1b,0x28,0x42), 134); cat(length(x), res(html_parse(x, encoding="ISO-2022-JP", limits=L(100))), "\n")
cat("== latin1 char string (native enc marked latin1)\n")
z <- strrep("\xe9", 60); Encoding(z) <- "latin1"; cat(res(html_parse(z, limits=L(100))), "\n")
cat("== empty\n"); print(routes(raw(), 100)); cat(res(html_parse("")), "\n")
cat("== numbers\n")
for (v in list(NA, NA_real_, 0, -1, 1.5, Inf, .Machine$integer.max, .Machine$integer.max+1, "10", c(1,2), 1L, TRUE, NULL)) {
  for (nm in c("max_input","max_memory","max_depth","max_nodes","max_errors")) {
    a <- list(v); names(a) <- nm
    o <- try_(do.call(html_limits, a))
    cat(sprintf("%-11s %-12s %s\n", nm, paste(deparse(v), collapse=""), if (inherits(o,"err")) paste("ERR", o$cls[1]) else { p <- try_(html_parse("<p>x", limits=o)); if (inherits(p,"err")) paste("limits ok; parse ERR", p$cls[1], p$msg) else "ok" }))
  }
}
l <- html_limits(); l$max_input <- 1e300; cat(res(html_parse("x", limits=l)), "\n")
l <- unclass(html_limits()); cat(res(html_parse("x", limits=l)), "\n")
l <- html_limits(); l$max_depth <- 2^31; cat(res(html_parse("x", limits=l)), "\n")
