## Submission

This is an update, 0.1.0 to 0.1.1. It fixes wrong results found by a
review of 0.1.0: legacy encodings that lost their last character, Markdown
output that rendered differently from the HTML, arguments mis-converted in
a C locale, and several extraction functions. One fix closes a
security problem: `html_json_ld(parse = TRUE)` no longer lets a page make
'jsonlite' read a local file or a URL. `NEWS.md` lists every change.

## Test environments

All on GitHub Actions, through the `pedrobtz/r-actions` workflows:

* macOS-latest, R release
* windows-latest, R release and R-devel
* ubuntu-latest, R release and R oldrel-1
* R-devel containers with CRAN's compilers: `clang23`, `ubuntu-clang`,
  `ubuntu-gcc16`
* UBSan, ASan, valgrind, gctorture, rchk, LTO and gcc `-fanalyzer`

## R CMD check results

0 errors | 0 warnings | 0 notes

## Bundled code

zuhtml bundles the Gumbo HTML5 parser
(<https://codeberg.org/gumbo-parser/gumbo-parser>, version 0.14.0) in
`src/vendor/gumbo/`, unchanged since 0.1.0. Gumbo is Apache-2.0; zuhtml's
own code is MIT. `LICENSE.note` explains how the two apply, and
`inst/COPYRIGHTS` reproduces every copyright notice in the vendored files.
Both copyright holders are listed as `cph` in `Authors@R`.

The vendored tree carries six small patches, listed in
`src/vendor/PROVENANCE`. They add a nesting-depth limit, remove the only
`printf()` call, add the modification notices Apache-2.0 requires, and fix
three memory-safety bugs found by fuzzing and valgrind.

New in 0.1.1, the tests compare two decoding tables with the WHATWG
Encoding Standard's index files, committed under
`tests/testthat/fixtures/whatwg/` (CC BY 4.0, noted in `inst/COPYRIGHTS`).

## Network use

Tests and vignettes do not use the network. The one example that reads a
web page runs only in interactive sessions.

## Method references

The package implements the WHATWG HTML Standard's parsing algorithm (through
Gumbo) and its encoding sniffing, and RFC 3986 for URL resolution. There are
no published papers describing its methods.
