source("pre.R")
d <- html_parse("<div><p id=a>x</p></div>")
for (n in c(127,128,129)) cat(n, "compounds:", sel(d, paste(rep("*", n), collapse=" ")) |> substr(1,90), "\n")
for (n in c(31,32,33)) cat(n, "nots:", substr(sel(d, paste0("p", strrep(":not(", n), "div", strrep(")", n))), 1, 110), "\n")
for (n in c(16383,16384,16385)) cat(n, "len:", substr(sel(d, paste0("p", strrep(" ", n-1))), 1, 100), "\n")
cat(substr(sel(d, paste0(strrep("p,", 5000), "p")),1,80), "\n")
cat(sel(d, "div p:nth-child(1)  ,  #a.x , :not(p) > p"), "\n")
cat(sel(d, "p:nth-child(2n+1 )"), sel(d, "p:nth-child( -n+ 1)"), sel(d, "p:nth-child(- n+1)"), sel(d,"p:nth-child(n-0)"), sel(d,"p:nth-child(1n)"), sel(d, "p:nth-child(+1n+0)"), sel(d, "p:nth-child(-1)"),"\n")
# error position late
e <- tryCatch(html_elements(d, "div > p.a[b=c]:nth-child(2n+1) ~ é:hover"), error=function(e) e); str(unclass(e)[c("position","reason","unsupported","selector")])
e <- tryCatch(html_elements(d, "ééé >> p"), error=function(e) e); str(unclass(e)[c("position","reason","unsupported")])
e <- tryCatch(html_elements(d, "p\n\t, [a=b c]"), error=function(e) e); str(unclass(e)[c("position","reason","unsupported")])
# attrs
a <- html_parse('<p ID=1 id=2 Class="a  b\ta" data-X="&amp;&#39;" empty="" bare><svg viewBox=1 VIEWBOX=2 xlink:href=h></svg>')
print(html_attrs(html_elements(a, "p, svg"))); print(html_classes(html_elements(a, "p, svg"))); print(html_attr(html_elements(a, "p, svg"), "ID")); print(html_attr(html_elements(a, "p, svg"), "viewbox")); print(html_attr(html_elements(a, "p, svg"), "viewBox")); print(html_attr(html_elements(a,"p"), c("bare"))); print(html_attr(html_elements(a,"p"), "nope", default="D")); print(try_(html_attr(html_elements(a,"p, svg"), c("id","viewBox")))); print(html_attr(html_elements(a,"svg"), "href")); print(html_attr(html_elements(a,"svg"), "xlink:href")); print(html_attr(html_elements(a,"svg"), "XLINK:HREF"))
# tables: nested, html_tables, match, cells links, convert
t <- html_parse('<base href="http://b/"><table id=o><tr><td>out <a href="x">l1</a><table id=i><tr><td>in <a href="y">l2</a></table><a href="z">l3</a><td><area href="w"><a>nohref</a></table><table id=t2><tr><th>n<th>l<th>m<th>z<th>g<tr><td>1<td>TRUE<td>1,5<td>007<td>1,234<tr><td>-2e3<td>false<td>2<td>1<td>12,345,678<tr><td> 3.5 <td><td>x<td>2<td>999</table>')
print(length(html_tables(t))); print(html_tables(t, css="#i")); print(length(html_tables(t, match="in"))); print(length(html_tables(html_elements(t, "table"))));  print(length(html_tables(html_elements(t, "#i")))); print(length(html_tables(t, match="[")) |> try_())
print(html_table_cells(html_element(t, "#o"))); print(html_table_cells(html_element(t, "#o"), absolute=TRUE)$links)
str(html_table(html_element(t, "#t2"), convert=TRUE)); str(html_table(html_element(t, "#t2"), convert=TRUE, thousands=","))
str(html_table(html_element(t, "#t2"), convert=TRUE, decimal=",", thousands="."))
cv <- function(v, ...) { h <- paste0("<table>", paste0("<tr><td>", v, collapse=""), "</table>"); r <- html_table(html_element(html_parse(h), "table"), header=FALSE, convert=TRUE, ...)[[1]]; cat(sprintf("%-40s => %s %s\n", paste(v, collapse="|"), class(r), paste(format(r, digits=17), collapse=" "))) }
cv(c("1","2")); cv(c("1","")); cv(c("1","NA")); cv(c("1","NA"), na="NA"); cv(c("2147483647","1")); cv(c("2147483648","1")); cv(c("-2147483648")); cv(c("1e5")); cv(c("1E400")); cv(c(".5","5.")); cv(c("+1","-1")); cv(c("0","00")); cv(c("0.5","-0.5","-0")); cv(c("1 234"), thousands=" "); cv(c("1,234","12,34"), thousands=","); cv(c("0,123"), thousands=","); cv(c("1,234.5","1,23"), thousands=","); cv(c("1.234,5"), decimal=",", thousands="."); cv(c("1.5"), decimal=","); cv(c("1,5","2"), decimal=","); cv(c("TRUE","false","True")); cv(c("T","F")); cv(c("true","1")); cv(c("1","1 000"), thousands=" "); cv(c("１２")); cv(c("Inf","NaN")); cv(c("0x10")); cv(c("1e","e1")); cv(c("1,,234"), thousands=","); cv(c(",234"), thousands=","); cv(c("1234,567"), thousands=","); cv(c("1.5.2")); cv(c("1e3"), decimal=","); cv(c("−1")); cv(c("12345678901234567890")); cv(c("1_000")); cv(c("1e+05", "1E-2")); cv("1,234e2", thousands=","); cv(c("TRUE", ""), na=""); cv(c("", "")); cv(c("-", "1")); cv(c("1.0", "2.50"), decimal=".", thousands=NULL); cv("1^5", thousands="^"); cv("1\\234", thousands="\\"); cv("1]234", thousands="]"); cv("1[234", thousands="["); cv("1-234") 
print(try_(html_table(html_element(t, "#t2"), convert=TRUE, decimal="e"))); print(try_(html_table(html_element(t, "#t2"), convert=TRUE, decimal=".", thousands=".")))
