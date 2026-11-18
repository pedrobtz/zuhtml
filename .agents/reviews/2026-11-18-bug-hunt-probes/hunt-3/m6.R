source("pre.R")
norm <- function(s) gsub("[ \n]+", " ", trimws(s))
set.seed(as.integer(commandArgs(TRUE)[1]))
atoms <- c("a","b","word","1.","2)","-","+","#","*","_","[","]","(",")","`","~","|","\\","&amp;","&lt;","&gt;","x_y","http://e.com/a_b","www.e.com","a@b.c","=","==","---",":","1","9"," "," ","  ","\n",".",",","\"","'","&amp;amp;","&amp;#1;","$","^","<br>","é","&nbsp;","](u)","***","__","``","<!--c-->")
inl <- c("span","a","u","del","sub")
gen_inline <- function(depth=0, ban=character()) {
  n <- sample(1:5, 1); out <- character()
  for (k in seq_len(n)) {
    if (depth < 3 && runif(1) < 0.35) {
      t <- sample(setdiff(inl, ban), 1)
      attr <- if (t == "a") sprintf(' href="%s"', sample(c("u","http://e.com/x?a=1&amp;b=2","a b","a(b","a)b","x_y_z","#f","<x>","a\\b","u*v*"),1)) else ""
      out <- c(out, sprintf("<%s%s>%s</%s>", t, attr, gen_inline(depth+1, c(ban, if (t %in% c("b","i","a")) t)), t))
    } else if (runif(1) < 0.05) out <- c(out, '<img src="i.png" alt="al*t">')
    else out <- c(out, sample(atoms, 1))
  }
  paste(out, collapse="")
}
gen_block <- function(depth=0) {
  r <- runif(1)
  if (depth > 2 || r < 0.4) return(sprintf("<p>%s</p>", gen_inline()))
  if (r < 0.5) return(sprintf("<h%d>%s</h%d>", k <- sample(1:6,1), gen_inline(), k))
  if (r < 0.65) return(sprintf("<ul>%s</ul>", paste(replicate(sample(1:3,1), sprintf("<li>%s%s</li>", gen_inline(), if (runif(1)<.4) gen_block(depth+1) else "")), collapse="")))
  if (r < 0.75) return(sprintf("<ol>%s</ol>", paste(replicate(sample(1:3,1), sprintf("<li>%s%s</li>", if (runif(1)<.8) gen_inline() else "", if (runif(1)<.4) gen_block(depth+1) else "")), collapse="")))
  if (r < 0.85) return(sprintf("<blockquote>%s%s</blockquote>", gen_inline(), gen_block(depth+1)))
  if (r < 0.9) return(sprintf("<div>%s%s%s</div>", gen_inline(), gen_block(depth+1), gen_inline()))
  if (r < 0.95) return("<pre>x\n y</pre>")
  sprintf("<table><tr><th>%s</th><th>%s</th></tr><tr><td>%s</td><td>%s</td></tr></table>", gen_inline(), gen_inline(), gen_inline(), gen_inline())
}
nbad <- 0
for (it in 1:1500) {
  h <- paste(replicate(sample(1:3,1), gen_block()), collapse="")
  d <- html_parse(h); md <- html_markdown(d)
  back <- html_parse(commonmark::markdown_html(md, extensions = c("table","strikethrough")))
  d0 <- html_parse(html_serialize(d)); # same
  t0 <- norm(html_text_clean(d)); t1 <- norm(html_text_clean(back))
  l0 <- html_attr(html_elements(d, "a[href]"), "href"); l0 <- l0[nzchar(norm(html_text_clean(html_elements(d, "a[href]")))) | lengths(lapply(seq_along(l0), function(i) html_elements(html_elements(d,"a[href]")[i], "img"))) > 0]
  l1 <- html_attr(html_elements(back, "a[href]"), "href")
  i0 <- length(html_elements(d, "img")); i1 <- length(html_elements(back, "img"))
  bad <- character()
  if (!identical(t0, t1)) bad <- c(bad, "text"); if (!identical(l0, vapply(l1, utils::URLdecode, "", USE.NAMES=FALSE))) bad <- c(bad, "hrefs")
  
  if (i0 != i1) bad <- c(bad, "nimg")
  if (length(bad)) { nbad <- nbad + 1; if (nbad <= 8) cat(sprintf("== %s\nH: %s\nMD: %s\nT0: %s\nT1: %s\n", paste(bad, collapse=","), encodeString(h), encodeString(md), encodeString(t0), encodeString(t1))) }
}
cat("bad:", nbad, "\n")
