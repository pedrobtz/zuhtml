# cran-comments

## Submission

This is a new submission: zuhtml 0.1.0.

zuhtml parses HTML the way a browser does and extracts R objects from it:
nodes selected by a subset of CSS, text, attributes, lists, tables, links,
forms and page metadata, and Markdown. It bundles the Gumbo HTML5 parser
(<https://codeberg.org/gumbo-parser/gumbo-parser>, version 0.14.0) under
`src/vendor/gumbo/`, so no system library is needed, and it has no hard
dependencies.

## Test environments

* local macOS (x86_64 R 4.5.2) — `R CMD check --as-cran`
* GitHub Actions, on every push to the default branch and on each release
  pull request:
  - R-devel in three R-hub containers: `r-hub/containers/clang23` (C built
    as `-std=gnu23` with CRAN's flags), `ubuntu-clang` and `ubuntu-gcc16`
  - ubuntu-latest, R release and oldrel-1
  - macOS-latest, R release
  - windows-latest, R release and R-devel

R-devel on Linux is covered by the R-hub containers, which carry the
compilers CRAN checks with. Windows R-devel is a runner row, since it has
no container equivalent; it is the flavor of CRAN's incoming pretest, which
is why no separate win-builder result is reported.

Beyond `R CMD check`, CI runs the package's own gates on every push, each
with a canary that proves it can fail:

* `tools/verify-vendor`: the vendored tree is the pinned upstream archive
  plus exactly the recorded patch series, byte for byte;
* `tools/run-lint`: project-owned C is clean under `-Werror -Wall -Wextra
  -Wpedantic -Wconversion -Wcast-qual`, and the shared object imports no
  stdio, `abort` or `exit` symbol;
* `tools/run-sanitizers`: the C core under AddressSanitizer,
  UndefinedBehaviorSanitizer and LeakSanitizer, with an allocation failure
  injected at every allocation index of a corpus (about 7,000 sites);
* `tools/run-conformance`: the 61 html5lib/WPT tree-construction fixture
  files the bundled parser ships, and a serialize-reparse round trip;
* `tools/run-fuzz`: libFuzzer over three targets (parsing, the round trip,
  selectors) for 60 seconds per push and 30 minutes nightly;
* `native-checks`: R CMD check under UBSan and ASan, valgrind with leak
  checking, gctorture and rchk;
* `tools/corpus/run`: 522 real pages from other projects' test suites
  (Readability, htmlparser-benchmark, pandas), pinned by commit and
  checksum, with the outcome of every page recorded and compared.

## Network use

`html_read()` can read a URL through base R's `url()`. The tests never use
the network: they read `file://` URLs and local connections. The one
example that reads a web page runs only in interactive sessions. The
vignettes use no network.

## R CMD check results

0 errors | 0 warnings | 1 note

### NOTE: New submission

Expected for a first submission.

## The bundled parser and its patches

Gumbo is Apache-2.0; zuhtml's own code is MIT. `LICENSE.note` explains how
the two licences apply, `inst/COPYRIGHTS` reproduces every copyright notice
found in the vendored files (Google Inc., and Bjoern Hoehrmann for the
UTF-8 decoder in `utf8.c`), and both holders are listed with role `cph` in
`Authors@R`. The `License:` and `Copyright:` fields follow those of
data.sketches, an MIT package bundling Apache-2.0 code.

The vendored tree is upstream 0.14.0 plus six local patches, recorded in
`src/vendor/PROVENANCE`:

1. a `max_tree_depth` option: tree construction is quadratic in nesting
   depth, and the limit bounds it while parsing;
2. removal of the library's only `printf()`, so the shared object makes no
   stdio call;
3. the modification notice Apache-2.0 section 4(b) requires, in each
   changed file;
4. and 5. fixes for two memory-safety bugs in 0.14.0's `<selectedcontent>`
   support that the package's fuzzing found, each reachable from one line
   of HTML: a heap use-after-free and a NULL dereference;
6. initialization of the document's quirks mode, which fragment parsing
   read uninitialized (found by valgrind).

The last three are being reported upstream.

## Method references

There are no published papers describing these methods. The package
implements published standards:

* HTML parsing: the WHATWG HTML Standard, section 13.2
  <https://html.spec.whatwg.org/multipage/parsing.html>, by way of the
  bundled parser;
* HTML serialization: the same standard, section 13.3;
* selectors: a documented subset of W3C Selectors Level 4
  <https://www.w3.org/TR/selectors-4/>;
* URL resolution: RFC 3986, section 5
  <https://www.rfc-editor.org/rfc/rfc3986#section-5>;
* encoding sniffing: the HTML Standard's prescan (section 13.2.3.2) and
  the WHATWG Encoding Standard's labels <https://encoding.spec.whatwg.org/>;
* microdata and form ownership: the HTML Standard, sections 5 and 4.10;
* Markdown output: CommonMark <https://spec.commonmark.org/> and the GitHub
  Flavored Markdown table extension <https://github.github.com/gfm/>.

## Acceptance criteria

The package design lists acceptance criteria (its section 14). Each, and
what verifies it:

| Criterion | Verified by |
|---|---|
| Builds from source on Windows, macOS and Linux with no system HTML library, Meson, Python or C++ | CI matrix above, source installs only |
| The pinned parser's tree-construction fixtures pass, fragments included | `tools/run-conformance`: all 1,878 applicable cases; 44 are refused by the input contract (NUL bytes or invalid UTF-8) and 12 need scripting, which the parser does not support. Twelve cases also run in `tests/testthat/test-serialize.R` |
| Allocation failure at any point is a clean, classed error that leaks nothing | `tools/run-sanitizers`: failure injected at every allocation index of the parser, the conversion, the serializer, the text cleaner, the Markdown writer and the table grid, under LeakSanitizer; `tests/testthat/test-seam.R` |
| Parser work is bounded: deep nesting cannot stall a session | the parse-time depth limit: 100,000 nested elements fail in milliseconds (`test-seam.R`) |
| Ownership: reachable nodes survive garbage collection; finalization is idempotent; dead and restored pointers are classed errors | `tests/testthat/test-nodeset.R`; gctorture and valgrind in `native-checks` |
| Selectors: every supported production, escapes, case rules, scoping, deduplication, and explicit rejection of every unsupported form | `tests/testthat/test-select.R` (40 rejection cases with exact positions); the `fuzz_selector` target |
| Lists: nesting, wrappers, empty and duplicate items | `tests/testthat/test-list.R` |
| Tables: spans, `rowspan=0`, row groups, overlaps, huge spans, ragged rows, empty versus missing cells, header rows, nested tables, leading zeros, duplicate names | `tests/testthat/test-table.R` |
| Text: inline boundaries, whitespace, non-breaking spaces, preformatted text, script, style and template content | `tests/testthat/test-text-clean.R` |
| URLs: relative, absolute, query-only and fragment-only references, dot segments, `<base>`, absent bases, malformed references; no network access | `tests/testthat/test-links.R`, including every RFC 3986 section 5.4 example verbatim |
| Round trip: parse, serialize, parse is structurally identical, except where the HTML standard itself does not guarantee it | `tools/run-conformance`: 1,785 of 1,878 cases are fixed points, and the other 93 are listed with the standard's reason for each; the `fuzz_roundtrip` target |
| Fuzzing finds no memory-safety failure in project-owned code | three targets under ASan and UBSan; the two findings were in the bundled parser and are patched (see above) |
| Markdown: every construct, escaping, nesting, emphasis only where CommonMark parses it back | `tests/testthat/test-markdown.R`; the corpus rendered back with a CommonMark renderer during development; `fuzz_parse` runs the writer on every node |
| Encoding: each source, each declaration form, the 1024-byte window, contradictions | `tests/testthat/test-sniff.R` |
| Input from files, URLs and connections: `file://` URLs, connections opened or not, compressed files, the read bound, the default base URL; no network in tests | `tests/testthat/test-read.R` |
| Metadata and forms: nested and `itemref` microdata, invalid JSON-LD, form ownership, every control type | `tests/testthat/test-metadata.R`, `tests/testthat/test-forms.R` |
| Performance measured separately for parsing, selection and extraction, per input shape | `tools/run-benchmarks` |
| `R CMD check --as-cran` clean on all three platforms | CI matrix; results above |

## Downstream dependencies

None. This is a new package.
