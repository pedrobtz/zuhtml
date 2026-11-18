source("pre.R")
encs <- c("GBK","gb18030","Big5","EUC-JP","Shift_JIS","EUC-KR")
con <- file("mb.tsv", "w")
for (e in encs) {
  nm <- zuhtml:::zuh_iconv_name(e); cat(e, "->", nm, "\n")
  for (hi in 0x80:0xFF) for (lo in 0x21:0xFF) {
    x <- as.raw(c(0x7a, hi, lo, 0x7a))   # z .. z brackets
    o <- tryCatch(zuhtml:::zuh_iconv(x, nm, NULL), error = function(e) NULL)
    v <- if (is.null(o)) "ERR" else paste(sprintf("%04X", utf8ToInt(rawToChar(o))), collapse = "+")
    writeLines(paste(e, sprintf("%02X%02X", hi, lo), v, sep = "\t"), con)
  }
}
close(con)
