source("pre.R")
encs <- c("IBM866","ISO-8859-2","ISO-8859-3","ISO-8859-4","ISO-8859-5","ISO-8859-6","ISO-8859-7","ISO-8859-8","ISO-8859-8-I","ISO-8859-10","ISO-8859-13","ISO-8859-14","ISO-8859-15","ISO-8859-16","KOI8-R","KOI8-U","macintosh","windows-874","windows-1250","windows-1251","windows-1252","windows-1253","windows-1254","windows-1255","windows-1256","windows-1257","windows-1258","x-mac-cyrillic")
out <- list()
for (e in encs) {
  lab <- zuhtml:::zuh_enc_table[[e]]; lab <- lab[length(lab)]
  if (e=="ISO-8859-8-I") lab <- "logical"
  v <- character(128)
  for (b in 128:255) {
    d <- try_(html_parse(c(s(sprintf('<meta charset="%s"><p>', lab)), as.raw(b))))
    v[b-127] <- if (inherits(d, "err")) "ERR" else paste(sprintf("%04X", utf8ToInt(html_text(html_root(d)))), collapse="+")
  }
  out[[e]] <- v
  cat(e, "(", zuhtml:::zuh_iconv_name(e), ") errors at:", sprintf("%02X", (128:255)[v=="ERR"]), "\n")
}
saveRDS(out, "sb.rds")
writeLines(unlist(lapply(names(out), function(e) paste(e, sprintf("%02X", 128:255), out[[e]], sep="\t"))), "sb.tsv")
