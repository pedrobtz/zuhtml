source("pre.R")
for (u in c(0x01,0x08,0x0B,0x0C,0x0E,0x1F,0x7F,0x80,0x85,0x9F,0xA0,0xFDD0,0xFDEF,0xFFFE,0xFFFF,0x1FFFE,0x10FFFF,0xFFFD,0xD)) {
  d <- html_parse(paste0("<p title='a", intToUtf8(u), "b'>x", intToUtf8(u), "y<!--c", intToUtf8(u), "d--><script>s",intToUtf8(u),"t</script>"))
  cat(sprintf("U+%04X text:", u), cp(d), " attr:", sprintf("%04X", utf8ToInt(html_attr(html_element(d,"p"),"title"))), " prob:", paste(html_problems(d)$code, collapse=","), "\n")
}
# tail-char loss in stateful encodings
for (lab in c("windows-1255","windows-1258","big5","euc-jp","shift_jis","gbk","gb18030","euc-kr","iso-2022-jp","koi8-u","windows-1251")) {
  lost <- c()
  for (b in 1:255) {
    d <- try_(html_parse(c(s(sprintf('<meta charset="%s"><p>zz', lab)), as.raw(b))))
    if (inherits(d,"err")) next
    t <- html_text(html_root(d))
    if (nchar(t) < 3) lost <- c(lost, b)
  }
  cat(lab, "last byte lost for:", sprintf("%02X", lost), "\n")
}
show("1258 hello", html_text(html_root(html_parse(c(s('<meta charset="windows-1258"><p>Hello'))))))
show("1258 compose", cp(html_parse(c(s('<meta charset="windows-1258"><p>a'), r(0xec), s("</p>")))))
show("1255 compose", cp(html_parse(c(s('<meta charset="windows-1255"><p>'), r(0xe9, 0xc4), s("</p>")))))
show("arg CP1258 hello", html_text(html_root(html_parse(s('<p>Hello'), encoding="CP1258"))))
show("koi8-u AE BE", cp(html_parse(c(s('<meta charset="koi8-u"><p>'), r(0xae, 0xbe)))))
