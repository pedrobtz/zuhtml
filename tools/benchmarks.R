# Benchmarks: parse (including conversion), selection and table
# extraction, on inputs of different shapes. Times are medians over
# repetitions; memory is the parser's peak native bytes and the frozen
# document's size, reported separately. There is deliberately no single
# headline number: which one matters depends on the input.
#
# Run from the package root: tools/run-benchmarks. Needs the package
# installed or loadable with pkgload.

suppressMessages(
  if (requireNamespace("pkgload", quietly = TRUE)) {
    pkgload::load_all(".", quiet = TRUE)
  } else {
    library(zuhtml)
  }
)

page <- function(n) {
  row <- paste0(
    "<div class=product><h2 class=name>Item %d</h2>",
    "<span class=price>%d.50</span><a href='item%d.html'>more</a>",
    "<p>Some <b>descriptive</b> text, with <i>markup</i>.</p></div>"
  )
  paste0(
    "<!DOCTYPE html><title>Catalog</title><nav><ul>",
    strrep("<li><a href='/x'>Link</a>", 20), "</ul></nav>",
    paste(sprintf(row, seq_len(n), seq_len(n), seq_len(n)), collapse = ""),
    "<table><tr><th>A<th>B<th>C",
    strrep("<tr><td>1<td>2<td>3", n), "</table>"
  )
}

inputs <- list(
  tiny = "<p>Hello <b>world</b></p>",
  ordinary = page(200),
  large = page(40000),
  deep = strrep("<div>", 500),
  malformed = strrep("<p><a><b>misnested</p></a><table>x<tr>y</b>", 2000)
)

median_time <- function(expr, reps) {
  times <- vapply(seq_len(reps), function(i) {
    system.time(force(expr()))[["elapsed"]]
  }, numeric(1))
  stats::median(times)
}

fmt_bytes <- function(b) {
  format(structure(b, class = "object_size"), units = "auto", standard = "SI")
}

cat(sprintf("%-10s %10s %10s %11s %11s %9s %9s\n", "input", "size",
            "parse", "peak mem", "doc mem", "select", "tables"))
for (nm in names(inputs)) {
  x <- inputs[[nm]]
  reps <- if (nchar(x) > 1e6) 3L else 20L
  t_parse <- median_time(function() html_parse(x), reps)
  doc <- html_parse(x)
  info <- html_info(doc)
  t_sel <- median_time(function() html_elements(doc, "div.product > h2.name, a[href$='.html']"), reps)
  t_tab <- median_time(function() html_tables(doc), reps)
  cat(sprintf("%-10s %10s %9.4fs %11s %11s %8.4fs %8.4fs\n", nm,
              fmt_bytes(info$input_bytes), t_parse,
              fmt_bytes(info$parse_peak_bytes), fmt_bytes(info$native_bytes),
              t_sel, t_tab))
}
cat(sprintf("\n%s, R %s, %s\n", format(Sys.time(), "%Y-%m-%d"),
            getRversion(), R.version$platform))
