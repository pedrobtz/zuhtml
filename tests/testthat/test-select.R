test_that("type and universal selectors", {
  doc <- sel_doc()
  expect_identical(sel(doc, "h2"), c("One", "Two"))
  expect_identical(sel(doc, "H2"), c("One", "Two"))
  expect_identical(nm(doc, "div *")[1:3], c("h2", "p", "p"))
  expect_length(html_elements(doc, "*"), 23L)
})

test_that("id and class selectors are case-sensitive", {
  doc <- sel_doc()
  expect_identical(sel(doc, "#t1"), "One")
  expect_length(html_elements(doc, "#T1"), 0L)
  expect_identical(sel(doc, ".title"), c("One", "Two"))
  expect_identical(sel(doc, "p.a.b"), "first")
  expect_identical(sel(doc, "p.b"), c("first", "second"))
  expect_length(html_elements(doc, ".Title"), 0L)
  expect_identical(nm(doc, "div.card.wide"), "div")
})

test_that("attribute presence and every matcher", {
  doc <- sel_doc()
  expect_identical(sel(doc, "p[title]"), "second")
  expect_identical(sel(doc, "p[title='']"), "second")
  expect_identical(sel(doc, "[data-x='foo-bar baz']"), "first")
  expect_identical(sel(doc, "[data-x~=baz]"), "first")
  expect_length(html_elements(doc, "[data-x~=foo]"), 0L)
  expect_length(html_elements(doc, "[data-x~='a b']"), 0L)
  expect_identical(sel(doc, "[data-x|=foo]"), "first")
  expect_identical(sel(doc, "[lang|=en]"), "first")
  expect_identical(sel(doc, "[data-x^=foo]"), "first")
  expect_identical(sel(doc, "[data-x$=baz]"), "first")
  expect_identical(sel(doc, "[data-x*='bar b']"), "first")
  # Empty values never match the substring matchers.
  expect_length(html_elements(doc, "[title^='']"), 0L)
  expect_length(html_elements(doc, "[title$='']"), 0L)
  expect_length(html_elements(doc, "[title*='']"), 0L)
})

test_that("attribute value case: HTML's list, and the i and s flags", {
  doc <- sel_doc()
  # type is on HTML's case-insensitive list; data-x is not.
  expect_identical(html_attr(html_elements(doc, "[type=text]"), "name"), "q")
  expect_length(html_elements(doc, "[type=text s]"), 0L)
  expect_length(html_elements(doc, "[data-x='FOO-BAR BAZ']"), 0L)
  expect_identical(sel(doc, "[data-x='FOO-BAR BAZ' i]"), "first")
  expect_identical(sel(doc, "[data-x='FOO-BAR BAZ' I]"), "first")
  expect_identical(sel(doc, "[lang=EN-us]"), "first")
})

test_that("attribute names match HTML elements regardless of case", {
  doc <- sel_doc()
  expect_identical(sel(doc, "[DATA-X]"), "first")
})

test_that("the four combinators", {
  doc <- sel_doc()
  expect_identical(sel(doc, "div p"), c("first", "second", "third"))
  expect_identical(sel(doc, "div > h2"), c("One", "Two"))
  expect_length(html_elements(doc, "body > h2"), 0L)
  expect_identical(sel(doc, "h2 + p"), "first")
  expect_identical(sel(doc, "h2 ~ p"), c("first", "second", "third"))
  expect_identical(sel(doc, "span ~ p"), "third")
  expect_identical(sel(doc, "span + p"), "third")
  expect_length(html_elements(doc, "p + h2"), 0L)
  # Whitespace around combinators is optional.
  expect_identical(sel(doc, "div>h2"), c("One", "Two"))
  expect_identical(sel(doc, "h2+p"), "first")
})

test_that("descendant and sibling chains backtrack correctly", {
  doc <- html_parse(paste0(
    "<div class=x><section><div class=y><p>hit</p></div></section></div>",
    "<div class=y><p>miss</p></div>"
  ))
  expect_identical(sel(doc, ".x .y p"), "hit")
  expect_identical(sel(doc, ".x > section .y > p"), "hit")
  doc <- html_parse("<a></a><b></b><c></c><a></a><d></d><e></e>")
  expect_identical(nm(doc, "a ~ c ~ e"), "e")
  expect_identical(nm(doc, "a + d + e"), "e")
  expect_length(html_elements(doc, "b + d"), 0L)
})

test_that("selector lists are unions in document order", {
  doc <- sel_doc()
  expect_identical(nm(doc, "span, h2"), c("h2", "span", "h2"))
  expect_identical(sel(doc, "#t1, .title"), c("One", "Two"))
})

