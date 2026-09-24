test_that("html_title() cleans the first HTML title and ignores SVG", {
  doc <- html_parse(paste0(
    "<svg><title>icon</title></svg>",
    "<title>\n  Annual   report\t2024 </title><title>second</title>"
  ))
  expect_identical(html_title(doc), "Annual report 2024")
  expect_identical(html_title(html_elements(doc, "title")), html_title(doc))
  expect_identical(html_title(html_parse("<p>none")), NA_character_)
  expect_identical(html_title(html_parse("<title></title>")), "")
  expect_identical(html_title(html_parse("<title>&amp; co</title>")), "& co")
})

test_that("html_meta() keeps every tag, duplicates included", {
  doc <- html_parse(paste0(
    "<head><meta charset='utf-8'>",
    "<meta http-equiv='X-UA-Compatible' content='IE=edge'>",
    "<meta name='description' content='A &amp; B'>",
    "<meta property='og:title' content='Title'>",
    "<meta property='og:image' content='a.png'>",
    "<meta property='og:image' content='b.png'>",
    "<meta name='twitter:card' content='summary'>",
    "<meta name='DC.creator' content='Ada'></head>",
    "<body><div itemscope><meta itemprop='x' content='y'></div></body>"
  ))
  m <- html_meta(doc)
  expect_named(m, c("name", "property", "http_equiv", "charset", "content"))
  expect_identical(nrow(m), 9L)
  expect_identical(m$charset[1], "utf-8")
  expect_identical(m$http_equiv[2], "X-UA-Compatible")
  expect_identical(m$content[m$name %in% "description"], "A & B")
  expect_identical(m$content[m$property %in% "og:image"], c("a.png", "b.png"))
  expect_identical(m$content[m$name %in% "DC.creator"], "Ada")
  expect_identical(nrow(html_meta(html_element(doc, "body"))), 1L)

  none <- html_meta(html_parse("<p>no meta"))
  expect_identical(nrow(none), 0L)
  expect_named(none, names(m))
})

test_that("html_json_ld() matches the MIME type and keeps text", {
  doc <- html_parse(paste0(
    "<script type='application/ld+json'>{\"@type\": \"Person\", ",
    "\"name\": \"Ada\", \"knows\": [\"Charles\"]}</script>",
    "<script type=' Application/LD+JSON; charset=utf-8 '>{bad json</script>",
    "<script type='application/json'>{\"no\": 1}</script>",
    "<script>var x = 1;</script>",
    "<script type='application/ld+json'>[{\"a\": 1}, {\"a\": 2}]</script>"
  ))
  txt <- html_json_ld(doc)
  expect_length(txt, 3L)
  expect_identical(txt[2], "{bad json")
  expect_identical(html_json_ld(html_parse("<p>none")), character())

  skip_if_not_installed("jsonlite")
  parsed <- html_json_ld(doc, parse = TRUE)
  expect_length(parsed, 3L)
  expect_identical(parsed[[1]]$name, "Ada")
  expect_identical(parsed[[1]]$knows, list("Charles"))
  expect_null(parsed[[2]])
  expect_identical(parsed[[3]][[2]]$a, 2L)
  expect_identical(attr(parsed, "json"), txt)
  expect_identical(html_json_ld(html_parse("<p>none"), parse = TRUE),
                   structure(list(), json = character()))
})

test_that("html_json_ld() parses through CDATA and comment wrappers", {
  skip_if_not_installed("jsonlite")
  bodies <- c(
    "<![CDATA[ {\"a\": 1} ]]>",
    "\n//<![CDATA[\n{\"a\": 1}\n//]]>\n",
    "/*<![CDATA[*/ {\"a\": 1} /*]]>*/",
    "<!-- {\"a\": 1} -->",
    "  {\"a\": 1}  "
  )
  doc <- html_parse(paste0(
    "<script type='application/ld+json'>", bodies, "</script>",
    collapse = ""
  ))
  parsed <- html_json_ld(doc, parse = TRUE)
  expect_identical(parsed, structure(rep(list(list(a = 1L)), 5L),
                                     json = bodies))
})

test_that("html_json_ld() validates parse", {
  doc <- html_parse("<p>")
  expect_error(html_json_ld(doc, parse = NA), class = "zuhtml_input_error")
})

