test_that("elements, attributes and text serialize as the spec says", {
  doc <- html_parse("<!DOCTYPE html><p class=a id=\"b\">One<br>Two")
  expect_identical(
    html_serialize(doc),
    paste0("<!DOCTYPE html><html><head></head><body>",
           "<p class=\"a\" id=\"b\">One<br>Two</p></body></html>")
  )
})

test_that("text is escaped: &, <, > and no-break space", {
  doc <- html_parse("<p>a &amp; b &lt;c&gt; d e \"q\" 'r'</p>")
  p <- html_children(body_of(doc))
  expect_identical(html_serialize(p, outer = FALSE),
                   "a &amp; b &lt;c&gt; d&nbsp;e \"q\" 'r'")
})

test_that("attribute values escape &, \", <, > and no-break space", {
  doc <- html_parse("<p title='a&amp;b \"c\" <d> e f &#39;'></p>")
  expect_identical(
    html_serialize(html_children(body_of(doc))),
    "<p title=\"a&amp;b &quot;c&quot; &lt;d&gt; e&nbsp;f '\"></p>"
  )
})

test_that("raw-text elements are not escaped", {
  doc <- html_parse(paste0(
    "<script>if (a < b && c) x = '&amp;';</script>",
    "<style>p > a { content: \"&\" }</style><textarea>a<b>&amp;</textarea>"
  ))
  out <- html_serialize(doc)
  expect_match(out, "<script>if (a < b && c) x = '&amp;';</script>",
               fixed = TRUE)
  expect_match(out, "<style>p > a { content: \"&\" }</style>", fixed = TRUE)
  # textarea is escapable raw text: parsed as text, serialized escaped.
  expect_match(out, "<textarea>a&lt;b&gt;&amp;</textarea>", fixed = TRUE)
})

test_that("void elements have no end tag", {
  doc <- html_parse("<p>a<br>b<img src=x><input></p><hr>")
  expect_identical(
    html_serialize(body_of(doc), outer = FALSE),
    "<p>a<br>b<img src=\"x\"><input></p><hr>"
  )
})

test_that("comments, doctypes and template contents", {
  doc <- html_parse(paste0(
    "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01//EN\">",
    "<!-- top --><template><td>x</td></template>"
  ))
  expect_identical(
    html_serialize(doc),
    paste0("<!DOCTYPE html><!-- top --><html><head><template><td>x</td>",
           "</template></head><body></body></html>")
  )
})

test_that("foreign content keeps names, namespaced attributes and PIs", {
  doc <- html_parse(paste0(
    "<svg viewBox='0 0 1 1'><foreignObject><p>x</p></foreignObject>",
    "<a xlink:href='u' xml:lang='en'/><?pi data?></svg>"
  ))
  expect_identical(
    html_serialize(html_children(body_of(doc))),
    paste0("<svg viewBox=\"0 0 1 1\"><foreignObject><p>x</p></foreignObject>",
           "<a xlink:href=\"u\" xml:lang=\"en\"></a><?pi data?></svg>")
  )
})

test_that("outer and inner serialization, vectorized, NA for missing", {
  doc <- html_parse("<p>1</p><p><b>2</b></p>")
  p <- html_children(body_of(doc))
  expect_identical(html_serialize(p), c("<p>1</p>", "<p><b>2</b></p>"))
  expect_identical(html_serialize(p, outer = FALSE), c("1", "<b>2</b>"))
  expect_identical(html_serialize(p[c(1, NA)]), c("<p>1</p>", NA))
  expect_identical(as.character(p), html_serialize(p))
  text <- html_children(p[1], elements_only = FALSE)
  expect_identical(html_serialize(text), "1")
  expect_identical(html_serialize(text, outer = FALSE), "")
  expect_identical(html_serialize(doc), html_serialize(doc, outer = FALSE))
})

test_that("text directly in a raw-text fragment context stays raw", {
  f <- html_fragment("if (a < b) x = '&';", context = "script")
  expect_identical(html_serialize(f), "if (a < b) x = '&';")
  f <- html_fragment("a < b &amp; c", context = "div")
  expect_identical(html_serialize(f), "a &lt; b &amp; c")
})

test_that("serialization is iterative: deep trees do not use the C stack", {
  html <- strrep("<div>", 400)
  doc <- html_parse(html)
  out <- html_serialize(doc)
  expect_identical(nchar(out),
                   nchar("<html><head></head><body></body></html>") +
                     400L * nchar("<div></div>"))
})

test_that("the html5lib fixture subset parses and round-trips", {
  cases <- read_dat(test_path("fixtures", "tree-construction.dat"))
  expect_length(cases, 12L)
  for (case in cases) {
    doc <- parse_dat_case(case)
    expect_identical(tree_lines(doc), case$document, label = case$data)
    again <- parse_dat_case(case, html_serialize(doc))
    expect_identical(tree_lines(again), case$document,
                     label = paste("round trip of", case$data))
  }
})

test_that("html_serialize() validates its arguments", {
  expect_error(html_serialize("<p>"), class = "zuhtml_input_error")
  expect_error(html_serialize(html_parse("<p>"), outer = NA),
               class = "zuhtml_input_error")
})
