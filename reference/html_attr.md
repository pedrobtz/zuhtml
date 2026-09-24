# Attributes of elements

`html_attr()` reads one attribute from every node; `html_attrs()` reads
all of them; `html_classes()` splits the `class` attribute into tokens.
Values are decoded (`&amp;` becomes `&`). An attribute that is present
but empty is `""`, distinct from an absent one: test a boolean attribute
such as `disabled` by presence, `!is.na(html_attr(x, "disabled"))`.

## Usage

``` r
html_attr(x, name, default = NA_character_)

html_attrs(x)

html_classes(x)
```

## Arguments

- x:

  A `zuhtml_document` or `zuhtml_nodeset`.

- name:

  The attribute name: a single string.

- default:

  The value for nodes that lack the attribute, including nodes that are
  not elements: a single string, possibly `NA`.

## Value

- `html_attr()`: a character vector as long as `x`; `NA` for missing
  nodes.

- `html_attrs()`: a list as long as `x` of named character vectors, in
  source order; `NA_character_` for missing nodes.

- `html_classes()`: a list as long as `x` of character vectors of class
  tokens; `NA_character_` for missing nodes.

## Details

Attribute names on HTML elements match regardless of ASCII case, as in a
browser; on SVG and MathML elements they match exactly (`viewBox`).
Namespaced attributes in foreign content are named with their prefix, as
in `"xlink:href"`. Where an element has the same attribute more than
once, the first wins, as the HTML parser decides.

## See also

Other node values:
[`html_name()`](https://pedrobtz.github.io/zuhtml/reference/html_name.md),
[`html_serialize()`](https://pedrobtz.github.io/zuhtml/reference/html_serialize.md),
[`html_text()`](https://pedrobtz.github.io/zuhtml/reference/html_text.md)

## Examples

``` r
doc <- html_parse(
  "<a href='/x' class='btn  primary' data-id=7>Go</a><input disabled>"
)
body <- html_children(html_root(doc))[2]
nodes <- html_children(body)
html_attr(nodes, "href")
#> [1] "/x" NA  
html_attr(nodes, "href", default = "")
#> [1] "/x" ""  
html_attrs(nodes)
#> [[1]]
#>           href          class        data-id 
#>           "/x" "btn  primary"            "7" 
#> 
#> [[2]]
#> disabled 
#>       "" 
#> 
html_classes(nodes)
#> [[1]]
#> [1] "btn"     "primary"
#> 
#> [[2]]
#> character(0)
#> 
!is.na(html_attr(nodes, "disabled"))
#> [1] FALSE  TRUE
```
