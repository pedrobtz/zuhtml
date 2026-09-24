# Extract an HTML list

Reads one `<ul>` or `<ol>` element. In `"text"` mode, the result has one
string per item: the item's cleaned text (see
[`html_text_clean()`](https://pedrobtz.github.io/zuhtml/reference/html_text_clean.md)),
without the text of any list nested inside it, so child items do not
leak into their parent. A nested list still separates the text around it
with a line break. In `"tree"` mode, nested lists become children of the
item that contains them, including lists inside wrapper elements such as
`<div>`.

## Usage

``` r
html_list(x, mode = c("text", "tree"))
```

## Arguments

- x:

  A `zuhtml_nodeset` holding exactly one `<ul>` or `<ol>` element, as
  from
  [`html_element()`](https://pedrobtz.github.io/zuhtml/reference/html_elements.md).

- mode:

  `"text"` or `"tree"`.

## Value

- `"text"`: a character vector, one string per item.

- `"tree"`: an object of class `zuhtml_list`, a list with `type` (`"ul"`
  or `"ol"`) and `items`, a list with one element per item; each item is
  a list with `text` (as in text mode) and `children` (a list of
  `zuhtml_list` objects, one per list nested in the item).

## Details

Items are the `<li>` children of the list, in source order; empty items
are `""` and duplicates are kept.

## See also

Other extraction:
[`html_links()`](https://pedrobtz.github.io/zuhtml/reference/html_links.md),
[`html_table()`](https://pedrobtz.github.io/zuhtml/reference/html_table.md),
[`html_url()`](https://pedrobtz.github.io/zuhtml/reference/html_url.md)

## Examples

``` r
doc <- html_parse("<ul><li>Apples<li>Tools<ul><li>Hammer<li>Saw</ul></ul>")
items <- html_element(doc, "ul")
html_list(items)
#> [1] "Apples" "Tools" 
html_list(items, mode = "tree")
#> <zuhtml_list ul, 2 items>
#> - Apples
#> - Tools
#>   - Hammer
#>   - Saw
```
