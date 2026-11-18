source("h.R")
R <- function(refs, base) { h <- paste0(sprintf("<a href=\"%s\">x</a>", refs), collapse = ""); d <- html_parse(h); u <- html_url(html_elements(d, "a"), base_url = base); print(data.frame(ref = refs, url = u), right = FALSE) }
base <- "http://a/b/c/d;p?q"
n <- c("g:h"="g:h","g"="http://a/b/c/g","./g"="http://a/b/c/g","g/"="http://a/b/c/g/","/g"="http://a/g","//g"="http://g","?y"="http://a/b/c/d;p?y","g?y"="http://a/b/c/g?y","#s"="http://a/b/c/d;p?q#s","g#s"="http://a/b/c/g#s","g?y#s"="http://a/b/c/g?y#s",";x"="http://a/b/c/;x","g;x"="http://a/b/c/g;x","g;x?y#s"="http://a/b/c/g;x?y#s","."="http://a/b/c/",
"./"="http://a/b/c/",".."="http://a/b/","../"="http://a/b/","../g"="http://a/b/g","../.."="http://a/","../../"="http://a/","../../g"="http://a/g",
"../../../g"="http://a/g","../../../../g"="http://a/g","/./g"="http://a/g","/../g"="http://a/g","g."="http://a/b/c/g.",".g"="http://a/b/c/.g","g.."="http://a/b/c/g..","..g"="http://a/b/c/..g","./../g"="http://a/b/g","./g/."="http://a/b/c/g/","g/./h"="http://a/b/c/g/h","g/../h"="http://a/b/c/h","g;x=1/./y"="http://a/b/c/g;x=1/y","g;x=1/../y"="http://a/b/c/y","g?y/./x"="http://a/b/c/g?y/./x","g?y/../x"="http://a/b/c/g?y/../x","g#s/./x"="http://a/b/c/g#s/./x","g#s/../x"="http://a/b/c/g#s/../x","http:g"="http:g")
d <- html_parse(paste0(sprintf("<a href=\"%s\">x</a>", names(n)), collapse = "")); u <- html_url(html_elements(d, "a"), base_url = base)
cat("RFC mismatches:\n"); print(data.frame(ref = names(n), got = u, want = unname(n))[is.na(u) | u != n, ])
R(c("12:30.html", "a:b", "x y", " x ", "x\ty", "?", "#", "//", "///x", "é/ü?ñ#ö", "HTTP://EX.com/a/../b", "mailto:a@b", "javascript:void(0)", "tel:+1", "\\\\host\\x", "C:\\x", "/a b", "%zz", "a/b:c", "./a:b", "::", ":x", "1http://x", "data:text/html,<p>", "..", "/..", "?a=1&amp;b=2"), "http://h/p/q?z#f")
for (b in list("", " http://h/ ", "h/", "//h/x", "mailto:x@y", "file:///a/b", "http://h", "http://h?q", "HTTP://H/A/../B/", "urn:a:b", "http://h/a b/", "1x://h/")) { cat("base", deparse(b), "\n"); R(c("x", "/x", "?q", "#f", "", "//o/p", "http://z/"), b) }
for (b in list(NA_character_, c("a","b"), 1, TRUE, character(0), factor("http://h/"))) { cat("base", deparse(b)[1], ": "); print(tr(html_url(html_parse("<a href=x>"), base_url = b))) }
d <- html_parse("<a href=x id=1 HREF=y data-u='z' xlink:href=q>t</a><p>no</p>text", base_url = "http://h/d/")
a <- html_elements(d, "a, p")
for (at in list("href", "HREF", "data-u", "", NA_character_, c("href","id"), 1, "nope", factor("href"))) { cat("attr", deparse(at)[1], ": "); print(tr(html_url(a, attr = at))) }
p("url doc", html_url(d)); p("url NA node", html_url(a[c(1, NA, 2)])); p("url empty", html_url(a[0]))
# base element variants
B <- function(h, base = NULL) { d <- html_parse(h, base_url = base); c(html_url(html_element(d, "a")), html_links(d, absolute = TRUE)$url, html_info(d)$base_url) }
p("base el", B("<base href='http://b/x/'><a href=y>"))
p("base el rel + given", B("<base href='sub/'><a href=y>", "http://g/d/"))
p("base el rel no given", B("<base href='sub/'><a href=y>"))
p("base no href then href", B("<base target=_blank><base href='http://b/'><a href=y>"))
p("two bases", B("<base href='http://one/'><base href='http://two/'><a href=y>"))
p("base empty href", B("<base href=''><a href=y>", "http://g/d/p"))
p("base bad href", B("<base href='ht tp://x'><a href=y>", "http://g/d/p"))
p("base ws href", B("<base href='  http://b/  '><a href=y>"))
p("base in body after a", B("<a href=y>l</a><base href='http://late/'>"))
p("base_url ''", B("<a href=y>", "")); p("base_url ws", B("<a href=y>", " http://g/ ")); p("base_url rel", B("<a href=y>", "g/"))
for (b in list(NA_character_, c("a","b"), 1, character(0))) { cat("parse base", deparse(b)[1], ": "); print(tr(html_parse("<a href=x>", base_url = b))) }
l1 <- "http://h/caf\xe9/"; Encoding(l1) <- "latin1"
d <- html_parse("<a href='x'>é</a>", base_url = l1); u <- html_url(html_element(d, "a")); p("latin1 base", list(u, Encoding(u), charToRaw(u), Encoding(html_info(d)$base_url)))
u2 <- html_url(html_element(d, "a"), base_url = enc2utf8(l1)); p("same as utf8 base", identical(u, u2))
# links
d <- html_parse("<a href='/1'> One\n two </a><a>nohref</a><area href=2><a href=''>e</a><svg><a href='s'>svg</a><a xlink:href='xs'>x</a></svg><a href='/1'>dup</a><map><area href='#f'></map>", base_url = "http://h/d/")
p("links", html_links(d)); p("links abs", html_links(d, absolute = TRUE)); p("links str", str(html_links(html_parse("<p>"))))
a1 <- html_elements(d, "a"); p("links on nodeset w NA + dup", html_links(c(a1[1], a1[NA_integer_], a1[1], html_elements(d, "body"))))
p("links absolute bad", list(tr(html_links(d, absolute = "yes")), tr(html_links(d, absolute = c(TRUE, TRUE))), tr(html_links(1))))
