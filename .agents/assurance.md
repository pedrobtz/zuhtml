# Assurance

How this package meets the shared `assurance.md` rules. CI checks this
file (r-actions `assurance.yml`), so keep the headings and table
columns as they are.

- **Statuses:** a cell is a fact, `gap #<issue>` or `n/a: <reason>`.

## Kinds

`compiled` `untrusted-input` `spec` `lifecycle` `emits`

## Why these kinds

- `compiled`: `src/` holds the R glue, the C core (`zuh_*.c`) and vendored
  Gumbo 0.14.0 with its patch series.
- `untrusted-input`: `html_parse()`, `html_fragment()` and `html_read()`
  parse bytes from anywhere, in any declared or sniffed encoding, and the
  selector compiler parses caller-supplied CSS.
- `spec`: WHATWG HTML tree construction and serialization, the Encoding
  Standard's `<meta>` prescan and labels, the CSS selector subset of design
  §6, RFC 3986 reference resolution, the HTML table model.
- `lifecycle`: the `zuhtml_document` external pointer outlives the parse,
  and every `zuhtml_nodeset` holds it.
- `emits`: `html_serialize()` writes HTML a browser or another parser
  reads; `html_markdown()` writes CommonMark.

## Required checks

`Where` names the workflow file under `.github/workflows/` that runs the
check. Add `(own)` when that workflow is the package's own rather than a
call to r-actions.

| Check         | Status   | Where                    |
| ------------- | -------- | ------------------------ |
| sanitizers    | done     | native-checks.yaml       |
| valgrind      | done     | native-checks.yaml       |
| rchk          | done     | native-checks.yaml       |
| gctorture     | done     | gctorture.yaml           |
| analyzers     | done     | native-checks.yaml       |
| alloc-failure | gap #62   |                          |
| mutation      | gap #63   |                          |
| fuzz          | done     | hardening.yaml (own)     |
| fuzz-reach    | gap #64   |                          |

`alloc-failure` is a gap although `tools/run-sanitizers` and
`zuh_parse_bytes(fail_at = k)` fail every allocation of the C core in turn:
those runs fail the ledger's and conversion's allocations, never R's. The
check asks for R's included, which is where an `R_alloc` longjmp while
`malloc` memory is live would show (#86 is one such case).

`fuzz` is the `fuzz` job of `hardening.yaml`: libFuzzer under ASan and UBSan
(a standalone mutation loop on macOS) over `fuzz_parse`, `fuzz_selector`
and `fuzz_roundtrip`, seeded with every conformance `#data` block, with a
canary that must crash first. Its oracle is memory safety, plus for
`fuzz_roundtrip` that the reparse succeeds. Nothing measures its reach.

## Boundaries

One row per boundary the package crosses. An oracle knows the answer:

- a conformance suite or test vectors;
- a reference implementation;
- a round trip;
- equivalent inputs compared;
- the bytes the other side received.

"No crash" is not an oracle.

<!-- markdownlint-disable MD013 -->
| Boundary | Oracle | Carried by |
| --- | --- | --- |
| HTML bytes → tree (document and fragment tree construction) | the 61 html5lib/WPT tree-construction `.dat` files, compared with the `C_zuh_doc_dump` rendering; `deviations.txt` empty; a corrupted rendering must fail every case | tools/run-conformance (hardening.yaml); 12 cases in tests/testthat/test-serialize.R from fixtures/tree-construction.dat |
| Tree → HTML (`html_serialize()`) | round trip over every html5lib case: serialize, reparse in the same context, compare trees; 144 adjudicated non-fixed points in `roundtrip-deviations.txt`, failing on a mismatch either way; a corrupted serializer must fail | tools/run-conformance --canary-serialize (hardening.yaml); tests/testthat/test-serialize.R; fuzz/fuzz_roundtrip.c |
| Raw bytes → UTF-8: BOM, `encoding =`, UTF-16 decoder in R | hand-written answers only; nothing compares `zuh_utf16()` with an independent decoder | gap #65 |
| `<meta>` prescan and encoding labels | hand-written answers transcribed from the algorithm; the label table is never diffed against WHATWG `encodings.json` | gap #66 |
| Legacy encodings → UTF-8 (windows-125x, GBK, Shift_JIS, Big5 through `iconv()`) | a few hand-written characters; nothing checks the WHATWG index tables | gap #67 |
| CSS selector text → match set | hand-written answers on one document; the rejection list per design §6 form | gap #68 |
| Tree → Markdown (`html_markdown()`) | hand-written answers; no CommonMark parser reads the output | gap #69 |
| Tree → text (`html_text()`, `html_strings()`) | hand-written answers | gap #70 |
| Tree → cleaned text (`html_text_clean()`) | Mozilla Readability's `expected.html`: each of its paragraphs appears in the cleaned text of `source.html`, over 11 synthetic pages | tests/testthat/test-realworld.R, fixtures/realworld/readability/ |
| Table → data frame (spans, headers, `convert`) | pandas' public-domain fixtures with known values; spans hand-written | gap #71 |
| List → R (`html_list()`) | hand-written answers | gap #72 |
| Reference → absolute URL (`html_url()`, `<base>`, `html_links()`) | RFC 3986 §5.4.1 and §5.4.2 examples verbatim; Readability's `expected.html` hrefs on the base-URL pages | tests/testthat/test-links.R; tests/testthat/test-realworld.R |
| Page metadata (`html_meta()`, `html_json_ld()`, `html_microdata()`) | hand-written answers | gap #73 |
| Forms (`html_forms()`: controls, selectedness, `form =` owner) | hand-written answers | gap #74 |
| Path, `file://` URL or connection → bytes (`html_read()`) | equivalent inputs: one file read as a path, a URL and a connection gives the same document; gzip and raw connections | tests/testthat/test-read.R |
<!-- markdownlint-enable MD013 -->

`tools/corpus/run` records nodes, problems, table cells, list items, links,
a cleaned-text hash and the round trip for 522 real pages against
`expected.tsv`. It catches change, not wrong answers, so it is no row's
oracle.

## Objects

One row per object that outlives the call that made it. "Sequences" is
the test of its out-of-order use (abort then read, use after end, use
after free). The guard columns name the test, or say why the guard
cannot apply.

<!-- markdownlint-disable MD013 -->
| Object | Sequences | Fork | Unwind | Owner |
| --- | --- | --- | --- | --- |
| `zuhtml_document` external pointer | tests/testthat/test-parse.R "a document restored from a saved session is a pointer error"; test-nodeset.R "finalization is idempotent and leaves a pointer error"; test-interrupt.R reuse after interrupts; only five accessors are tried on a dead document, gap #75 | n/a: immutable `malloc` memory and no OS handle or PID-bound state; a child's copy-on-write copy is its own to free | the pointer and finalizer exist before Gumbo runs; tests/testthat/test-seam.R and test-tree.R fail every allocation index; tools/run-sanitizers with leak detection | R, through the finalizer; `C_zuh_parse` frees at once on failure; borrows nothing |
| `zuhtml_nodeset` (IDs plus the document) | test-nodeset.R "a node ID outside its document is a pointer error" (through `html_name()` only, gap #75); "c() refuses nodes from different documents"; `[<-` and `[[<-` have no such guard, gap #82 | n/a: R integers and a reference to the document | n/a: no native state; C accessors use `R_alloc` and an `R_alloc`-backed `zuh_buf` | holds the document: test-nodeset.R "a nodeset keeps its document alive through garbage collection" |
| connection opened by `html_read()` | tests/testthat/test-read.R: text-mode and closed connections refused; a caller's open connection read from its position and kept; an unopened one opened in binary and closed | n/a: lives within one synchronous `html_read()` call and is never returned | test-read.R "unreadable URLs are input errors, without a warning or a leak" covers a failed open; an error after a successful open is untested, gap #76 | `html_read()` closes what it opened, on success and error; a caller's open connection stays the caller's |
<!-- markdownlint-enable MD013 -->

The compiled selector's external pointer lives inside one `C_zuh_select()`
call and is never returned, so it is no row; its finalizer covers an
interrupt in the match loop (test-interrupt.R).

## Findings that are bugs

The audit that wrote this file found these wrong results, filed as bugs
rather than gaps: #81 (legacy encodings refuse bytes the Encoding Standard
maps), #82 (sub-assignment mixes documents' node IDs), #83
(`max_selector_length` has no effect), #84 (unclassed native errors), #85
(the 4 × raw pre-check rejects stateful encodings) and #86 (a buffer leak
in the internal tree dump).

