test_that("implied elements, text and attributes are all converted", {
  doc <- html_parse("<!DOCTYPE html><title>T</title><p class=a id=b>Hi <b>x")
  expect_identical(tree_lines(doc), c(
    "| <!DOCTYPE html>",
    "| <html>",
    "|   <head>",
    "|     <title>",
    "|       \"T\"",
    "|   <body>",
    "|     <p>",
    "|       class=\"a\"",
    "|       id=\"b\"",
    "|       \"Hi \"",
    "|       <b>",
    "|         \"x\""
  ))
  m <- doc_meta(doc)
  # document, doctype, html, head, title, text, body, p, text, b, text
  expect_identical(m$n_nodes, 11)
  expect_identical(m$n_attrs, 2)
})

test_that("empty input has the implied html, head and body", {
  expect_identical(tree_lines(html_parse("")),
                   c("| <html>", "|   <head>", "|   <body>"))
})

test_that("doctype identifiers are kept", {
  doc <- html_parse(paste0(
    '<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN" ',
    '"http://www.w3.org/TR/html4/strict.dtd"><p>'
  ))
  expect_identical(
    tree_lines(doc)[[1L]],
    paste0('| <!DOCTYPE html "-//W3C//DTD HTML 4.01//EN" ',
           '"http://www.w3.org/TR/html4/strict.dtd">')
  )
})

test_that("quirks mode is recorded", {
  expect_identical(doc_meta(html_parse("<p>"))$quirks_mode, "quirks")
  expect_identical(doc_meta(html_parse("<!DOCTYPE html><p>"))$quirks_mode,
                   "no-quirks")
})

test_that("misnested markup is repaired as the spec says", {
  doc <- html_parse("<!DOCTYPE html><b><i>x</b>y</i>")
  expect_identical(tree_lines(doc)[-(1:4)], c(
    "|     <b>",
    "|       <i>",
    "|         \"x\"",
    "|     <i>",
    "|       \"y\""
  ))
})

test_that("text is foster-parented out of tables", {
  doc <- html_parse("<!DOCTYPE html><table><tr><td>a</td>x</tr></table>")
  expect_identical(tree_lines(doc)[5:6], c("|     \"x\"", "|     <table>"))
})

test_that("comments are kept by default and dropped with comments = FALSE", {
  html <- "<!DOCTYPE html><!-- top --><p>a<!-- in -->b"
  expect_true("|       <!--  in  -->" %in% tree_lines(html_parse(html)))
  lines <- tree_lines(html_parse(html, comments = FALSE))
  expect_false(any(grepl("<!--", lines, fixed = TRUE)))
  # The text either side of the dropped comment stays two nodes.
  expect_identical(lines[length(lines) - c(1L, 0L)],
                   c("|       \"a\"", "|       \"b\""))
})

test_that("template contents are the template's children, flagged", {
  doc <- html_parse("<!DOCTYPE html><template><td>x</td></template>")
  expect_identical(tree_lines(doc)[3:7], c(
    "|   <head>",
    "|     <template>",
    "|       content",
    "|         <td>",
    "|           \"x\""
  ))
})

test_that("foreign content keeps its namespace and case-adjusted names", {
  doc <- html_parse(paste0(
    "<!DOCTYPE html><svg viewBox='0 0 1 1'><foreignobject/><clippath/>",
    "<a xlink:href=u></a></svg><math><mi>x</mi></math>"
  ))
  lines <- tree_lines(doc)
  expect_true(all(c("|     <svg svg>", "|       viewBox=\"0 0 1 1\"",
                    "|       <svg foreignObject>", "|       <svg clipPath>",
                    "|         xlink href=\"u\"", "|     <math math>",
                    "|       <math mi>") %in% lines))
})

test_that("unknown elements keep their lowercased names", {
  lines <- tree_lines(html_parse("<!DOCTYPE html><My-Widget Data-X=1>t"))
  expect_true(all(c("|     <my-widget>", "|       data-x=\"1\"") %in% lines))
})

test_that("character references are decoded", {
  lines <- tree_lines(html_parse("<!DOCTYPE html><p title='&lt;&amp;'>&copy;&#x41;"))
  expect_true(all(c("|       title=\"<&\"", "|       \"©A\"") %in% lines))
})

test_that("max_nodes trips during conversion", {
  html <- strrep("<p>x</p>", 100)
  # html, head, body, the document, and 100 paragraphs with a text node each
  err <- expect_error(html_parse(html, limits = html_limits(max_nodes = 203)),
                      class = "zuhtml_limit_error")
  expect_identical(err$limit, "max_nodes")
  expect_identical(err$observed, 204)
  expect_s3_class(html_parse(html, limits = html_limits(max_nodes = 204)),
                  "zuhtml_document")
})

test_that("an allocation failure during conversion is a clean error", {
  html <- "<!DOCTYPE html><table><tr><td>a<b>b</table><p id=x>&amp;"
  lim <- html_limits()
  input <- zuhtml:::zuh_decode(html, NULL, lim, NULL)
  # Find the allocation count of a complete parse, then fail each of the
  # last few, which are conversion's.
  k <- 1
  repeat {
    res <- tryCatch(
      zuhtml:::zuh_parse_bytes(input$bytes, "UTF-8", NULL, lim, fail_at = k),
      zuhtml_limit_error = function(e) NULL
    )
    if (!is.null(res)) break
    k <- k + 1
  }
  for (j in max(1, k - 6):(k - 1)) {
    expect_error(
      zuhtml:::zuh_parse_bytes(input$bytes, "UTF-8", NULL, lim, fail_at = j),
      class = "zuhtml_limit_error"
    )
  }
})

test_that("the document reports its own memory", {
  m <- doc_meta(html_parse(strrep("<p class=c>text</p>", 50)))
  expect_gt(m$frozen_bytes, 0)
  expect_gt(m$parse_peak_bytes, m$frozen_bytes)
})

test_that("stray and nested <selectedcontent> markup is safe (patches 0004, 0005)", {
  # Gumbo 0.14.0 dereferenced NULL on the first and read freed memory on
  # the second; both crashed the R session.
  doc <- html_parse("<!DOCTYPE html><p>x</selectedcontent>y")
  expect_identical(html_text(body_of(doc)), "xy")
  expect_true("unexpected-end-tag" %in% html_problems(doc)$code)
  doc <- html_parse("<selectedcontent><option>a<option selected>b")
  expect_identical(html_name(html_elements(doc, "selectedcontent option")),
                   c("option", "option"))
})
