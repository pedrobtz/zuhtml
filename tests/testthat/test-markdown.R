test_that("html_markdown() writes headings, paragraphs and breaks", {
  expect_identical(
    md("<h1>Title</h1><p>One\n  two.</p><h3>Sub <i>it</i></h3><hr><p>x"),
    "# Title\n\nOne two.\n\n### Sub *it*\n\n---\n\nx"
  )
  expect_identical(md("<h6>six</h6>"), "###### six")
  expect_identical(md("<a href=u><h3>linked</h3><p>teaser</a>"),
                   "### [linked](u)\n\n[teaser](u)")
  expect_identical(md("<p>a<br>b<br><br>c<br></p><p><br>d"),
                   "a\\\nb\\\n\\\nc\n\nd")
  # A heading stays on one line, and its '#' is escaped.
  expect_identical(md("<h2>a<br>b # c<p>d</p></h2>"), "## a b \\# c d")
  expect_identical(md("<div><div>a</div></div><section>b</section>"),
                   "a\n\nb")
  expect_identical(md("<p></p><h1> </h1><p>  </p>"), "")
})

test_that("html_markdown() writes inline markup lazily", {
  expect_identical(md("<p>a <b> bold </b>c"), "a **bold** c")
  expect_identical(md("<p>a<em></em>b<strong> </strong>c"), "ab c")
  expect_identical(md("<p><b><i>both</i></b>"), "***both***")
  # Markup around blocks is closed and reopened in each block.
  expect_identical(md("<b><p>one</p><p>two</p></b>"), "**one**\n\n**two**")
  expect_identical(md("<p>use <code>x &lt;- `y`</code> or <kbd>C-c</kbd>"),
                   "use `` x <- `y` `` or `C-c`")
  expect_identical(md("<p><code>`a</code> <code>\n </code>"), "`` `a ``")
  expect_identical(md("<p>x<code>a\n  b</code>"), "x`a b`")
})

test_that("html_markdown() writes only emphasis that CommonMark parses", {
  # Adjacent emphasis of one kind continues.
  expect_identical(md("<p><em>a</em><em>, b</em> <b>c</b><b>d</b>"),
                   "*a, b* **cd**")
  # No-break spaces collapse, so delimiters do not end up next to them.
  expect_identical(md("<p><b>&nbsp;Post </b>&nbsp;x"), "**Post** x")
  # An opener between a letter and punctuation, or before Unicode
  # whitespace, cannot open.
  expect_identical(md("<p>word<i>.</i> <b>\u3000x</b>"), "word. \u3000x")
  # A closer between punctuation and a letter cannot close.
  expect_identical(md("<p><em>\u00ab</em>Quand <em>a.</em> b"),
                   "\u00abQuand *a.* b")
  expect_identical(md("<p><b>x.</b>y <i>z</i><b>w</b>"), "x.y *z*w")
})

test_that("html_markdown() fences <pre> with the right fence and language", {
  expect_identical(md("<pre>a\n  b\n\nc</pre>"), "```\na\n  b\n\nc\n```")
  expect_identical(
    md("<pre><code class='language-r'>x <- 1\n```\n</code></pre>"),
    "````r\nx <- 1\n```\n````"
  )
  expect_identical(md("<pre class='lang-sh'>ls</pre>"), "```sh\nls\n```")
  expect_identical(md("<pre></pre>"), "```\n```")
  expect_identical(md("<pre>a<br>b<b>c</b></pre>"), "```\na\nbc\n```")
  expect_identical(md("<pre><div>a</div><div>b</div></pre><pre>c<p>d</pre>"),
                   "```\na\nb\n```\n\n```\nc\nd\n```")
  expect_identical(md("<p>before<pre>*raw* [text]</pre>after"),
                   "before\n\n```\n*raw* [text]\n```\n\nafter")
})

test_that("html_markdown() nests lists and quotes", {
  expect_identical(md("<ul><li>a<li>b</ul>"), "- a\n- b")
  expect_identical(
    md("<ol start=9><li>nine<li>ten<p>more</p></ol>"),
    "9. nine\n10. ten\n\n    more"
  )
  expect_identical(md("<ol reversed start=3><li>c<li>b<li value=7>x<li>y</ol>"),
                   "3. c\n2. b\n7. x\n6. y")
  expect_identical(md("<ul><li>a<ul><li>b<ol><li>c</ol></ul>tail<li>d</ul>"),
                   "- a\n  - b\n    1. c\n\n  tail\n- d")
  # An empty item is left out: a bare "-" under text would be a heading
  # underline.
  expect_identical(md("<ul><li>a<ul><li></li><li> </ul></li><li>x</ul>"),
                   "- a\n- x")
  expect_identical(md("<ul><li>a<ol start=3><li>c</ol></ul>"),
                   "- a\n\n  3. c")
  expect_identical(
    md("<blockquote><p>q</p><blockquote>inner</blockquote><ul><li>i</ul></blockquote><p>out"),
    "> q\n>\n> > inner\n>\n> - i\n\nout"
  )
  expect_identical(md("<ul><li><pre>a\n\nb</pre></ul>"),
                   "- ```\n  a\n\n  b\n  ```")
  expect_identical(md("<p>x<ul><li>y</ul>z"), "x\n\n- y\n\nz")
  expect_identical(md("<li>orphan</li>"), "- orphan")
})

