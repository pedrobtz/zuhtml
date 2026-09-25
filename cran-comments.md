## Submission

This is a new submission.

zuhtml bundles the Gumbo HTML5 parser
(<https://codeberg.org/gumbo-parser/gumbo-parser>, version 0.14.0) in
`src/vendor/gumbo/`, so it needs no system library.

## Test environments

* local macOS, R 4.5.2
* GitHub Actions: ubuntu-latest (R release, oldrel-1), macOS-latest
  (R release), windows-latest (R release, R-devel)
* R-hub containers, R-devel: `clang23`, `ubuntu-clang`, `ubuntu-gcc16`
* UBSan, ASan, valgrind, gctorture and rchk

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Bundled code

Gumbo is Apache-2.0; zuhtml's own code is MIT. `LICENSE.note` explains how
the two apply, and `inst/COPYRIGHTS` reproduces every copyright notice in
the vendored files. Both copyright holders are listed as `cph` in
`Authors@R`.

The vendored tree carries six small patches, listed in
`src/vendor/PROVENANCE`. They add a nesting-depth limit, remove the only
`printf()` call, add the modification notices Apache-2.0 requires, and fix
three memory-safety bugs found by fuzzing and valgrind. The fixes are being
reported upstream.

## Network use

Tests and vignettes do not use the network. The one example that reads a
web page runs only in interactive sessions.
