# Real-world fixtures

Pages from other projects' test suites, small enough to ship with the
package and chosen so that their content can be redistributed. The full
external corpus, 522 pages, is in `tools/corpus/`, outside the tarball.

## pandas

`pandas/` is from pandas, `pandas/tests/io/data/html` at commit
`3f573414b99fe1f32676ed94784217af78c8751b`, BSD-3-Clause:

* `banklist.html`: the FDIC failed-bank list, a US government work;
* `spam.html`: a USDA nutrient table, a US government work;
* `valid_markup.html`: a small generated table.

## Mozilla Readability

`readability/` is from Mozilla Readability, `test/test-pages` at commit
`ab4027a8b37669745016869a37a504727992b2ba`, Apache-2.0. Only the
synthetic test pages the project wrote itself (placeholder "lorem ipsum"
text) are included, not its saved news articles. Each directory holds
`source.html` and `expected.html`, the article markup Readability extracts
from it; the tests check zuhtml against the latter.

Licence notices are reproduced in `inst/COPYRIGHTS`.