test_that("structural pseudo-classes count element siblings", {
  doc <- sel_doc()
  expect_identical(sel(doc, "li:first-child"), "1")
  expect_identical(sel(doc, "li:last-child"), "5")
  expect_identical(nm(doc, "div > :first-child"), c("h2", "h2"))
  expect_identical(sel(doc, "li:nth-child(2)"), "2")
  expect_identical(sel(doc, "li:nth-child(odd)"), c("1", "3", "5"))
  expect_identical(sel(doc, "li:nth-child(EVEN)"), c("2", "4"))
  expect_identical(sel(doc, "li:nth-child(2n+1)"), c("1", "3", "5"))
  expect_identical(sel(doc, "li:nth-child( -n + 2 )"), c("1", "2"))
  expect_identical(sel(doc, "li:nth-child(n+4)"), c("4", "5"))
  expect_identical(sel(doc, "li:nth-child(3n - 1)"), c("2", "5"))
  expect_identical(sel(doc, "li:nth-child(0n+3)"), "3")
  expect_identical(sel(doc, "li:nth-child(-1)"), character())
  expect_identical(sel(doc, "p:nth-of-type(2)"), "second")
  expect_identical(sel(doc, "div > p:nth-of-type(odd)"), c("first", "third"))
  # Text between elements does not count.
  d2 <- html_parse("<div>text<b>1</b> more <b>2</b></div>")
  expect_identical(sel(d2, "b:first-child"), "1")
  expect_identical(sel(d2, "b:only-child"), character())
  expect_identical(sel(html_parse("<div>x<b>only</b>y</div>"), "b:only-child"),
                   "only")
})

test_that(":root, :empty and :scope", {
  doc <- sel_doc()
  expect_identical(nm(doc, ":root"), "html")
  expect_identical(nm(doc, ":scope"), "html")
  # em is empty; i holds whitespace text; b holds only a comment.
  expect_identical(nm(doc, "div :empty"), c("em", "b"))
})

test_that(":not() takes one compound selector", {
  doc <- sel_doc()
  expect_identical(sel(doc, "p:not(.a)"), c("second", "third"))
  expect_identical(sel(doc, "p:not([title]):not(.a)"), "third")
  expect_identical(sel(doc, "li:not(:nth-child(odd))"), c("2", "4"))
  expect_identical(nm(doc, "div > :not(p):not(h2)"), c("span", "em", "i", "b"))
  expect_identical(sel(doc, "p:not(:not(.a))"), "first")
})

test_that("escapes and strings in selectors", {
  doc <- html_parse(paste0(
    "<p id='a:b' class='1x' data-q='say \"hi\"'>esc</p>",
    "<p class='été'>utf</p>"
  ))
  expect_identical(sel(doc, "#a\\:b"), "esc")
  expect_identical(sel(doc, ".\\31 x"), "esc")
  expect_identical(sel(doc, ".\\000031x"), "esc")
  expect_identical(sel(doc, "[data-q='say \"hi\"']"), "esc")
  expect_identical(sel(doc, "[data-q=\"say \\\"hi\\\"\"]"), "esc")
  expect_identical(sel(doc, ".été"), "utf")
  expect_identical(sel(doc, ".\\e9 t\\e9"), "utf")
})

test_that("foreign elements match type selectors exactly", {
  doc <- html_parse("<svg viewBox='0 0 1 1'><foreignObject><p>x</p></foreignObject></svg>")
  expect_identical(nm(doc, "foreignObject"), "foreignObject")
  expect_length(html_elements(doc, "foreignobject"), 0L)
  expect_identical(nm(doc, "svg"), "svg")
  expect_identical(nm(doc, "[viewBox]"), "svg")
  expect_length(html_elements(doc, "[viewbox]"), 0L)
  expect_identical(nm(doc, "foreignObject > p"), "p")
})

test_that("element searches exclude the context unless :scope selects it", {
  doc <- sel_doc()
  cards <- html_elements(doc, ".card")
  expect_length(html_elements(cards, ".card"), 0L)
  expect_identical(html_elements(cards, ":scope"), cards)
  expect_identical(html_text(html_elements(cards, ":scope > h2")),
                   c("One", "Two"))
  expect_length(html_elements(cards, ":scope > em"), 1L)
  # Ancestors outside the context still count.
  expect_identical(sel(cards[1], "body p.a"), "first")
})

test_that("multiple contexts give a deduplicated union", {
  doc <- sel_doc()
  divs <- html_elements(doc, "div")
  both <- c(divs[2], divs[1], divs[1], html_root(doc))
  expect_identical(sel(both, "h2"), c("One", "Two"))
})

test_that("html_element() is aligned, with missing nodes for no match", {
  doc <- sel_doc()
  cards <- html_elements(doc, ".card")
  expect_identical(html_text(html_element(cards, "span")), c("s", NA))
  expect_identical(html_text(html_element(cards, "p")), c("first", NA))
  expect_identical(html_text(html_element(cards[c(1, NA, 1)], "h2")),
                   c("One", NA, "One"))
  expect_length(html_element(cards[0], "p"), 0L)
  expect_identical(html_text(html_element(doc, "h2")), "One")
})

