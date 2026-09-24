# Forms and their controls

Describes each `<form>` below the given nodes (and the nodes themselves)
and the controls it owns, for inspection. Nothing is submitted, fetched
or built into a request.

## Usage

``` r
html_forms(x)
```

## Arguments

- x:

  A `zuhtml_document` or `zuhtml_nodeset`.

## Value

A list with one element per form, in document order, each a list of:

- `action`: the `action` attribute resolved as
  [`html_url()`](https://pedrobtz.github.io/zuhtml/reference/html_url.md)
  resolves URLs; without one, the document's base URL, as browsers
  submit to the page itself; `NA` when neither resolves;

- `method`: `"get"`, `"post"` or `"dialog"` (`"get"` when missing or
  invalid);

- `enctype`: `"application/x-www-form-urlencoded"` (the default),
  `"multipart/form-data"` or `"text/plain"`;

- `id`, `name`: the attributes, or `NA`;

- `fields`: a data frame with one row per control and columns `name`
  (`NA` when absent; repeated names are kept), `type`, `value`,
  `checked` (`TRUE`/`FALSE` for checkboxes and radio buttons, `NA`
  otherwise), `disabled`, and `options`, a list-column holding for each
  select a data frame of its options (`value`, `label`, `selected`,
  `disabled`) and `NULL` for other controls.

## Details

A control belongs to a form as the HTML standard's form owner says: the
form named by its `form` attribute (the element with that ID, if it is a
`<form>`; no form otherwise), else its nearest ancestor `<form>`. Old
pages often write `<table><form><tr><td><input ...>`, where the parser
closes the form at once but browsers still associate the following
controls with it; such a form, left empty inside a table, owns the
controls without another owner that follow it in that table, up to the
next form.

Controls are `<input>`, `<select>`, `<textarea>` and `<button>`
elements, in document order. Values follow the DOM:

- `type` is an input's `type` (lowercased; `"text"` when missing or
  unknown), `"select-one"` or `"select-multiple"`, `"textarea"`, or a
  button's `type` (`"submit"` by default);

- `value` is the `value` attribute (`"on"` for a checkbox or radio
  button without one, else `""`); a textarea's text; or a select's first
  selected option's value, where a single select with no option marked
  selected selects its first enabled option;

- `disabled` is `TRUE` for a control with a `disabled` attribute or
  inside a disabled `<fieldset>` (except in its first `<legend>`).

## See also

Other extraction:
[`html_links()`](https://pedrobtz.github.io/zuhtml/reference/html_links.md),
[`html_list()`](https://pedrobtz.github.io/zuhtml/reference/html_list.md),
[`html_table()`](https://pedrobtz.github.io/zuhtml/reference/html_table.md),
[`html_table_cells()`](https://pedrobtz.github.io/zuhtml/reference/html_table_cells.md),
[`html_url()`](https://pedrobtz.github.io/zuhtml/reference/html_url.md)

## Examples

``` r
doc <- html_parse(paste0(
  "<form action='/search' method=POST>",
  "<input name=q value='zuhtml'>",
  "<select name=sort><option>relevance<option selected>date</select>",
  "<label><input type=checkbox name=exact checked> Exact</label>",
  "<button>Search</button></form>",
  "<input form=search-options name=page value=2>",
  "<form id=search-options></form>"
), base_url = "https://example.org/")
forms <- html_forms(doc)
forms[[1]][c("action", "method")]
#> $action
#> [1] "https://example.org/search"
#> 
#> $method
#> [1] "post"
#> 
forms[[1]]$fields[, c("name", "type", "value", "checked")]
#>    name       type  value checked
#> 1     q       text zuhtml      NA
#> 2  sort select-one   date      NA
#> 3 exact   checkbox     on    TRUE
#> 4  <NA>     submit             NA
forms[[1]]$fields$options[[2]]
#>       value     label selected disabled
#> 1 relevance relevance    FALSE    FALSE
#> 2      date      date     TRUE    FALSE
forms[[2]]$fields$name
#> [1] "page"
```
