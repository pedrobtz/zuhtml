# External HTML corpus

Real pages, saved by other projects, read to find out what this package
gets wrong. The html5lib fixtures in `tools/conformance/` check tree
construction case by case; this corpus checks whole pages from the wild:
what the parser builds from them, and what the extractors return.

Nothing here ships. `tools/` is excluded by `.Rbuildignore`, and the files
themselves are not committed: 52 MB of other projects' fixtures does not
belong in this repository's history. What is committed is enough to
reproduce the corpus exactly:

| file | what it is |
| --- | --- |
| `sources.tsv` | each upstream, pinned to a commit, with its licence and the files taken |
| `checksums.sha256` | every file's sha256; also the list of what to fetch |
| `expected.tsv` | what zuhtml currently makes of each file |
| `fetch` | downloads whatever is missing or stale into `files/`, then verifies all of it |
| `run` | reads everything and reports outcomes that **changed** |
| `sweep.R` | the reader behind `run`; its header documents every column |
| `github.R` | GitHub API helpers for `fetch --pin` |

```sh
tools/corpus/fetch             # download and verify (needs network)
tools/corpus/fetch --check     # re-verify what is already there
tools/corpus/fetch --pin       # rebuild checksums.sha256 after editing sources.tsv
tools/corpus/run               # compare against expected.tsv
tools/corpus/run --record      # rewrite expected.tsv
```

`fetch` skips a file only when it is present and its checksum matches, so
it can resume a partial `files/`. CI caches `files/` under a key derived
from `checksums.sha256`.

## Sources

| source | files | licence |
| --- | --- | --- |
| [Mozilla Readability](https://github.com/mozilla/readability) `test/test-pages` | 130 real articles saved from news and blog sites (`source.html`), and the article markup Readability extracts from each (`expected.html`) | Apache-2.0 |
| [htmlparser-benchmark](https://github.com/AndreasMadsen/htmlparser-benchmark) `files/` | 258 front pages of popular sites, the corpus JavaScript HTML parsers (htmlparser2, parse5, cheerio) are benchmarked on | MIT |
| [pandas](https://github.com/pandas-dev/pandas) `pandas/tests/io/data/html` | the 4 saved pages pandas tests `read_html()` on: real tables with spans, footnotes and formatting | BSD-3-Clause |

Notices stay with their projects; nothing is redistributed here.

## Why outcomes rather than passes

HTML never fails to parse, so "it parsed" says almost nothing. Each row of
`expected.tsv` records what the parser built and what the extractors
returned: node and problem counts, table cells, list items, links, the
length and a hash of the cleaned text, and whether the tree survives a
serialize-and-parse round trip. `run` fails on any change in any column.
Record a new baseline only when the change is understood and intended.

## The baseline, 2026-09-24

All the files are UTF-8, but not all say so. Since Stage 14, `html_read()`
decodes with a page's `<meta>` declaration as a browser does, and some
files keep a declaration from before they were converted to UTF-8:

* four htmlparser-benchmark pages declare `iso-8859-1`, so they decode as
  windows-1252, which garbles their few non-ASCII characters (a UTF-8
  `U+FFFD` reads as `ï¿½`), exactly as a browser shows them;
* `readability/qq` declares `gb2312`, and its UTF-8 bytes are not valid
  GBK, so it fails with `zuhtml_encoding_error`. Passing
  `encoding = "UTF-8"` reads it.

The other 521 pages parse. 362 round-trip exactly. 156 lose only
their doctype's public and system identifiers, which the HTML standard's
serializer never writes (`roundtrip` is `doctype`). The other 3 differ for
reasons `tools/conformance/roundtrip-deviations.txt` already lists:

* two pages have legacy doctypes that select quirks or limited-quirks
  mode; the serialized `<!DOCTYPE html>` selects no-quirks, and tree
  construction differs further on (category A);
* one page holds a raw C1 control character (U+0092, a Windows-1252
  apostrophe mis-encoded as UTF-8); it is serialized as itself and the
  parser's input decoder replaces it with U+FFFD on the second parse
  (category B).

## Relationship to `tests/testthat/`

This corpus finds bugs; the package's own suite keeps them fixed. When a
page here exposes a defect, the fix belongs in `tests/testthat/` as a
minimal committed fixture of a few lines, not as the original page.