test_that("html_matches() and html_filter()", {
  doc <- sel_doc()
  x <- html_elements(doc, "h2, p, span")
  expect_identical(html_matches(x, "p"), c(FALSE, TRUE, TRUE, FALSE, TRUE,
                                           FALSE))
  expect_identical(html_matches(x[c(1, NA)], "h2"), c(TRUE, NA))
  expect_identical(html_text(html_filter(x, ".b")), c("first", "second"))
  expect_identical(html_matches(x[1], ":scope"), TRUE)
  texts <- html_children(x[1], elements_only = FALSE)
  expect_identical(html_matches(texts, "*"), FALSE)
  expect_false(html_matches(doc, "*"))
  expect_error(html_filter(doc, "p"), class = "zuhtml_input_error")
})

test_that("template contents are never searched", {
  doc <- html_parse("<template><p class=t>in</p></template><p class=t>out</p>")
  expect_identical(sel(doc, ".t"), "out")
  tmpl <- html_elements(doc, "template")
  expect_length(html_elements(tmpl, "p"), 0L)
  expect_identical(sel(html_template_content(tmpl), ":scope"), "in")
})

test_that("fragments are searched from the fragment node", {
  f <- html_fragment("<tr><td class=c>1<td>2", context = "tbody")
  expect_identical(sel(f, "td.c"), "1")
  expect_length(html_elements(f, ":root"), 0L)
})

test_that("every unsupported form is rejected with its position", {
  doc <- html_parse("<p>x")
  unsupported <- c(
    "p:has(b)", "p::before", "p::text", "p::attr(href)", "p:before",
    "svg|a", "*|p", "|p", "[svg|href]", "[*|href]", "p:hover", "p:is(b)",
    "p:where(b)", "p:nth-last-child(1)", "p:first-of-type",
    "p:nth-child(2n of .x)", "p:not(a b)", "p:not(a, b)", "p:not(a > b)",
    "p /* note */"
  )
  for (s in unsupported) {
    err <- expect_error(html_elements(doc, s), class = "zuhtml_selector_error")
    expect_true(err$unsupported, label = s)
    expect_true(err$position >= 1L && err$position <= nchar(s), label = s)
  }
})

test_that("malformed selectors are syntax errors with positions", {
  doc <- html_parse("<p>x")
  malformed <- list(
    list("", 1L), list("   ", 1L), list("p,", 3L), list(",p", 1L),
    list("a,,b", 3L), list("p >", 4L), list("> p", 1L), list("p..a", 3L),
    list("#", 2L), list("#1a", 2L), list("[", 2L), list("[a", 3L),
    list("[a=]", 4L), list("[a=b c]", 6L), list("[a~b]", 3L),
    list("p:nth-child(x)", 13L), list("p:nth-child(2n+)", 16L),
    list("p:nth-child(2", 13L), list("[a='x\ny']", 6L), list("p!", 2L)
  )
  for (m in malformed) {
    err <- expect_error(html_elements(doc, m[[1L]]),
                        class = "zuhtml_selector_error")
    expect_false(err$unsupported, label = m[[1L]])
    expect_identical(err$position, m[[2L]], label = m[[1L]])
  }
})

test_that("selector errors carry the selector and a caret", {
  err <- expect_error(html_elements(html_parse("<p>"), "div p:hover"),
                      class = "zuhtml_selector_error")
  expect_identical(err$selector, "div p:hover")
  expect_identical(err$position, 6L)
  expect_match(conditionMessage(err), "\n       ^", fixed = TRUE)
})

test_that("positions count characters, not bytes", {
  err <- expect_error(html_elements(html_parse("<p>"), "éé:hover"),
                      class = "zuhtml_selector_error")
  expect_identical(err$position, 3L)
})

test_that("css is validated and bounded", {
  doc <- html_parse("<p>")
  expect_error(html_elements(doc, c("p", "a")), class = "zuhtml_input_error")
  expect_error(html_elements(doc, NA_character_), class = "zuhtml_input_error")
  expect_error(html_elements(doc, 1), class = "zuhtml_input_error")
  err <- expect_error(html_elements(doc, strrep("p ", 9000)),
                      class = "zuhtml_limit_error")
  expect_identical(err$limit, "max_selector_length")
  err <- expect_error(html_elements(doc, paste(rep("p", 200), collapse = ">")),
                      class = "zuhtml_selector_error")
  expect_false(err$unsupported)
})

test_that("matching stays fast on deep documents with long selectors", {
  doc <- html_parse(strrep("<div>", 500))
  s <- paste(rep("div", 60), collapse = " ")
  elapsed <- system.time(res <- html_elements(doc, paste(s, "span")))
  expect_length(res, 0L)
  if (timing_asserted()) expect_lt(elapsed[["elapsed"]], 5)
})

test_that("long type names compile (regression: pool use-after-free)", {
  # The fuzzer found the lowercase copy of a type name reading the selector
  # pool after growing it had moved it. Names past the pool's first growth
  # exercised it.
  doc <- html_parse("<abcdefghijklmnopqrstuvwxyz-element>x</abcdefghijklmnopqrstuvwxyz-element>")
  expect_identical(
    sel(doc, "ABCDEFGHIJKLMNOPQRSTUVWXYZ-ELEMENT, abcdefghijklmnopqrstuvwxyz-element"),
    "x"
  )
})
