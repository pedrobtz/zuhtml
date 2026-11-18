source("pre.R")
print(iconv("Hello", "CP1258", "UTF-8")); print(iconv(list(charToRaw("Hello")), "CP1258", "UTF-8", toRaw = TRUE))
f <- tempfile(fileext = ".html")
writeBin(c(s('<html><head><meta http-equiv="Content-Type" content="text/html; charset=windows-1258"></head><body>Xin ch'), r(0xe0), s('o')), f)
d <- html_read(f); cat(html_serialize(d), "\n"); print(html_info(d)$input_bytes); print(file.size(f))
cat(html_serialize(html_fragment(s("<b>Hanoi</b> Vietnam"), encoding = "windows-1258")), "\n")
cat(html_serialize(html_fragment(c(s("<p>"), r(0xf9, 0xec, 0xe5, 0xed)), encoding = "windows-1255")), "\n")
cat(sprintf("%04X", utf8ToInt(html_text(html_fragment(c(s("<p>"), r(0xf9, 0xec, 0xe5, 0xed), s("</p>")), encoding = "CP1255")))), "\n")
# templates
d <- html_parse("<!doctype html><body><template><p>in<template><b>deep</b></template></p></template><p>out</p>")
cat(html_text(html_root(d)), "|", html_text_clean(d), "|", length(html_elements(d, "p")), length(html_elements(d, "b")), "\n")
tc <- html_template_content(html_elements(d, "template")); print(tc); cat(html_serialize(d), "\n")
f2 <- html_fragment("<p>in</p><template><i>t</i></template>", "template"); cat(html_serialize(f2), "|", html_text(html_root(f2)), "|", length(html_elements(f2, "p")), length(html_elements(f2, "i")), "\n")
d <- html_parse("<table><template><tr><td>x</td></tr></template><tr><td>y</td></tr></table>"); cat(html_serialize(d), "| tds:", length(html_elements(d, "td")), "\n")
d <- html_parse("<template><meta charset=koi8-r></template>"); cat(html_serialize(d), "\n")
d <- html_parse("<svg><template><p>x</p></template></svg>"); cat(html_serialize(d), "| p:", length(html_elements(d, "p")), "\n")
d <- html_parse("<template shadowrootmode=open><p>x</p></template>"); cat(html_serialize(d), "| p:", length(html_elements(d, "p")), "\n")
# whole doc vs fragment of body
src <- "<p>One<p>Two<table><tr><td>a<b>c</table><ul><li>x<li>y</ul>t&nbsp;&amp;<svg><circle/></svg><math><mi>x</mi></math>"
b <- html_element(html_parse(paste0("<!doctype html>", src)), "body"); fr <- html_fragment(src, "body")
inner <- sub("^<body>(.*)</body>$", "\\1", html_serialize(b)); cat(identical(inner, html_serialize(fr)), "\n"); if (!identical(inner, html_serialize(fr))) cat(inner, "\n", html_serialize(fr), "\n")
src <- "<p>One<table><tr><td>a</table>"
b <- html_element(html_parse(src), "body"); fr <- html_fragment(src, "body"); cat(html_serialize(b), "\n", html_serialize(fr), "\n")