## Limits

One row per limit the package enforces. "Straddled by" is the test of
`limit - 1`, `limit` and `limit + 1` on every path that reaches it.

<!-- markdownlint-disable MD013 -->
| Limit | Unit | Straddled by |
| --- | --- | --- |
| `max_input` (16 MiB), decoded | UTF-8 bytes after decoding, BOM removed | character input at `limit` and `limit + 1` in tests/testthat/test-seam.R; raw, sniffed, UTF-16 and fragment paths untested, gap #77 |
| `max_input`, raw pre-checks (`html_parse(raw)`, file size, connection stream) | input bytes, 4 × `max_input` | over the limit only (tests/testthat/test-parse.R, test-read.R), gap #77 |
| `max_memory` (512 MiB) | ledger bytes, headers included; a payload estimate for conversion | over the limit only (tests/testthat/test-seam.R), gap #78 |
| `max_depth` (512, patch 0001) | Gumbo open-element stack; `html` and `body` count | over the limit only (tests/testthat/test-seam.R, test-fragment.R), gap #78 |
| `max_nodes` (4e6) | arena nodes, document node included | tests/testthat/test-tree.R at `limit - 1` and `limit` (203 and 204); fragments and `comments = FALSE` untested, gap #78 |
| `max_errors` (100) | parse errors kept | over the limit only (tests/testthat/test-problems.R), gap #78 |
| `max_table_cells` (1e6) | grid slots, spans expanded | over the limit only (tests/testthat/test-table.R, test-table-options.R), gap #79 |
| colspan clamp (1000) and rowspan clamp (65534) | columns, rows per cell | colspan 999999 → 1000 only (tests/testthat/test-table.R), gap #79 |
| `max_selector_length` (16 KiB) | selector bytes | over the limit only (tests/testthat/test-select.R), gap #80; the argument has no effect, gap #83 |
| `ZUH_SEL_MAX_COMPOUNDS` (128), `ZUH_SEL_MAX_NOT_DEPTH` (32) | compounds per complex selector, `:not()` nesting | 200 compounds only (tests/testthat/test-select.R), gap #80 |
| selector work limit (1e9) | compound tests per call | gap #80 |
<!-- markdownlint-enable MD013 -->
