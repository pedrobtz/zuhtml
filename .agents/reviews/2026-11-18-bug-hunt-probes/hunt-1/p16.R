source("h.R")
s <- "<p>x</p></b></i>"; n <- nrow(html_problems(html_parse(s)))
for (k in c(n - 1, n, n + 1)) { d <- html_parse(s, limits = html_limits(max_errors = k)); cat("max_errors", k, "kept", nrow(html_problems(d)), "trunc attr", attr(html_problems(d), "truncated"), "info", html_info(d)$problems, html_info(d)$problems_truncated, "\n") }
p("problems subset keeps attr?", attributes(html_problems(html_parse(s))[1, ])$truncated)
p("problems nonascii col", html_problems(html_parse("<p>éé中</b>\né</i>")))
# microdata URL props without the attribute
M <- function(h, base = NULL) lapply(html_microdata(html_parse(h, base_url = base))[[1]]$properties, `[[`, 1)
p("url prop absent, base", M("<div itemscope><a itemprop=a>t</a><img itemprop=i><link itemprop=l><object itemprop=o></object><a itemprop=a2 href=''>e</a><a itemprop=bad href='x y'>e</a></div>", "http://h/page"))
p("url prop absent, nobase", M("<div itemscope><a itemprop=a>t</a><a itemprop=r href=rel>r</a></div>"))
# max_selector_length has no consumer
d <- html_parse("<p>x", limits = html_limits(max_selector_length = 1)); p("sel len limit ignored", length(html_elements(d, "p, div, span")))
# css Encoding bytes
cb <- "p"; cb2 <- "p.\xc3\xa9"; Encoding(cb2) <- "bytes"; p("css bytes", tr(length(html_elements(d, cb2))))
nb <- "cl\xc3\xa9"; Encoding(nb) <- "bytes"; p("attr name bytes", tr(html_attr(d, nb))); p("attr default bytes", tr(html_attr(d, "x", default = nb))); p("base_url bytes", tr(html_url(html_elements(html_parse("<a href=x>", base_url = nb), "a")))); p("context bytes", tr(html_fragment("<p>", context = nb))); p("encoding bytes", tr(html_parse(charToRaw("<p>"), encoding = nb)))
p("match bytes", tr(html_tables(html_parse("<table><tr><td>x</table>"), match = nb)))
p("na bytes", tr(html_table(html_element(html_parse("<table><tr><td>clé</table>"), "table"), header = FALSE, na = nb)))
# css selector error with invalid position splitting? selectors with multibyte before error in attr value
e <- tr(html_elements(d, "[a='中文'] >> x")); p("pos after CJK", c(e$e$position, e$msg))
e <- tr(html_elements(d, "\U0001F600 !")); p("pos after emoji", c(e$e$position, e$msg))
e <- tr(html_elements(d, "p !")); str(e$e[setdiff(names(e$e), c("call", "message"))])
e <- tr(html_elements(d, "p:hover")); str(e$e[setdiff(names(e$e), c("call", "message"))])
# print n / format
ps <- html_elements(html_parse(paste(rep("<p>x</p>", 12), collapse = "")), "p"); p("print default", print(ps)); p("print n=Inf", print(ps[1:2], n = Inf)); p("print n=-1", tr(print(ps[1:2], n = -1))); p("print n='3'", tr(print(ps[1:2], n = "3"))); p("print n=c(1,2)", tr(print(ps[1:3], n = c(1, 2))))
p("format wide", format(html_elements(html_parse("<p title='中文中文中文中文'>x<!--a\nb-->"), "p"), width = 12)); p("format quote", format(html_elements(html_parse("<p title='a\"b&lt;'>"), "p")))
p("format text nl", format(html_children(html_element(html_parse("<p>line1\nline2 is long long long long long long long long long long long long long</p>"), "p"), FALSE)))
# html_info on nodeset & fields
p("info ns", class(html_info(ps))); i <- html_info(html_parse("<p>", base_url = "http://b/")); p("info $ partial", list(i$problem, i$enc, i$base))
# html_tables css bad
p("tables css NA", tr(html_tables(html_parse("<table>"), css = NA))); p("tables css bad", tr(html_tables(html_parse("<table>"), css = "table:hover")))
# as.character on doc / nodeset zero
p("as.character ns0", as.character(ps[0])); p("unlist(lapply)", unlist(lapply(ps[1:2], html_text)))
# html_elements on fragment vs doc-node; :root in fragment
f <- html_fragment("<p>a</p><p>b</p>"); p("frag elements", length(html_elements(f, "p"))); p("frag root elems", length(html_elements(html_root(f), "p"))); p("frag :root", length(html_elements(f, ":root"))); p("frag links", nrow(html_links(f))); p("frag title", html_title(f)); p("frag serialize", html_serialize(f)); p("frag md", html_markdown(f)); p("frag text clean", html_text_clean(f))
