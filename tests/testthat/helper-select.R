# One document for the selector tests; each test builds its own copy.
# sel() and nm() are the text and names of the elements a selector finds.
sel_doc <- function() {
  html_parse(paste0(
    "<!DOCTYPE html>",
    "<div id=main class='card wide'>",
    "<h2 id=t1 class=title>One</h2>",
    "<p class='a b' lang=en-US data-x='foo-bar baz'>first</p>",
    "<p class=b title=''>second</p>",
    "<span>s</span>",
    "<p>third</p>",
    "</div>",
    "<ul><li>1<li>2<li>3<li>4<li>5</ul>",
    "<div class=card><h2 class=title>Two</h2><em></em><i> </i><b><!--c--></b></div>",
    "<form><input type=TEXT name=q><input type=checkbox checked></form>"
  ))
}

sel <- function(doc, css) html_text(html_elements(doc, css))
nm <- function(doc, css) html_name(html_elements(doc, css))
