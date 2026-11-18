source("pre.R")
t <- function(lab, ...) { b <- r(...); d <- try_(html_parse(c(s(sprintf('<meta charset="%s"><p>ab', lab)), b))); cat(sprintf("%-12s %-10s ", lab, paste(sprintf("%02X", as.integer(b)), collapse="")), if (inherits(d,"err")) paste("ERR", d$cls[1]) else paste(sprintf("%04X", utf8ToInt(html_text(html_root(d)))), collapse=" "), "\n") }
t("euc-jp", 0xa4); t("euc-jp", 0x8f, 0xa2); t("shift_jis", 0x82); t("gbk", 0x81); t("gb18030", 0x81, 0x30); t("gb18030", 0x81, 0x30, 0x81); t("big5", 0xa4); t("euc-kr", 0xb0)
t("iso-2022-jp", 0x1b); t("iso-2022-jp", 0x1b, 0x24); t("iso-2022-jp", 0x1b, 0x24, 0x42, 0x24); t("iso-2022-jp", 0x1b, 0x24, 0x42); t("iso-2022-jp", 0x1b, 0x28, 0x4a)
t("big5", 0x88, 0x62, 0x41); t("windows-1258", 0x61, 0xec, 0x41)
# saveRDS round trip
d <- html_parse("<p>x"); f <- tempfile(); saveRDS(d, f); d2 <- readRDS(f)
print(try_(html_text(html_root(d2)))); print(try_(html_info(d2))); print(d2); print(try_(html_problems(d2)))
# fragment args
print(try_(html_fragment("<p>", "div", "latin1"))); print(try_(html_fragment("<p>", NA))); print(try_(html_fragment("<p>", c("a","b")))); print(try_(html_fragment("<p>", "div", enc = "UTF-8")))
print(try_(html_fragment("<p>", "dïv")))
print(try_(html_fragment("<p>", "div ")))
print(try_(html_fragment("<p>x", "DiV", comments = NULL)))
print(try_(html_fragment("<p>x", "div", limits = NULL)))
print(try_(html_fragment("<p>x", "div", encoding = NULL, base_url = NULL)))
# U+FEFF mid text, utf16 mid BOM
cat(cp(html_parse("a﻿b")), "\n")
cat(cp(html_parse(r(0xff,0xfe,0x41,0,0xff,0xfe,0x42,0))), "\n")
# gb18030 U+FEFF first then text; latin1 arg with EF BB BF
cat(cp(html_parse(r(0x84,0x31,0x95,0x33,0x41), encoding = "gb18030")), "\n")
print(try_(cp(html_parse(c(r(0xef,0xbb,0xbf), s("x")), encoding = "windows-1252"))))
# html_info printing
print(html_info(html_parse(c(s('<meta charset=sjis><p>'), r(0x82,0xa0)))))
