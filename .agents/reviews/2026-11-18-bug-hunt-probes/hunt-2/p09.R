source("pre.R")
P <- function(label, x, ...) { cat("--", label, "\n"); d <- html_parse(x, ...); print(html_problems(d)); invisible(d) }
P("ascii baseline", "<!doctype html><p>ab</x>")
P("multibyte before: é é", "<!doctype html><p>éé</x>")
P("astral before", "<!doctype html><p>\U0001F600</x>")
P("tab before", "<!doctype html><p>\t</x>")
P("LF", "<!doctype html>\n<p>a\n</x>")
P("CRLF", "<!doctype html>\r\n<p>a\r\n</x>")
P("CR only", "<!doctype html>\r<p>a\r</x>")
P("BOM raw", c(r(0xef,0xbb,0xbf), s("<!doctype html><p>ab</x>")))
P("BOM string", "﻿<!doctype html><p>ab</x>")
P("utf16", {z <- s("<!doctype html><p>ab</x>"); c(r(0xff,0xfe), as.vector(rbind(z, as.raw(0))))})
P("latin1 é", c(s("<!doctype html><p>"), r(0xe9,0xe9), s("</x>")), encoding = "latin1")
cat("-- fragment\n"); print(html_problems(html_fragment("<p>éé</x>")))
cat("-- fragment tbody\n"); print(html_problems(html_fragment("<tr><td>éé</x>", "tbody")))
P("eof in comment", "<!doctype html><p>a<!-- x")
P("NUL char ref", "<!doctype html><p>&#0;&#x80;&#xD800;&#x110000;&notit;")
cat(cp(html_parse("<!doctype html><p>&#0;&#x80;&#x9F;&#x81;&#xD800;&#x110000;&#xFFFE;&#1;")), "\n")
P("dup attr", "<!doctype html><p a=1 a=2>")
P("C1 raw text", "<!doctype html><p>\u0080")
cat("== quirks\n")
q <- function(x, ...) html_info(html_parse(x, ...))$quirks_mode
cat(q(""), q("<p>"), q("<!DOCTYPE html>"), q("<!doctype HTML>"), q('<!DOCTYPE html SYSTEM "about:legacy-compat">'), "\n")
cat(q('<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">'),
    q('<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">'),
    q('<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">'),
    q('<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">'),
    q('<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN" "x">'),
    q('<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">'),
    q('<!DOCTYPE foo>'), q('<!-- c --><!DOCTYPE html>'), q('x<!DOCTYPE html>'), q('<!DOCTYPE html><!DOCTYPE foo>'),
    q('<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 FRAMESET//en">'), q('<!DOCTYPE html SYSTEM "http://www.ibm.com/data/dtd/v11/ibmxhtml1-transitional.dtd">'), "\n")
cat("fragment quirks:", html_info(html_fragment("<p>x"))$quirks_mode, html_info(html_fragment("<!DOCTYPE html><p>x"))$quirks_mode, "\n")
cat("quirks effect: <p><table> in quirks vs no-quirks\n")
cat(html_serialize(html_parse("<p>a<table>")), "\n", html_serialize(html_parse("<!doctype html><p>a<table>")), "\n", html_serialize(html_fragment("<p>a<table>")), "\n")
cat("== doctype node\n")
d <- html_parse('<!DOCTYPE html PUBLIC "pub\'id" "sys">'); k <- html_children(d); print(html_type(k)); print(html_name(k)); cat(html_serialize(d), "\n")
d <- html_parse('<!DOCTYPE>'); cat(html_serialize(d), "|", html_name(html_children(d)), "\n")
d <- html_parse('<!DOCTYPE HTML>'); cat(html_serialize(d), "\n")
d <- html_parse('<!DOCTYPE potato SYSTEM \'a"b\'>'); cat(html_serialize(d), "\n")
cat("== comments=FALSE\n")
x <- "<!--a--><!doctype html><!--b--><html><!--c--><head><!--d--></head><!--e--><body>x<!--f-->y<table><!--g--><tr><td>1</table><template><!--h-->t</template><svg><!--i--></svg><?pi?><![CDATA[z]]></body><!--j--></html><!--k-->"
d1 <- html_parse(x); d0 <- html_parse(x, comments = FALSE)
cat(html_serialize(d1), "\n", html_serialize(d0), "\n")
cat(gsub("<!--.-->", "", html_serialize(d1)) == html_serialize(d0), "\n")
print(html_type(html_children(html_element(d0, "body")))); print(html_text(html_children(html_element(d0, "body"))))
print(html_type(html_children(html_element(d1, "body"))))
cat("problems equal:", identical(html_problems(d1), html_problems(d0)), "\n")
