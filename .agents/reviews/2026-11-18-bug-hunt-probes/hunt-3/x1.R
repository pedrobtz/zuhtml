source("pre.R")
# json_ld: local file read through jsonlite::fromJSON
tf <- tempfile(fileext=".json"); writeLines('{"secret": "from-local-file"}', tf)
d <- html_parse(sprintf('<script type="application/ld+json">%s</script><script type="APPLICATION/LD+JSON ; charset=utf-8"> {"a":1} </script><script type="application/ld+json"><!-- {"b":2} --></script><script type="application/ld+json">//<![CDATA[\n{"c":3}\n//]]></script><script type="application/ld+json">[1,2</script><script type="application/ld+json"></script><svg><script type="application/ld+json">{"svg":1}</script></svg><script type="application/ld+jsonx">{}</script><template><script type="application/ld+json">{"t":1}</script></template>', tf))
print(html_json_ld(d)); str(html_json_ld(d, parse=TRUE))
unlink(tf)
# metadata
tt <- function(h) cat(sprintf("%-80s => %s\n", h, encodeString(html_title(html_parse(h)), quote='"', na.encode=FALSE)))
tt("<svg><title>S</title></svg><title> a \n b </title><title>second</title>"); tt("<body><svg><title>S</title></svg><p>x"); tt("<title></title>"); tt("<body><title>in body</title>"); tt("<title>a&nbsp;b \u00a0 c</title>"); tt("<template><title>T</title></template>"); tt("<title>a<b>b</b></title>"); tt("<frameset><title>fs</title></frameset>")
print(html_title(html_fragment("<title>frag</title>"))); print(html_title(html_elements(html_parse("<title>x</title><p>"), "p")))
print(html_meta(html_parse('<meta charset=utf-8><meta NAME="Description" CONTENT="d&amp;e"><meta property="og:title" content><meta http-equiv=refresh content="0;url=x"><body><meta name=inbody content=1><svg><meta name=svgm content=2></svg><template><meta name=t></template>')))
print(html_meta(html_elements(html_parse('<meta name=a content=1><meta name=b>'), "meta")[c(2,1,1)]))
# microdata
md <- function(h, base=NULL) str(html_microdata(if (is.null(base)) html_parse(h) else html_parse(h, base_url=base)))
md('<div itemscope itemtype="  http://s/A  http://s/A http://s/B " itemid="x"><a itemprop="url">no href</a><a itemprop="u2" href="">empty</a><a itemprop="u3" href="p q">bad</a><img itemprop=img><span itemprop="a b a">v</span><meta itemprop=m><time itemprop=t datetime="2020">x</time><time itemprop=t2>y</time><data itemprop=d value=5>five</data><meter itemprop=me>z</meter><div itemscope><span itemprop=inner>not mine</span></div><div itemprop=child itemscope><span itemprop=n>N</span></div><span itemprop="">emptyname</span></div>', "http://b/dir/")
md('<div itemscope itemref="r1 r2 missing r1" id=top><span itemprop=own>o</span></div><p id=r1><span itemprop=ref1>R1</span><span itemscope itemprop=sub><span itemprop=deep>D</span></span></p><span id=r2 itemprop=self>S</span><div id=r1><span itemprop=dupid>X</span></div>')
md('<div itemscope id=a itemref="a b"><div id=b itemprop=loop itemscope itemref=a><span itemprop=x>1</span></div></div>')
md('<div itemscope itemprop=orphan><span itemprop=x>1</span></div>')
# forms
ff <- function(h, base=NULL) { f <- html_forms(if (is.null(base)) html_parse(h) else html_parse(h, base_url=base)); for (x in f) { cat("-- action:", x$action, "method:", x$method, "enctype:", x$enctype, "id:", x$id, "\n"); print(x$fields[, 1:5]); for (o in x$fields$options) if (!is.null(o)) print(o) } }
ff('<form action="go" method=PoSt enctype="MULTIPART/FORM-DATA" id=f1><input name=a><input type=CHECKBOX name=c><input type=radio name=r value=1 checked><input type=bogus name=b value=v><input type=hidden name=h value=H><textarea name=t>\n x\n</textarea><button name=bt value=B>go</button><button type=reset>r</button><select name=s size=5><option>a<option>b</select><select name=s2><option disabled>d<option value="">e<optgroup disabled><option selected>g</optgroup></select><select name=s3 multiple><option selected>a<option selected>b</select><select name=s4><option selected>a<option selected>b</select><select name=s5></select><fieldset disabled><legend><input name=inlegend></legend><legend><input name=inlegend2></legend><input name=infs></fieldset><input name=file type=file value="C:\\x"><input type=image name=img></form><input form=f1 name=outside><input form="" name=noform><input form=nope name=nope><input name=orphan>', "http://b/d/")
ff('<table><form action=x><tr><td><input name=a></td></tr></form><tr><td><input name=b><table><tr><td><input name=nested></table></td></tr></table><input name=after><form id=second><input name=z></form>')
ff('<form><input name=a><form><input name=b></form><input name=c></form><input name=d>')
ff('<svg><form><input name=svgin></form></svg><form action="ht tp://bad"><input name=x></form><form action=""></form><form action="?q"></form>')
ff('<form action=x><input name=a></form>')
# lists
l <- function(h, ...) { d <- html_parse(h); print(try_(html_list(html_element(d, "ul, ol"), ...))) }
l("<ul><li>a<b>b</b> c<li>d<ul><li>e<li>f<ol><li>g</ol></ul>tail<li><div><ul><li>wrapped</ul></div><li></li><li> <ul><li>only child</ul></ul>")
l("<ul><li>a<li>d<ul><li>e<li>f<ol><li>g</ol></ul>tail<li><div><ul><li>wrapped</ul><ol><li>w2</ol></div></ul>", mode="tree")
l("<ul>text<li>a</li><div><li>in div</li></div><p>p</p><ul><li>direct nested</ul><li>b<table><tr><td><ul><li>in table</ul></table></ul>")
l("<ol start=5 reversed><li value=3>a<li>b</ol>"); l("<ul></ul>"); l("<ul><li>a</ul>", mode="x"); print(try_(html_list(html_parse("<ul><li>a</ul>")))); print(try_(html_list(html_elements(html_parse("<ul><li>a</ul><ul><li>b</ul>"), "ul")))); print(try_(html_list(html_element(html_parse("<menu><li>a</menu>"), "menu")))); print(try_(html_list(html_element(html_parse("<dl><dt>a</dl>"), "dl"))))
