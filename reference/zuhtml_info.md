# Report the zuhtml build configuration

Reports the bundled 'Gumbo' version and the local patches applied to it,
and runs two self-tests against the compiled parser. Intended for
diagnostics and bug reports: in a correct build both `parser_ok` and
`depth_limit_ok` are `TRUE`.

## Usage

``` r
zuhtml_info()
```

## Value

An object of class `zuhtml_info`: a list with elements `zuhtml_version`,
`gumbo_version`, `gumbo_patches` (a character vector of patch
identifiers, in the order applied), `parser_ok` (the bundled parser
builds the expected tree for a fixed document) and `depth_limit_ok` (the
parse-time nesting limit stops a deeply nested document).

## Examples

``` r
zuhtml_info()
#> zuhtml 0.0.0.9000
#> Gumbo:        0.14.0
#> Patches:      0001-max-tree-depth, 0002-no-stdio, 0003-modification-notices, 0004-selectedcontent-descendant, 0005-selectedcontent-end-tag, 0006-document-quirks-init
#> Parser:       ok
#> Depth limit:  ok
```
