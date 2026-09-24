test_that("html_forms() describes the form element", {
  doc <- html_parse(paste0(
    "<form id=f1 name=login action='../auth?x=1' method=PoSt ",
    "enctype=MULTIPART/FORM-DATA></form>",
    "<form method=put enctype=bogus></form>",
    "<form action=''></form>"
  ), base_url = "https://site.test/app/page.html")
  f <- html_forms(doc)
  expect_length(f, 3L)
  expect_identical(f[[1]]$action, "https://site.test/auth?x=1")
  expect_identical(f[[1]]$method, "post")
  expect_identical(f[[1]]$enctype, "multipart/form-data")
  expect_identical(f[[1]]$id, "f1")
  expect_identical(f[[1]]$name, "login")
  # Invalid values fall back to the defaults; no action submits to the page.
  expect_identical(f[[2]]$method, "get")
  expect_identical(f[[2]]$enctype, "application/x-www-form-urlencoded")
  expect_identical(f[[2]]$action, "https://site.test/app/page.html")
  expect_identical(f[[2]]$id, NA_character_)
  expect_identical(f[[3]]$action, "https://site.test/app/page.html")
  # A form with no controls has a zero-row fields frame.
  expect_identical(nrow(f[[1]]$fields), 0L)
  expect_named(f[[1]]$fields,
               c("name", "type", "value", "checked", "disabled", "options"))
  expect_identical(html_forms(html_parse("<p>none")), list())
  expect_identical(html_forms(html_parse("<form></form>"))[[1]]$action,
                   NA_character_)
})

test_that("html_forms() reads every control type", {
  doc <- html_parse(paste0(
    "<form>",
    "<input name=a><input name=b type=PASSWORD value=s>",
    "<input name=c type=frobnicate><input name=h type=hidden value=1>",
    "<input name=d type=date value=2024-01-02><input type=file name=up>",
    "<input type=checkbox name=cb><input type=checkbox name=cb2 value=y ",
    "checked><input type=radio name=r value=1><input type=radio name=r ",
    "value=2 checked>",
    "<input type=submit name=go value=Go><input type=image name=pic>",
    "<textarea name=t>\nline 1\nline 2</textarea>",
    "<button name=b1>B</button><button type=reset>R</button>",
    "<button type=button value=v>V</button><button type=nope>N</button>",
    "</form>"
  ))
  fl <- html_forms(doc)[[1]]$fields
  expect_identical(
    fl$type,
    c("text", "password", "text", "hidden", "date", "file", "checkbox",
      "checkbox", "radio", "radio", "submit", "image", "textarea", "submit",
      "reset", "button", "submit")
  )
  expect_identical(
    fl$value,
    c("", "s", "", "1", "2024-01-02", "", "on", "y", "1", "2", "Go", "",
      "line 1\nline 2", "", "", "v", "")
  )
  expect_identical(fl$checked,
                   c(rep(NA, 6), FALSE, TRUE, FALSE, TRUE, rep(NA, 7)))
  # Repeated names are kept.
  expect_identical(sum(fl$name %in% "r"), 2L)
  expect_identical(fl$name[15], NA_character_)
  expect_true(all(vapply(fl$options, is.null, NA)))
})

test_that("html_forms() reads selects with the DOM's selectedness", {
  doc <- html_parse(paste0(
    "<form>",
    "<select name=one><option disabled>x<option value=v2>Two",
    "<option>  Three\n  words </option></select>",
    "<select name=two><option selected>a<option selected>b</select>",
    "<select name=many multiple><option>a<option selected>b",
    "<option selected>c</select>",
    "<select name=none multiple><option>a</select>",
    "<select name=grp><optgroup disabled><option>g</optgroup>",
    "<option label=L value=lv>text</select>",
    "<select name=empty></select>",
    "</form>"
  ))
  fl <- html_forms(doc)[[1]]$fields
  expect_identical(fl$type, c("select-one", "select-one", "select-multiple",
                              "select-multiple", "select-one", "select-one"))
  # No option selected: the first enabled one is.
  expect_identical(fl$value, c("v2", "b", "b", "", "lv", ""))
  o <- fl$options[[1]]
  expect_identical(o$value, c("x", "v2", "Three words"))
  expect_identical(o$label, c("x", "Two", "Three words"))
  expect_identical(o$selected, c(FALSE, TRUE, FALSE))
  expect_identical(o$disabled, c(TRUE, FALSE, FALSE))
  # Several selected in a single select: the last wins.
  expect_identical(fl$options[[2]]$selected, c(FALSE, TRUE))
  expect_identical(fl$options[[3]]$selected, c(FALSE, TRUE, TRUE))
  expect_identical(fl$options[[5]]$disabled, c(TRUE, FALSE))
  expect_identical(fl$options[[5]]$label, c("g", "L"))
  expect_identical(nrow(fl$options[[6]]), 0L)
})

test_that("controls are disabled by attribute or fieldset", {
  doc <- html_parse(paste0(
    "<form><input name=a disabled>",
    "<fieldset disabled><legend><input name=in_legend></legend>",
    "<input name=in_set><legend><input name=second_legend></legend>",
    "</fieldset>",
    "<fieldset><input name=ok></fieldset>",
    "<fieldset disabled><legend><fieldset disabled><legend>",
    "<input name=nested></legend></fieldset></legend></fieldset></form>"
  ))
  fl <- html_forms(doc)[[1]]$fields
  expect_identical(
    stats::setNames(fl$disabled, fl$name),
    c(a = TRUE, in_legend = FALSE, in_set = TRUE, second_legend = TRUE,
      ok = FALSE, nested = FALSE)
  )
})

test_that("form= and the parser's association decide ownership", {
  doc <- html_parse(paste0(
    "<form id=main><input name=inside><input name=away form=other></form>",
    "<input name=outside form=main><input name=orphan>",
    "<input name=bad form=notaform><div id=notaform></div>",
    "<input name=blank form=''>",
    "<form id=other></form>",
    "<table><form id=legacy><tr><td><input name=cell1>",
    "<td><select name=cell2><option>x</select></tr></form></table>",
    "<table><tr><td><input name=later></table>"
  ))
  f <- html_forms(doc)
  names <- lapply(f, function(x) x$fields$name)
  expect_identical(names[[1]], c("inside", "outside"))
  expect_identical(names[[2]], "away")
  # The form closed at once inside the table owns the cells after it.
  expect_identical(f[[3]]$id, "legacy")
  expect_identical(names[[3]], c("cell1", "cell2"))
})

test_that("html_forms() scopes to the given nodes", {
  doc <- html_parse(paste0(
    "<div id=a><form><input name=x></form></div>",
    "<div id=b><form><input name=y></form></div>"
  ))
  f <- html_forms(html_elements(doc, "#b"))
  expect_length(f, 1L)
  expect_identical(f[[1]]$fields$name, "y")
  expect_length(html_forms(html_elements(doc, "form")), 2L)
})
