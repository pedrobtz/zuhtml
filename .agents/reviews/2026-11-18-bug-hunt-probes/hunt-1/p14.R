source("h.R")
cat("locale:", Sys.getlocale("LC_CTYPE"), "\n")
f <- file.path("tmp", "utf8.html"); writeBin(c(charToRaw("<p class='caf"), as.raw(c(0xc3, 0xa9)), charToRaw("'>caf"), as.raw(c(0xc3, 0xa9)), charToRaw("</p>")), f)
x <- paste(readLines(f, warn = FALSE), collapse = "\n")   # the usual idiom; unmarked string
cat("Encoding(x):", Encoding(x), " validUTF8:", validUTF8(x), "\n")
d <- tr(html_parse(x)); if (inherits(d, "ERR")) print(d) else { t <- html_text(d); cat("text bytes:", paste(charToRaw(t), collapse = " "), " =", sQuote(rawToChar(charToRaw(t))), "\n"); cat("input_bytes:", html_info(d)$input_bytes, "\n") }
d2 <- html_read(f); cat("html_read text bytes:", paste(charToRaw(html_text(d2)), collapse = " "), "\n")
sel <- rawToChar(c(charToRaw("p.caf"), as.raw(c(0xc3, 0xa9))))
p("selector unmarked", tr(length(html_elements(d2, sel))))
an <- rawToChar(as.raw(c(0xc3, 0xa9)))
d3 <- html_read(f); p("attr default unmarked", charToRaw(html_attr(html_element(d3, "p"), "zz", default = an)))