test_that("html_markdown() resolves link and image URLs", {
  doc <- html_parse(paste0(
    "<base href='/root/'><p><a href='a b.html'>A</a> ",
    "<a href='u(1)'>paren</a> <a>no href</a> <a href='x'></a>",
    "<img src='i.png' alt=' An [image] '> <img alt=gone>",
    "<a href='https://x.test/'><img src='//cdn.test/l.png' alt=logo></a>"
  ), base_url = "https://site.test/docs/page.html")
  # "a b.html" is not a valid reference, so it is kept, encoded.
  expect_identical(
    html_markdown(doc),
    paste0(
      "[A](a%20b.html) ",
      "[paren](https://site.test/root/u\\(1\\)) no href ",
      "![An \\[image\\]](https://site.test/root/i.png) ",
      "[![logo](https://cdn.test/l.png)](https://x.test/)"
    )
  )
  # Without a base URL, relative references are kept as written.
  expect_identical(md("<a href='../up'>up</a>"), "[up](../up)")
  expect_identical(md("<a href=''>empty</a>"), "[empty]()")
})

test_that("html_markdown() escapes Markdown in text", {
  expect_identical(
    md("<p>*a* _b_ snake_case [c] `d` &lt;e> \\ a|b ~x &amp;copy; & y"),
    "\\*a\\* \\_b\\_ snake_case \\[c\\] \\`d\\` \\<e\\> \\\\ a|b \\~x \\&copy; & y"
  )
  expect_identical(md("<p>1. one</p><p>2) two</p><p>12 3. x</p>"),
                   "1\\. one\n\n2\\) two\n\n12 3. x")
  expect_identical(md("<p># h</p><p>- d</p><p>+ p</p><p>= e</p><p>> q"),
                   "\\# h\n\n\\- d\n\n\\+ p\n\n\\= e\n\n\\> q")
  expect_identical(md("<p>a<br>- b"), "a\\\n\\- b")
  expect_identical(md("<ul><li>- x</ul>"), "- \\- x")
  expect_identical(md("<p>a # b - c"), "a # b - c")
})

test_that("html_markdown() writes simple tables as pipe tables", {
  expect_identical(
    md(paste0(
      "<table><caption>Prices</caption><thead><tr><th>Item<th>Cost</thead>",
      "<tbody><tr><td><b>Tea</b> | hot<td>3<tr><td>Cake</tbody></table>"
    )),
    paste0(
      "Prices\n\n| Item | Cost |\n| --- | --- |\n",
      "| **Tea** \\| hot | 3 |\n| Cake |  |"
    )
  )
  expect_identical(md("<table><tr><td>x<br>y<td><code>z</code></table>"),
                   "| x y | `z` |\n| --- | --- |")
  expect_identical(md("<b>bold<table><tr><td>in</table></b>"),
                   "**bold**\n\n| **in** |\n| --- |")
  expect_identical(md("<blockquote><table><tr><td>q</table></blockquote>"),
                   "> | q |\n> | --- |")
  expect_identical(md("<table><tr><td><a href='a|b'>l</a></table>"),
                   "| [l](a%7Cb) |\n| --- |")
})

test_that("html_markdown() falls back to text for complex tables", {
  expect_identical(
    md("<table><tr><td colspan=2>wide<tr><td>a<td>b</table>"),
    "wide\n\na b"
  )
  expect_identical(
    md("<table><tr><td>out<td><table><tr><td>in</table></table>"),
    "out\n\n| in |\n| --- |"
  )
  expect_identical(md("<table><tr><td rowspan=0>r<td>x</table>"), "r x")
  expect_identical(
    md("<table></table><table><tr></tr></table><table><tr><td> </table>"),
    ""
  )
  # Blocks in cells make a layout table: its content is written as usual.
  expect_identical(
    md(paste0("<table><tr><td><h2>News</h2><ul><li>a<li>b</ul>",
              "<td><p>x<br>y</p><pre>z</pre></table>")),
    "## News\n\n- a\n- b\n\nx\\\ny\n\n```\nz\n```"
  )
})

test_that("html_markdown() skips what html_text_clean() skips", {
  doc <- html_parse(paste0(
    "<head><title>T</title><style>p{}</style></head><body>",
    "<script>x()</script><!-- c --><template><p>t</p></template>",
    "<svg><title>icon</title></svg><iframe>raw</iframe><p>kept</p></body>"
  ))
  expect_identical(html_markdown(doc), "kept")
  expect_identical(md("<p>news<svg><title>Live</title></svg>on"), "news on")
})

test_that("html_markdown() is aligned and handles node types", {
  doc <- html_parse("<!DOCTYPE html><p>a *b*</p><!-- c --><ul><li>i</ul>")
  p <- html_element(doc, "p")
  expect_identical(html_markdown(p), "a \\*b\\*")
  expect_identical(html_markdown(html_children(p, elements_only = FALSE)),
                   "a \\*b\\*")
  li <- html_element(doc, "li")
  expect_identical(html_markdown(li), "- i")
  kids <- html_children(doc, elements_only = FALSE)
  expect_identical(html_markdown(kids[1]), NA_character_)
  expect_identical(html_markdown(html_element(doc, "table")), NA_character_)
  expect_identical(html_markdown(html_elements(doc, "p, li")),
                   c("a \\*b\\*", "- i"))
  frag <- html_fragment("<b>x</b> y")
  expect_identical(html_markdown(frag), "**x** y")
})
