# Test fixtures

`tree-construction.dat` holds twelve html5lib tree-construction cases,
copied verbatim from the fixtures that Gumbo 0.14.0 ships. Those come from
web-platform-tests (`html/syntax/parsing/resources/`), under the 3-Clause
BSD License; see `inst/COPYRIGHTS`. The cases, in order:
`tests1.dat:1`, `adoption01.dat:1`, `tables01.dat:1`, `template.dat:1`, `svg.dat:1`, `math.dat:1`, `entities01.dat:1`, `comments01.dat:1`, `doctype01.dat:1`, `tests_innerHTML_1.dat:1`, `processing-instructions.dat:1`, `tests26.dat:1`.

The full set of 61 files runs in `tools/run-conformance`, outside the CRAN
tarball.

`whatwg/index-windows-1255.txt` and `whatwg/index-windows-1258.txt` are the
Encoding Standard's index files, downloaded unmodified from
<https://encoding.spec.whatwg.org/> on 2026-11-19 (header date 2024-09-18),
under CC BY 4.0; see `inst/COPYRIGHTS`. SHA-256:

- `index-windows-1255.txt`
  `4a3ca10dd8ef4ce06b929f6bf66d7ea8932ab3c06e07162b0f8a9536a692e6ac`
- `index-windows-1258.txt`
  `2236cdac45f5970629881d09908d13af96965f1c67617160734cbefb54aa3176`

`test-sniff.R` compares all 128 entries of each with `zuh_sb_tables`.
