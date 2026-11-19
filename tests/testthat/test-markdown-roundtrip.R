# The CommonMark round trip (helper-markdown.R): html_markdown() output
# rendered by commonmark and parsed again keeps the page's text, links,
# images, lists and code, and adds no emphasis.

test_that("a '!' before a link stays text, and ':-:' lines make no table", {
  skip_without_round_trip()
  r <- expect_round_trip('<p>Wow!<a href="u">Click</a></p>')
  expect_length(html_elements(r$back, "img"), 0)
  expect_round_trip('<p>Wow! <a href="u">Click</a> !<a href="v">x</a></p>')
  r <- expect_round_trip("<p>a | b<br>:-: | :-:</p>")
  expect_length(html_elements(r$back, "table"), 0)
  r <- expect_round_trip("<p>a | b<br>| :-: | :-: |</p>")
  expect_length(html_elements(r$back, "table"), 0)
  expect_round_trip("<p>x</p><p>: colon</p><p>| pipe</p>")
})

test_that("adjacent code spans keep their text, and edge spaces stay", {
  skip_without_round_trip()
  r <- round_trip("<p><code>foo</code><code>bar</code></p>")
  expect_identical(html_text_clean(r$back), "foobar")
  expect_identical(html_text_clean(html_elements(r$back, "code")), "foobar")
  expect_round_trip("<p>run<code> ls </code>now</p>")
  expect_round_trip("<p>a<kbd>Ctrl</kbd><kbd> C</kbd>b</p>")
  expect_round_trip("<p>a<code> </code>b <code>x</code> <code>y</code></p>")
  r <- round_trip("<p><code>`a</code><code>b`</code></p>")
  expect_identical(html_text_clean(html_elements(r$back, "code")), "`ab`")
})

test_that("nested and adjacent emphasis leaves no literal asterisks", {
  skip_without_round_trip()
  cases <- c(
    "<p><i><b>A</b>x<b>B</b>y</i></p>",
    "<p><i><i>a</i></i></p>",
    "<p><i><b>a</b></i><b>c</b></p>",
    "<p><b>Note: <i>this</i></b> x</p>",
    "<p><b><i>both</i></b></p>",
    "<p>a<b>b<i>c</i>d</b>e</p>",
    "<p><b>x<i>y<b>z</b></i></b></p>",
    "<p><i>a<b>b<p>c</p>d</b></i></p>"
  )
  for (html in cases) {
    r <- expect_round_trip(html)
    expect_styles_kept(r)
  }
})

test_that("list numbering survives reversed lists and empty items", {
  skip_without_round_trip()
  expect_identical(md("<ol reversed><li>a<li>b<li>c</ol>"),
                   "3. a\n2. b\n1. c")
  r <- expect_round_trip("<ol reversed><li>a<li>b<li>c</ol>")
  expect_identical(html_attr(html_element(r$back, "ol"), "start"), "3")
  r <- expect_round_trip("<ol reversed><li>a<li> <li>c</ol>")
  expect_identical(html_attr(html_element(r$back, "ol"), "start"), "2")
  expect_round_trip("<ul><li>a<ol><li></li><li>b</li></ol></li></ul>")
  expect_round_trip("<ul><li>a<ol><li value=4>b</li></ol></li></ul>")
  expect_round_trip("<ul><li>a<ol start=3><li></li><li>b</li></ol></li></ul>")
  r <- expect_round_trip("<ol start=-2><li>a<li>b</ol>")
  expect_identical(html_attr(html_element(r$back, "ol"), "start"), "0")
})

test_that("a block inside <pre> keeps its line break", {
  skip_without_round_trip()
  for (html in c("<pre><div>a</div>b</pre>",
                 "<pre>x<div>a</div><div>b</div>y</pre>",
                 "<pre><span><p>a</p></span>b<p>c</p></pre>")) {
    r <- expect_round_trip(html)
    expect_identical(html_text_clean(html_element(r$back, "pre")),
                     html_text_clean(html_element(r$src, "pre")))
  }
})

test_that("pipe tables order rows as html_table() does", {
  skip_without_round_trip()
  rows <- function(doc) {
    unname(as.matrix(html_table(html_element(doc, "table"), header = FALSE)))
  }
  for (html in c(
    "<table><tfoot><tr><td>f</tfoot><tr><td>b</table>",
    "<table><tbody><tr><td>b</tbody><thead><tr><th>h</thead></table>",
    paste0("<table><caption>c</caption><tfoot><tr><td>f</tfoot>",
           "<tr><td>b1</tr><tbody><tr><td>b2</tbody>",
           "<thead><tr><th>h</thead></table>")
  )) {
    r <- round_trip(html)
    expect_identical(rows(r$back), rows(r$src), label = r$md)
  }
})

