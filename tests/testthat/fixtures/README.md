# Test fixtures

`tree-construction.dat` holds twelve html5lib tree-construction cases,
copied verbatim from the fixtures that Gumbo 0.14.0 ships. Those come from
web-platform-tests (`html/syntax/parsing/resources/`), under the 3-Clause
BSD License; see `inst/COPYRIGHTS`. The cases, in order:
`tests1.dat:1`, `adoption01.dat:1`, `tables01.dat:1`, `template.dat:1`, `svg.dat:1`, `math.dat:1`, `entities01.dat:1`, `comments01.dat:1`, `doctype01.dat:1`, `tests_innerHTML_1.dat:1`, `processing-instructions.dat:1`, `tests26.dat:1`.

The full set of 61 files runs in `tools/run-conformance`, outside the CRAN
tarball.
