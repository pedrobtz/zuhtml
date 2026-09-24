test_that("whitespace collapses and the ends are trimmed", {
  expect_identical(clean("<p>  a \t\n b   c  </p>"), "a b c")
  expect_identical(clean("<p>  a  </p>", trim = FALSE), " a ")
  expect_identical(clean(""), "")
})

test_that("inline elements join without separators", {
  expect_identical(clean("<p>a<b>b</b><i>c</i> d</p>"), "abc d")
})

test_that("block elements and <br> are line breaks", {
  expect_identical(clean("<div>a</div><div>b</div>"), "a\nb")
  expect_identical(clean("<p>a</p><p>b</p><h1>c</h1>"), "a\nb\nc")
  expect_identical(clean("<p>a<br>b<br><br>c</p>"), "a\nb\n\nc")
  expect_identical(clean("<div><div><p>a</p></div></div><p>b</p>"), "a\nb")
  expect_identical(clean("<ul><li>1</li><li>2</li></ul>"), "1\n2")
  expect_identical(clean("<br><p>a</p><br>"), "a")
})

test_that("table cells are separated by a space, rows by a line break", {
  expect_identical(clean("<table><tr><td>a<td>b<tr><td>c<td>d</table>"),
                   "a b\nc d")
})

test_that("non-breaking spaces fold into whitespace unless nbsp = FALSE", {
  expect_identical(clean("<p>a&nbsp;&nbsp; b</p>"), "a b")
  expect_identical(clean("<p>a&nbsp;b</p>", nbsp = FALSE), "a b")
  expect_identical(clean("<pre>a&nbsp;b</pre>"), "a b")
})

test_that("preformatted text keeps its whitespace", {
  expect_identical(clean("<pre>  a\n    b  </pre>"), "  a\n    b  ")
  expect_identical(clean("<p>x</p><pre> y </pre><p>z</p>"), "x\n y \nz")
  expect_identical(clean("<textarea>\n  t  x</textarea>"), "  t  x")
})

test_that("script, style, template and comments are skipped", {
  expect_identical(
    clean(paste0("<p>a<script>x()</script>b<style>p{}</style>c",
                 "<template>t</template><!-- d -->e</p>")),
    "abce"
  )
})

test_that("html_text_clean() is vectorized and keeps missing nodes", {
  doc <- html_parse("<p> 1 </p><p>2</p>")
  p <- html_elements(doc, "p")
  expect_identical(html_text_clean(p[c(2, NA, 1)]), c("2", NA, "1"))
  txt <- html_children(p[1], elements_only = FALSE)
  expect_identical(html_text_clean(txt), "1")
  com <- html_children(html_element(html_parse("<p><!--c--></p>"), "p"),
                       elements_only = FALSE)
  expect_identical(html_text_clean(com), NA_character_)
})

test_that("html_text_clean() validates its flags", {
  doc <- html_parse("<p>")
  expect_error(html_text_clean(doc, trim = NA), class = "zuhtml_input_error")
  expect_error(html_text_clean(doc, nbsp = "yes"),
               class = "zuhtml_input_error")
})
