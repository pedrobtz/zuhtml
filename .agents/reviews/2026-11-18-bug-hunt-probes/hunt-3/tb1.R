source("pre.R")
tb <- function(h, ..., cells=FALSE) { d <- html_parse(h); x <- html_element(d, "table"); cat("----", h, "\n"); r <- try_(html_table(x, ...)); if (is.data.frame(r) && ncol(r) > 20) cat("df", dim(r), "\n") else print(r); if (cells) print(try_(html_table_cells(x))) ; invisible(r)}
tb("<table><tr><th>A<th>B<tr><td>1<td>2</table>", cells=TRUE)
tb("<table><thead><tr><td>A<td>B</thead><tr><td>1<td>2</table>")
tb("<table><tr><td>1<td>2<thead><tr><th>A<th>B</thead><tfoot><tr><td>f1<td>f2</tfoot><tbody><tr><td>3<td>4</tbody><caption>cap</caption></table>", cells=TRUE)
tb("<table><tr><th rowspan=2>A<th colspan=2>B<tr><th>b1<th>b2<tr><td>1<td>2<td>3</table>", cells=TRUE)
tb("<table><tr><th>A<td>1<tr><th>B<td>2</table>")
tb("<table><tr><th>A<th>B<tr><th>C<th>D</table>")
tb("<table><tr><td rowspan=0>a<td>b<tr><td>c<tr><td>d</table>", cells=TRUE)
tb("<table><tr><td rowspan=65535>a<td>b<tr><td>c</table>", cells=TRUE)
tb("<table><tr><td colspan=0>a<td>b<tr><td>c</table>")
tb("<table><tr><td colspan=1000>a<td>b</table>", header=FALSE) -> r; print(dim(r))
tb("<table><tr><td colspan=1001>a<td>b</table>", header=FALSE) -> r; print(dim(r))
tb("<table><tr><td colspan=999>a<td>b</table>", header=FALSE) -> r; print(dim(r))
tb("<table><tr><td colspan=-2>a<td colspan=2.9>b<td colspan=' +2x'>c<td colspan='2 '>d<td colspan='1e3'>e<td colspan=''>f<td colspan=99999999999999999999999>g</table>", header=FALSE) -> r; print(dim(r)); print(html_table_cells(html_element(html_parse("<table><tr><td colspan=-2>a<td colspan=2.9>b<td colspan=' +2x'>c<td colspan='2 '>d<td colspan='1e3'>e<td colspan=''>f<td colspan=99999999999999999999999>g</table>"),"table"))[,1:7])
tb("<table><tr><td rowspan=2>a<td>b<tr><td colspan=2>c</table>", cells=TRUE)
tb("<table><tr><td>a<td rowspan=2>b<tr><td colspan=2>c</table>")
tb("<table><tr><td>a<td rowspan=2>b<td>x<tr><td>c<td>d<td>e</table>", header=FALSE)
tb("<table><tbody><tr><td rowspan=5>a<td>b</tbody><tbody><tr><td>c<td>d</table>", header=FALSE, cells=TRUE)
tb("<table><tr><td>a<td>b<td>c<tr><td>d</table>", header=FALSE)
tb("<table><tr><td>a<tr><td><td>  <td>&nbsp;</table>", header=FALSE)
tb("<table></table>"); tb("<table><tr></tr></table>", cells=TRUE); tb("<table><thead><tr><th>A</thead></table>", cells=TRUE); tb("<table><tr><th>A</table>")
tb("<table><caption>c</caption><tr><td>x<table><tr><td>in</table>y<td>z</table>", header=FALSE, cells=TRUE)
tb("<table><tr><th>a<th>a<th><th>V1<th>V3<tr><td>1<td>2<td>3<td>4<td>5</table>")
tb("<table><thead><tr><th colspan=2>G<th>Total<tr><th>x<th>y<th>Total</thead><tr><td>1<td>2<td>3</table>")
tb("<table><thead><tr><th>A<th>B</thead><thead><tr><th>C<th>D</thead><tr><td>1<td>2</table>")
tb("<table><tr><td>1<td>2</tr><thead></thead></table>")
tb("<table><tr><td>NA<td>-<td>x</table>", header=FALSE, na=c("NA","-"))
tb("<table><tr><td> a <td> b </table>", header=FALSE, trim=FALSE)
tb("<table><tr><td>a<br>b<td><p>p1<p>p2<td><ul><li>x<li>y</ul></table>", header=FALSE)
tb("<table><tr><td>a<td>b</table>", header=2)
tb("<table><tr><td>a<td>b</table>", header=c(1,1))
tb("<table><tr><td>a<td>b</table>", header=0)
tb("<table><tr><td>a<td>b</table>", header=1.5)
tb("<table><tr><td>a<td>b<tr><td>c<td>d<tr><td>e<td>f</table>", header=c(1,3))
tb("<table><tr><td>a<td>b<tr><td>c<td>d<tr><td>e<td>f</table>", header=c(3,1))
tb("<table><tr><td>a<td>b</table>", header=NA)
tb("<table><tr><td>a<td>b</table>", header="yes")
tb("<table><tr><td>a<td>b</table>", header=c(TRUE,FALSE))
# limits
tb("<table><tr><td colspan=10>a<tr><td>b</table>", header=FALSE, limits=html_limits(max_table_cells=20)) -> r
tb("<table><tr><td colspan=10>a<tr><td>b</table>", header=FALSE, limits=html_limits(max_table_cells=19)) -> r
tb("<table><tr><td>b<tr><td colspan=10>a</table>", header=FALSE, limits=html_limits(max_table_cells=19)) -> r
tb("<table><tr><td>b</table>", header=FALSE, limits=html_limits(max_table_cells=0)) -> r
tb("<table><tr><td>b</table>", header=FALSE, limits=html_limits(max_table_cells=1)) -> r
tb("<table></table>", header=FALSE, limits=html_limits(max_table_cells=0)) -> r
tb("<table><tr><tr><tr></table>", header=FALSE, limits=html_limits(max_table_cells=0)) -> r
e <- tryCatch(html_table(html_element(html_parse("<table><tr><td colspan=10>a<tr><td>b</table>"),"table"), limits=html_limits(max_table_cells=19)), error=function(e) e); str(unclass(e)[-1])
e <- tryCatch(html_table(html_element(html_parse("<table><tr><td>a<td rowspan=2>b<tr><td colspan=2>c</table>"),"table")), error=function(e) e); str(unclass(e)[c("row","cell")])
