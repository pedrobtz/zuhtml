source("pre.R")
res <- function(ref, base) { d <- html_parse(sprintf('<a href="%s">x</a>', gsub('"', '&quot;', ref))); html_url(html_element(d, "a"), base_url = base) }
B <- "http://a/b/c/d;p?q"
ex <- c("g:h"="g:h","g"="http://a/b/c/g","./g"="http://a/b/c/g","g/"="http://a/b/c/g/","/g"="http://a/g","//g"="http://g","?y"="http://a/b/c/d;p?y","g?y"="http://a/b/c/g?y","#s"="http://a/b/c/d;p?q#s","g#s"="http://a/b/c/g#s","g?y#s"="http://a/b/c/g?y#s",";x"="http://a/b/c/;x","g;x"="http://a/b/c/g;x","g;x?y#s"="http://a/b/c/g;x?y#s","."="http://a/b/c/","./"="http://a/b/c/",".."="http://a/b/","../"="http://a/b/","../g"="http://a/b/g","../.."="http://a/","../../"="http://a/","../../g"="http://a/g",
"../../../g"="http://a/g","../../../../g"="http://a/g","/./g"="http://a/g","/../g"="http://a/g","g."="http://a/b/c/g.",".g"="http://a/b/c/.g","g.."="http://a/b/c/g..","..g"="http://a/b/c/..g","./../g"="http://a/b/g","./g/."="http://a/b/c/g/","g/./h"="http://a/b/c/g/h","g/../h"="http://a/b/c/h","g;x=1/./y"="http://a/b/c/g;x=1/y","g;x=1/../y"="http://a/b/c/y","g?y/./x"="http://a/b/c/g?y/./x","g?y/../x"="http://a/b/c/g?y/../x","g#s/./x"="http://a/b/c/g#s/./x","g#s/../x"="http://a/b/c/g#s/../x","http:g"="http:g")
stopifnot(identical(res("", B), "http://a/b/c/d;p?q")); for (r in names(ex)) { got <- res(r, B); if (!identical(got, unname(ex[r]))) cat("MISMATCH", r, got, ex[r], "\n") }
cases <- list(c("x","http://a"),c("x","http://a?q"),c("x","http://a#f"),c("","http://a/b#f"),c("#","http://a/b#f"),c("?","http://a/b?q#f"),c("x","mailto:u@h"),c("x","file:///a/b"),c("//","http://a/b"),c("///x","http://a/b"),c("x y","http://a/"),c(" x ","http://a/"),c("x\ty","http://a/"),c("\n x","http://a/"),c("x","a/b"),c("x","//a/b"),c("http://h/a/../b","zzz"),c("HTTP://H/A/./B",NA),c("1http://x","http://a/"),c("a:b","http://a/"),c("a/b:c","http://a/"),c("./a:b","http://a/"),c(":x","http://a/"),c("é","http://a/"),c("a\u00a0b","http://a/"),c("x"," http://a/"),c("x","http://a/ b/"),c("..//c","x:/a/b"),c("/.//c","x:/a/b"),c("..","http://a"),c("../..","http://a/b"),c("/..","http://a/b"),c(".","http://a/b/"),c("./","http://a/b"),c("..","http://a/b/c/"),c("g","http://a/b/c/d;p?q=1/2"),c("g","http://a/b?c/d/"),c("javascript:alert(1)","http://a/"),c("mailto:x@y","http://a/"),c("tel:+1","http://a/"),c("data:,a/../b","http://a/"),c("x","urn:a:b"),c("#f","urn:a:b"),c("x","HTTP://A/b"),c("\\\\evil","http://a/b"),c("/a b","http://a"),c("%zz","http://a/"),c("[","http://a/"),c("http://[::1","http://a/"),c("x","http://[::1]:80/a"),c("//h:80","https://a/b"),c("a/b/../../../c","http://a/x/y"),c("...","http://a/x/y"),c(".../a","http://a/x/y"),c("a/.../b","http://a/"),c("./.","http://a/x/y"),c("a/..","http://a/x/y"),c("a/../","http://a/x/y"),c("a/.","http://a/x/y"),c("/.","http://a/x/y"),c("/..","http://a/x/y"),c("..a","http://a/x/y"),c("?a/../b","http://a/x/y"), c("x","http:"), c("x","http:/"), c("x","http://"), c("x","http:a"), c("../x","http:a/b"), c("x", ""), c("x","http://a/b?q#f/g"), c("\u0001x","http://a/"), c("x\u007f","http://a/"))
for (cs in cases) cat(sprintf("%-22s + %-24s => %s\n", encodeString(cs[1]), encodeString(cs[2]), tryCatch(res(cs[1], if (is.na(cs[2])) NULL else cs[2]), error=function(e) paste("ERR", conditionMessage(e)))))
# base element handling
bb <- function(h, base=NULL, ...) { d <- if (is.null(base)) html_parse(h) else html_parse(h, base_url=base); cat(sprintf("%-100s [%s] => %s\n", h, if(is.null(base)) "" else base, paste(html_url(html_elements(d, "a"), ...), collapse=" | "))) }
bb('<base href="http://b/x/"><a href="y">')
bb('<base href="/x/"><a href="y">'); bb('<base href="/x/"><a href="y">', "http://p/q/r")
bb('<base href="http://b1/"><base href="http://b2/"><a href="y">')
bb('<base target=_blank><base href="http://b2/"><a href="y">')
bb('<base href="ht tp://bad"><base href="http://b2/"><a href="y">', "http://p/")
bb('<base href=""><a href="y">', "http://p/q")
bb('<base href=" http://b/ "><a href="y">')
bb('<a href="y"><base href="http://late/">')
bb('<body><svg><base href="http://svg/"></base></svg><a href="y">', "http://p/")
bb('<template><base href="http://tmpl/"></template><a href="y">', "http://p/")
bb('<base href="http://b/x/"><a href="y">', "http://p/", base_url="http://explicit/")
bb('<base href="//b/x/"><a href="y">', "https://p/")
bb('<base href="http://b/x/?q#f"><a href="y"><a href="#z"><a href=""><a href="?k">')
bb('<base href="javascript:1"><a href="y">', "http://p/")
bb('<base href="data:text/html,x"><a href="y"><a href="#f">', "http://p/")
bb('<base href="http://b/"><a>')
d <- html_parse('<base href="http://b/d/"><a href="x">t</a><a href="">e</a><a>n</a><area href="#f"><a href=" sp ">s</a><a href="a b">bad</a><svg><a href="s1">sv</a><a xlink:href="s2">sx</a></svg><link href="l"><img src="i.png">')
print(html_links(d)); print(html_links(d, absolute=TRUE)); print(html_url(html_elements(d,"img"), "src")); print(try_(html_url(html_elements(d,"svg a"), "xlink:href")))
print(html_links(html_elements(d, "a")[c(2,1,1)])); print(html_links(html_fragment('<a href="/x">k</a>'), absolute=TRUE)); print(html_links(html_parse("<p>")))