test_that("adjacent lists of one kind stay separate", {
  skip_without_round_trip()
  expect_round_trip("<ul><li>a</ul><ul><li>b</ul><ul><li>c</ul>")
  expect_round_trip("<ol><li>a</ol><ol><li>b</ol>")
  expect_round_trip("<ul><li>a</ul><p> </p><ul><li>b</ul>")
  expect_round_trip("<ul><li>a</ul><ul><li></li></ul><ul><li>b</ul>")
  expect_round_trip("<ul><li>x<ul><li>a</ul><ul><li>b</ul></ul>")
  expect_round_trip("<ul><li>a</ul><ol><li>b</ol><ul><li>c</ul>")
})

test_that("random inline trees survive the round trip", {
  skip_without_round_trip()
  withr::local_seed(20261118)
  words <- c("a", "b", "word", "x1", ".", ",", "!", "(", ")", "*", "_",
             "-", ":", "[", "]", "`", "#", "|", "é")
  gen <- function(depth) {
    n <- sample(1:3, 1)
    parts <- character(n)
    for (i in seq_len(n)) {
      pick <- if (depth >= 3) 1L else sample(1:6, 1)
      text <- paste(sample(words, sample(1:3, 1), replace = TRUE),
                    collapse = sample(c("", " "), 1))
      parts[i] <- switch(
        pick,
        text,
        paste0(sample(c("", " "), 1), text, sample(c("", " "), 1)),
        {
          tag <- sample(c("em", "i"), 1)
          paste0("<", tag, ">", gen(depth + 1), "</", tag, ">")
        },
        {
          tag <- sample(c("strong", "b"), 1)
          paste0("<", tag, ">", gen(depth + 1), "</", tag, ">")
        },
        paste0("<code>", sample(c("", " "), 1), text, "</code>"),
        if (depth == 0) paste0("<a href='u", i, "'>", gen(depth + 1), "</a>")
        else text
      )
    }
    paste(parts, collapse = "")
  }
  for (k in 1:60) {
    html <- paste0("<p>", gen(0), "</p>")
    r <- round_trip(html)
    expect_identical(html_text_clean(r$back), html_text_clean(r$src),
                     label = paste(html, "->", r$md))
    expect_styles_kept(r)
  }
})

test_that("a rule opening a list item keeps the list (#133)", {
  skip_without_round_trip()
  expect_round_trip("<ul><li><hr><ul><li>n</ul></ul>")
  expect_round_trip("<ul><li><ul><li><hr></ul></ul>")
  expect_round_trip("<ul><li>a</ul><ul><li><hr><li>b</ul>")
  expect_round_trip("<blockquote><ul><li><hr></ul></blockquote>")
})

test_that("link text with ']:' in code is no reference definition (#133)", {
  skip_without_round_trip()
  expect_round_trip("<p><a href=u><code>]:</code></a></p>")
  expect_round_trip("<p><a href=u><code>]: x</code></a></p>")
  expect_round_trip("<ul><li><a href=u>a<code>]:b</code></a></ul>")
})

test_that("a leading '^' in link or image text is no footnote (#133)", {
  skip_without_round_trip()
  expect_round_trip("<p><img src=i.png alt='^baz'></p>")
  expect_round_trip("<p><a href=u>^x</a> <a href=v><i>^.</i>y</a></p>")
})

test_that("an '&' ending a text node makes no entity with the next (#133)", {
  skip_without_round_trip()
  expect_round_trip("<p>&amp;<span>amp;</span></p>")
  expect_round_trip("<p>&amp;<b>#38;</b> x&amp;<i>lt;</i></p>")
})

test_that("':' and '|' at a line start make no table (#127)", {
  skip_without_round_trip()
  for (html in c("<p>a<br>:-</p>", "<p>a<br>|-|</p>", "<p>a | b<br>|:-|-</p>",
                 "<p>:-</p>", "<p>|-|</p>", "<p><code>x</code><br>:-</p>",
                 "<ul><li>a<br>:-</ul>", "<p><b>a</b><br><i>:-</i></p>")) {
    r <- expect_round_trip(html)
    expect_length(html_elements(r$back, "table"), 0)
  }
})
