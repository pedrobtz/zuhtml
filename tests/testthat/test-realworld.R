# Real pages from other projects' test suites; the full set, 522 pages, is
# the external corpus in tools/corpus/.

test_that("pandas' failed-bank list reads as pandas documents it", {
  doc <- html_read(realworld("pandas", "banklist.html"))
  tabs <- html_tables(doc)
  expect_length(tabs, 1L)
  bank <- tabs[[1L]]
  expect_identical(
    names(bank),
    c("Bank Name", "City", "ST", "CERT", "Acquiring Institution",
      "Closing Date", "Updated Date")
  )
  expect_identical(nrow(bank), 10L)
  expect_identical(bank[1L, "Bank Name"],
                   "Banks of Wisconsin d/b/a Bank of Kenosha")
  expect_identical(bank$CERT[1:3], c("35386", "34527", "58185"))
  expect_identical(bank$`Closing Date`[1L], "May 31, 2013")
})

test_that("pandas' nutrient table keeps section rows and multi-line headers", {
  tab <- html_tables(html_read(realworld("pandas", "spam.html")))[[1L]]
  expect_identical(dim(tab), c(37L, 6L))
  expect_identical(names(tab)[1:4], c("Nutrient", "Unit", "Value per 100.0g",
                                      "oz 1 NLEA serving\n56g"))
  # A section heading spans every column, so its text repeats in each.
  expect_identical(unlist(tab[1L, 1:4], use.names = FALSE),
                   rep("Proximates", 4L))
  expect_identical(unlist(tab[2L, 1:3], use.names = FALSE),
                   c("Water", "g", "51.70"))
})

test_that("pandas' valid markup gives two tables with an index column", {
  tabs <- html_tables(html_read(realworld("pandas", "valid_markup.html")))
  expect_length(tabs, 2L)
  expect_identical(names(tabs[[1L]]), c("V1", "a", "b"))
  expect_identical(tabs[[1L]]$b, c("7", "0", "4", "0"))
  expect_identical(dim(tabs[[2L]]), c(2L, 3L))
})

test_that("every paragraph Readability extracts is in the cleaned text", {
  pages <- readability_pages()
  expect_gte(length(pages), 10L)
  for (page in pages) {
    text <- squash(html_text_clean(
      html_read(realworld("readability", page, "source.html"))
    ))
    paras <- html_text_clean(html_elements(
      html_read(realworld("readability", page, "expected.html")), "p"
    ))
    for (p in paras[nzchar(paras)]) {
      expect_true(grepl(squash(p), text, fixed = TRUE),
                  label = paste(page, ":", substr(p, 1, 40)))
    }
  }
})

test_that("script and style text never reaches the cleaned text", {
  text <- html_text_clean(html_read(
    realworld("readability", "remove-script-tags", "source.html")
  ))
  expect_false(grepl("alert(", text, fixed = TRUE))
  text <- html_text_clean(html_read(
    realworld("readability", "style-tags-removal", "source.html")
  ))
  expect_false(grepl("font-weight", text, fixed = TRUE))
  text <- html_text_clean(html_read(
    realworld("readability", "comment-inside-script-parsing", "source.html")
  ))
  expect_false(grepl("-->", text, fixed = TRUE))
})

test_that("html_url() resolves links and images as Readability does", {
  for (page in c("base-url", "base-url-base-element",
                 "base-url-base-element-relative")) {
    src <- html_read(realworld("readability", page, "source.html"),
                     base_url = "http://fakehost/test/page.html")
    expected <- html_read(realworld("readability", page, "expected.html"))
    ours <- html_url(html_elements(src, "a"))
    theirs <- html_attr(html_elements(expected, "a"), "href")
    # One convention differs: without a <base>, Readability leaves an
    # in-page anchor such as "#foo" relative. RFC 3986 resolves it, as
    # html_url() does.
    keep <- !(page == "base-url" & startsWith(theirs, "#"))
    expect_identical(ours[keep], theirs[keep], label = page)
    expect_identical(
      html_url(html_elements(src, "img"), "src"),
      html_attr(html_elements(expected, "img"), "src"),
      label = page
    )
  }
})