test_that("html_microdata() collects nested items and duplicates", {
  doc <- html_parse(paste0(
    "<div itemscope itemtype='https://schema.org/Product' ",
    "itemid='/p/1'>",
    "<h1 itemprop='name'>  Kettle\n  2000 </h1>",
    "<img itemprop='image' src='k1.png'><img itemprop='image' src='k2.png'>",
    "<a itemprop='url' href='?ref=x'>link</a>",
    "<div itemprop='offers' itemscope itemtype='https://schema.org/Offer'>",
    "<meta itemprop='priceCurrency' content='EUR'>",
    "<data itemprop='price' value='39.9'>39,90 EUR</data>",
    "<time itemprop='validFrom' datetime='2024-01-01'>New year</time>",
    "<span itemprop='name'>offer name, not product name</span>",
    "</div>",
    "<span itemprop='brand manufacturer'>Acme</span>",
    "<div itemprop='review'><span itemprop='author'>Ann</span></div>",
    "</div>",
    "<p itemscope><span itemprop='a'>1</span></p>"
  ), base_url = "https://shop.example/c/index.html")
  items <- html_microdata(doc)
  expect_length(items, 2L)
  p <- items[[1]]
  expect_identical(p$type, "https://schema.org/Product")
  expect_identical(p$id, "https://shop.example/p/1")
  pr <- p$properties
  expect_identical(
    names(pr),
    c("name", "image", "url", "offers", "brand", "manufacturer", "review",
      "author")
  )
  expect_identical(pr$name, list("Kettle 2000"))
  expect_identical(pr$image, list("https://shop.example/c/k1.png",
                                  "https://shop.example/c/k2.png"))
  expect_identical(pr$url, list("https://shop.example/c/index.html?ref=x"))
  expect_identical(pr$brand, list("Acme"))
  expect_identical(pr$manufacturer, list("Acme"))
  # A property without itemscope does not start a scope.
  expect_identical(pr$review, list("Ann"))
  expect_identical(pr$author, list("Ann"))

  offer <- pr$offers[[1]]
  expect_identical(offer$type, "https://schema.org/Offer")
  expect_identical(offer$id, NA_character_)
  expect_identical(offer$properties, list(
    priceCurrency = list("EUR"), price = list("39.9"),
    validFrom = list("2024-01-01"), name = list("offer name, not product name")
  ))

  expect_identical(items[[2]]$type, character())
  expect_identical(items[[2]]$properties, list(a = list("1")))
  expect_identical(html_microdata(html_parse("<p>none")), list())
})

test_that("html_microdata() follows itemref and survives cycles", {
  doc <- html_parse(paste0(
    "<div itemscope id='x' itemref='a b missing x'>",
    "<span itemprop='name'>Amanda</span></div>",
    "<p id='a'>Age: <span itemprop='age'>26</span></p>",
    "<div id='b' itemprop='band' itemscope itemref='c'></div>",
    "<div id='c'><span itemprop='size'>12</span>",
    "<span itemprop='loop' itemscope itemref='c'></span></div>"
  ))
  items <- html_microdata(doc)
  expect_length(items, 1L)
  pr <- items[[1]]$properties
  expect_identical(names(pr), c("name", "age", "band"))
  expect_identical(pr$age, list("26"))
  band <- pr$band[[1]]
  expect_identical(names(band$properties), c("size", "loop"))
  expect_identical(band$properties$size, list("12"))
  # c holds loop itself, which the crawl skips: loop has only size.
  expect_identical(band$properties$loop[[1]]$properties,
                   list(size = list("12")))

  cyc <- html_microdata(html_parse(paste0(
    "<div itemscope itemref='b'></div>",
    "<div id='b' itemprop='p' itemscope itemref='c'></div>",
    "<div id='c' itemprop='q' itemscope itemref='b'></div>"
  )))
  b <- cyc[[1]]$properties$p[[1]]
  c <- b$properties$q[[1]]
  expect_identical(c$properties$p, list(NULL))
})

test_that("metadata functions take a nodeset scope", {
  doc <- html_parse(paste0(
    "<div id='one'><div itemscope><i itemprop='k'>1</i></div></div>",
    "<div id='two'><div itemscope><i itemprop='k'>2</i></div>",
    "<script type='application/ld+json'>{}</script></div>"
  ))
  two <- html_elements(doc, "#two")
  expect_identical(html_microdata(two)[[1]]$properties$k, list("2"))
  expect_identical(html_json_ld(two), "{}")
  expect_identical(html_json_ld(html_elements(doc, "#one")), character())
})
