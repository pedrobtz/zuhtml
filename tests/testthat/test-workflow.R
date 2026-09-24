test_that("the design's worked extraction workflow runs end to end", {
  path <- withr::local_tempfile(fileext = ".html")
  writeLines(c(
    "<!DOCTYPE html><title>Catalog</title>",
    "<nav><ul><li><a href='/'>Home</a><li><a href='sale/'>Sale</a></ul></nav>",
    "<div class=product><h2 class=name>Tea</h2><span class=price>3.50</span>",
    "  <a href='tea.html'>more</a></div>",
    "<div class=product><h2 class=name>Cake</h2><a href='cake.html'>more</a></div>",
    "<table><tr><th>Size<th>Grams<tr><td>S<td>0100<tr><td>L<td>0250</table>"
  ), path)

  doc <- html_read(path, base_url = "https://example.org/catalog/")

  title <- html_text_clean(html_element(doc, "title"))
  links <- html_links(doc, absolute = TRUE)
  menus <- lapply(html_elements(doc, "nav ul"), html_list)
  tables <- html_tables(doc)

  cards <- html_elements(doc, ".product")
  products <- data.frame(
    name = html_text_clean(html_element(cards, ".name")),
    price = html_text_clean(html_element(cards, ".price")),
    url = html_url(html_element(cards, "a")),
    stringsAsFactors = FALSE
  )
  problems <- html_problems(doc)

  expect_identical(title, "Catalog")
  expect_identical(links$url[1:2], c("https://example.org/",
                                     "https://example.org/catalog/sale/"))
  expect_identical(menus, list(c("Home", "Sale")))
  expect_identical(tables[[1L]]$Grams, c("0100", "0250"))
  # A card without a price keeps its row and gets NA in that column.
  expect_identical(products$name, c("Tea", "Cake"))
  expect_identical(products$price, c("3.50", NA))
  expect_identical(products$url, c("https://example.org/catalog/tea.html",
                                   "https://example.org/catalog/cake.html"))
  expect_s3_class(problems, "data.frame")
})
