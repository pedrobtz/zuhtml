source("pre.R")
d0 <- html_parse("<p>x<!--f-->y<!--g-->z</p>", comments = FALSE)
d2 <- html_parse("<p>xyz</p>")
cat(html_info(d0)$nodes, html_info(d2)$nodes, "\n")
print(html_strings(html_element(d0, "p"))); print(html_strings(html_element(d2, "p")))
print(html_text(html_element(d0,"p"), recursive = FALSE))
cat(html_text_clean(html_parse("<p>a <!--c--> b</p>", comments=FALSE)), "|", html_text_clean(html_parse("<p>a <!--c--> b</p>")), "|\n")
print(html_strings(html_parse("<p>a <!--c--> b</p>", comments=FALSE)))
print(html_markdown(html_parse("<p>x<!--f-->y</p>", comments=FALSE)))
# template + comments
d <- html_parse("<template><!--a-->x<!--b-->y</template>", comments=FALSE)
print(html_info(d)$nodes); cat(html_serialize(d), "\n")
# fragments: every context
tags <- c("div","p","span","table","tbody","thead","tfoot","tr","td","th","caption","colgroup","col","select","option","optgroup","template","html","head","body","title","textarea","script","style","noscript","plaintext","xmp","iframe","noembed","noframes","svg","math","frameset","ul","li","pre","a","button","form","br","img","input","DIV","foreignObject","mi","annotation-xml","desc","x-custom","")
src <- "<tr><td>1</td></tr><p>a&amp;b</p><option>o<li>l<col><b>x"
for (t in tags) { v <- try_(html_fragment(src, t)); cat(sprintf("%-15s", t), if (inherits(v,"err")) paste("ERR", v$cls[1], v$msg) else paste(html_info(v)$context, "|", html_serialize(v)), "\n") }
