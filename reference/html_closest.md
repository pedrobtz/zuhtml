# Nearest ancestor matching a selector

For each node, the node itself if it matches `css`, otherwise its
nearest ancestor element that does, as the DOM's `closest()` and
jQuery's `.closest()`. Use it to go from a cell or a link to the row,
card or section that contains it. `:scope` is the node itself.

## Usage

``` r
html_closest(x, css)
```

## Arguments

- x:

  A `zuhtml_document` or `zuhtml_nodeset`.

- css:

  A CSS selector: a single string.

## Value

A `zuhtml_nodeset` as long as `x`: for each node, the matching element,
or a missing node where there is none (and for missing nodes).

## See also

Other navigation:
[`html_children()`](https://pedrobtz.github.io/zuhtml/reference/html_children.md),
[`html_elements()`](https://pedrobtz.github.io/zuhtml/reference/html_elements.md)

## Examples

``` r
doc <- html_parse(paste0(
  "<table><tr id=a><td>1<td><b>x</b></tr>",
  "<tr id=b><td>2<td><b>y</b></tr></table>"
))
bold <- html_elements(doc, "b")
html_attr(html_closest(bold, "tr"), "id")
#> [1] "a" "b"
html_closest(bold, "ul")
#> <zuhtml_nodeset[2]>
#> [1] <missing>
#> [2] <missing>
```
