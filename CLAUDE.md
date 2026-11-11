# CLAUDE.md

<!-- markdownlint-disable-next-line MD013 -->
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Shared conventions

The portfolio's shared rules are synced into `.claude/shared/` from
`pedrobtz/packages:claude/shared/`. Never edit them here. Where this file and
a shared file disagree, this file wins for this package.

@.claude/shared/workflow.md
@.claude/shared/r-package.md
@.claude/shared/ci.md
@.claude/shared/native-code.md
@.claude/shared/correctness.md
@.claude/shared/assurance.md

## What this is

An R package that parses real-world HTML with a **vendored copy of the Gumbo
parser** (the maintained fork at
<https://codeberg.org/gumbo-parser/gumbo-parser>) and extracts R objects from
it: nodesets selected by a CSS subset, attributes, text, and ordinary data
frames from lists, tables and links. No system HTML library, no libxml2, no
Python, no browser. Zero hard runtime dependencies. It deliberately has no
HTTP client, and does not execute JavaScript, sanitize, mutate the DOM or
support XPath. `html_read()` reads a path, a URL (through base R's `url()`)
or a connection; a fetcher such as `zuhttp` hands it a string for anything
more.

Two documents outrank this file. [.agents/design.md](.agents/design.md) is the
specification of every contract. [.agents/roadmap.md](.agents/roadmap.md) is
the stage-by-stage plan to 0.1.0; its opening review records where the design
was found wrong by measurement and the seven amendments the design still owes.
`CLAUDE.md` orients, the design decides, the roadmap sequences.

The sibling package `zuxml` (Expat, same author) is the pattern to copy for
vendoring, the immutable index-addressed arena, vectorized nodesets, gate
scripts and CRAN comments. zuhtml does not depend on it or share code with it,
apart from `R/zu_source.R`, which is copied verbatim from zuxml.

## Current state

Version 0.1.0 is on CRAN, published 2026-10-06 (crandb, checked
2026-11-11). The default branch is `0.1.0.9000`; its `NEWS.md` section holds
the `html_read()` open-failure change made through `zu_source.R`'s `fail`
hook.

All eighteen roadmap stages, 0 to 17, are done; Stage 17 was the 0.1.0
release. Stages 10 to 15 widened 0.1.0 after a survey of other languages'
HTML libraries, adding:

- `html_closest()`, `html_strings()` and `pretty =`;
- page metadata;
- table options;
- `html_markdown()` in `src/zuh_markdown.c`;
- `<meta>` encoding sniffing;
- `html_forms()`.

Stage 16 made `html_read()` read URLs and connections. Every export is
documented with runnable examples and a family. Four vignettes and a
pkgdown-only article of real pages are written. Gumbo 0.14.0 is vendored with
a six-patch series. The upstream reports of the patched Gumbo bugs are the
maintainer's to make. The probe harness
([.agents/probe-gumbo.c](.agents/probe-gumbo.c)) holds the measurements the
roadmap cites.

The roadmap's **Status:** line under each stage is authoritative for progress;
update it there, not here. Status never goes in a stage heading: it would
change the anchor every stage issue links to.

## Versions and dependents

The current version's parent issue is `#48` for `v0.1.1`. The `v0.1.0`
parent was `#2`: Stages 0 to 9 were sub-issues #3 to #12, Stages 10 to
15 #26 to #31, Stage 16 #40 and Stage 17 (the release) #13, renumbered twice.

Sibling packages that depend on this one: `zuhttp` lists
`zuhtml (>= 0.1.0)` in `Suggests` (local clones, 2026-11-11).

The roadmap's scope table lists the 33 exports that 0.1.0 ships and what is
deferred. An argument or helper left out can be added in a patch release; one
shipped is a commitment.

## Commands

The everyday `devtools` commands are in `.claude/shared/r-package.md`. Gate
scripts, each run from the package root:

```sh
tools/update-gumbo 0.14.0      # re-vendor: download, verify, copy, patch, PROVENANCE
tools/verify-vendor            # vendor tree == archive + patches   (CI: hardening)
tools/verify-vendor --canary   # must pass by seeing a dropped patch (CI: hardening)
tools/run-lint                 # strict warnings; no stdio symbols  (CI: hardening)
tools/run-lint --canary        # flags reject a planted warning; symbol
                               # check sees 0002 reversed        (CI: hardening)
tools/run-conformance          # html5lib tree-construction fixtures vs the tree
                               # dump, plus a serialize-reparse round trip;
                               # --canary and --canary-serialize must fail
                               #                                    (CI: hardening)
tools/run-fuzz [secs]          # fuzz_selector, fuzz_parse, fuzz_roundtrip under
                               # ASan+UBSan: libFuzzer, or a standalone mutation
                               # loop where it is missing (macOS); seeds include
                               # every conformance #data block; fuzz_canary must
                               # crash first. 60 s per push, 30 min nightly
                               #                                    (CI: hardening)
tools/run-sanitizers           # ASan+UBSan seam driver, fault injection at every
                               # allocation index, overflow canary; leak check and
                               # leak canary with ASAN_OPTIONS=detect_leaks=1
                               #                                    (CI: hardening)
tools/corpus/fetch             # fetch the external HTML corpus: 522 real pages
                               # from Readability, htmlparser-benchmark, pandas
tools/corpus/run [--record]    # compare what zuhtml makes of each page with
                               # expected.tsv; --canary must fail   (CI: corpus)
tools/run-benchmarks           # parse, select and table timings with native
                               # memory, per input shape; not a CI gate
```

Add each new gate here when it lands, and say whether CI runs it.

## Architecture

The layout, from design §13 and the roadmap. The html5lib fixtures live in
`tools/conformance/`.

```text
R/                 parse.R, conditions.R, info.R, node.R, nodeset.R, select.R,
                   attributes.R, text.R, write.R, list.R, table.R, links.R,
                   metadata.R, markdown.R, sniff.R, forms.R,
                   zu_source.R (copied verbatim from zuxml; edit there)
src/               init.c, r_api.c, r_node.c, r_select.c, r_extract.c
                                        R-facing glue only
                   zuh_gumbo.c          version-specific Gumbo adapter
                   zuh_memory.c         allocation ledger, abort, limits
                   zuh_document.[ch]    frozen immutable arena
                   zuh_selector.c, zuh_text.c, zuh_table.c, zuh_write.c,
                   zuh_markdown.c, zuh_buf.c
                   zuh_status.h, zuh_r.h
                   Makevars, vendor/gumbo/, vendor/PROVENANCE
tools/             gate scripts, patches/, conformance/ fixtures (not in the tarball)
fuzz/              libFuzzer targets over the C core
.agents/           design, roadmap, probe harness
```

The pipeline is: validate and decode input in R → `zuh_gumbo_parse()` (pure C,
the abortable region: Gumbo runs with the ledger as its allocator) → iterative
conversion into the frozen arena → bulk-free every ledger block → an external
pointer owned by R. Everything after that (navigation, CSS matching, text,
tables, serialization) reads the arena and never touches Gumbo. Only
`zuh_gumbo.c` includes a Gumbo header.

## Invariants that are easy to break

- **The C core contains no R.** `zuh_*.c` never includes `R.h`; R glue lives
  in `r_api.c` and `init.c`. The sanitizer and fuzz drivers compile the core
  standalone, and that is the only reason those gates work.
- **No R API inside the abortable region.** `R_CheckUserInterrupt()` or
  `Rf_error()` between `setjmp` and Gumbo's return long-jumps past the ledger
  and leaks every block. Parse latency is bounded by the depth and input caps
  instead; interrupts are polled only in loops over the frozen arena, which
  hold nothing but `R_alloc` memory.
- **Never call `gumbo_destroy_output()`.** It recurses per nesting level. All
  Gumbo memory goes through the ledger, so bulk free is the one teardown path,
  on success and on failure alike. A second path is a second set of bugs.
- **The depth limit is a parse-time patch, not a conversion check.** Parse
  time is quadratic in nesting depth (100k nested divs, half a megabyte, take
  16 s; see the roadmap review). A check after Gumbo returns runs after the
  damage.
- **The vendor tree is upstream plus exactly the patch series.**
  `tools/verify-vendor` re-derives `src/vendor/gumbo/` from the pinned archive
  and `tools/patches/`; any other edit fails it. Each patch is minimal,
  versioned and submitted upstream. The no-stdio patch has a canary: the lint
  gate asserts the shared object references no `printf`/`stderr` symbol.
- **The memory cap is the real guard; the input cap is a pre-check.** Gumbo
  allocates about 17 bytes per input byte on ordinary markup and up to 47 on
  formatting-heavy markup. The two defaults must stay consistent with that
  ratio, and a page that trips the memory cap first is a classed error, not a
  bug.
- **Portable make only** in `src/Makevars`: no GNU conditionals, no
  `$(shell)`, no `-W*` overrides. Any of them costs a CRAN rejection or
  `SystemRequirements: GNU make`.
- **Node IDs are document-local and an `NA_integer_` ID is a missing node**,
  distinct from a zero-length nodeset. Aligned operations (`html_element()`,
  `html_parent()`) preserve length and return missing nodes; set operations
  (`html_elements()`) deduplicate in document order. Mixing the two
  conventions silently misaligns extracted columns.
- **Template children stay children.** The template node carries a flag and
  descendant traversal skips them unless `html_template_content()` asks. There
  is no separate fragment object.
- **Node accessors return NULL for a bad pointer or ID.** Every entry in
  `src/r_node.c` validates the pointer and every ID (`checked()`) and
  returns `R_NilValue` rather than erroring; `zuh_checked()` in
  `R/node.R` turns that into `zuhtml_pointer_error`. Wrap every accessor
  `.Call()` in it, and name the routine in the `.Call()` itself: R CMD
  check flags `.Call(fun, ...)` with a variable routine.
- **Node IDs are preorder.** Conversion assigns them in document order and
  records `subtree_end`, so a node's descendants are exactly
  `(id, subtree_end]`, and sorting IDs sorts by document order. Anything
  that builds or edits the arena must keep that.
- **The selector subset is a closed list.** `zuh_selector.c` accepts
  exactly design §6's productions; every other form must fail with
  `ZUH_SEL_UNSUPPORTED` and a position, and `test-select.R` has a rejection
  test per form. Adding a production means amending the design first.
- **Strings built for R use an R_alloc-backed `zuh_buf`.** Pass
  `zuh_r_alloc` to `zuh_buf_init()` in R-facing code, so an R allocation
  failure while a string is being built strands no `malloc` memory. The
  core's own callers (the sanitizer driver, fuzz targets) pass `NULL` and
  `zuh_buf_free()`.
- **`x[0]` drops, it does not give NA.** Table slots are 0-based with -1
  for a gap; convert to R indices with gaps as `NA` first (`R/table.R`).
- **Pool strings can move.** In `zuh_selector.c`, anything that copies a
  pool string back into the pool must grow first and address the source
  after (`pool_dup()`); the fuzzer found the use-after-free the naive copy
  had.
- **Conversion allocations count toward fault injection.** Use
  `conv_malloc()` in `zuh_gumbo.c` for anything conversion allocates, so
  "fail every allocation index" keeps covering it.
- **Errors are classed conditions** under `zuhtml_error`, with the subclasses
  listed in design §12. C returns a status enum (`src/zuh_status.h`); R maps
  the enumerator (`zuh_status_names` in `R/parse.R`, same order), never the
  message text. Tests assert `class = "zuhtml_<kind>_error"`.
- **A document is owned by its external pointer from birth.**
  `C_zuh_doc_new()` makes the pointer and finalizer before parsing;
  `C_zuh_parse()` stores the malloc'd document in it before Gumbo runs. Keep
  every R allocation outside the window between `zuh_doc_new()` and that
  store.
- **Do not trust `iconv()`'s failure signal on raw input.** It can return the
  input unchanged (macOS) or with a NUL in it (Windows). UTF-16 is decoded
  in R (`zuh_utf16()`); for the ASCII-compatible rest, `zuh_iconv()`
  converts twice with different `sub=` bytes and rejects unchanged
  non-ASCII output, any NUL, and invalid UTF-8.
- **A contract change amends the design in the same commit.** The contracts
  are the exports, the limits, the patch series and the arena layout.

## Editing rules

Additions to, and deviations from, `.claude/shared/r-package.md`:

- **Deviation: there is no `README.Rmd`.** Edit `README.md` directly, and
  keep its example output in step with the code by running it.
- Vignettes live in `vignettes/` and run under R CMD check (`^vignettes$` is
  not in `.Rbuildignore`); keep them fast. `_pkgdown.yml` lists every export
  and article: add new ones there.
- Exported functions are `html_*` plus `zuhtml_info()`; native symbols are
  prefixed `zuh_`.
- Base data frames and list-columns, never tibble.
- Every export needs `@return` and runnable `@examples`.

## Testing

- **Conformance suite.** Gumbo 0.14.0 ships 61 html5lib/WPT
  tree-construction `.dat` files under `tests/tree_construction/`; they
  become `tools/conformance/` and the `run-conformance` gate. They cover tree
  construction only, not selectors, text cleaning, tables or URLs. For URL
  resolution, RFC 3986 §5.4 lists the normal and abnormal examples verbatim;
  use them as-is.
- **The CRAN-sized conformance subset** is
  `tests/testthat/fixtures/tree-construction.dat`: twelve cases copied
  verbatim, read by `read_dat()` in `helper-dat.R`. They are WPT material
  (3-Clause BSD): `inst/COPYRIGHTS` carries the notice, and any new fixture
  from elsewhere needs its own entry there.
- **Round-trip non-fixed-points are adjudicated, not asserted away.**
  Serialization round-trip is an adjudicated oracle, not an axiom: the HTML
  spec does not guarantee it. `tools/conformance/roundtrip-deviations.txt`
  lists each known non-fixed-point with its category and reason; the gate
  fails if the list and the results disagree either way.
- **Never test through Python.** Beautiful Soup and pandas are exploratory
  comparators only; nothing under `tests/` may need them.
- **The external corpus records outcomes, not passes.** `tools/corpus/`
  pins 522 real pages from other projects by commit and checksum (not
  committed) and records, per page, nodes, problems, table cells, list
  items, links, a hash of the cleaned text and the round-trip result.
  Any change in any column fails `tools/corpus/run`: understand it, then
  `--record`. A page that exposes a bug becomes a small fixture in
  `tests/testthat/`, never the page itself.
- **Real-world fixtures must be redistributable.**
  `tests/testthat/fixtures/realworld/` ships pandas' public-domain (FDIC,
  USDA) and synthetic tables and Readability's synthetic pages with its
  expected output, which serves as an oracle for `html_text_clean()` and
  `html_url()`. Saved news articles and site front pages stay in
  `tools/corpus/`: their content is the sites' copyright, whatever licence
  the collecting project uses. Add a notice to `inst/COPYRIGHTS` with any new
  fixture source.
- **Helpers.** `helper-tree.R` renders a document in the html5lib test format
  (`tree_lines()`) through the internal `C_zuh_doc_dump`, which is also what
  the conformance gate compares; `doc_meta()` reads the internal document
  metadata. `helper-dat.R` has `read_dat()`; `helper-timing.R` has
  `timing_asserted()`.
- **Fault injection from R** goes through the internal
  `zuh_parse_bytes(..., fail_at = k)`. The exhaustive run over every index,
  with leak detection, is `tools/run-sanitizers`.
- **Interrupts are tested with `setTimeLimit()`**, which R enforces where
  the C loops poll `R_CheckUserInterrupt()` (`test-interrupt.R`). Every
  R-facing loop over the frozen document polls.
- **Timing assertions are opt-in**: wrap them in `timing_asserted()`, true
  only where `ZUHTML_TIMING_TESTS=true`, which only `R-CMD-check.yaml` sets.
  Sanitizer, valgrind, gctorture, coverage and emulated builds are many times
  slower; the first native-checks run failed on exactly that.
- **Runtime.** About 4 s under `R CMD check` (2026-09-24); the heavy tests
  (16 MiB inputs, interrupts) are `skip_on_cran()`.

### Definition of done, in addition to the shared one

- `gctorture(TRUE)` clean when C changed.
- A stage is done when its exit criteria pass in CI on all three platforms,
  not when the code is written.
- A gate counts once it has been seen to fail.

## Continuous integration

- `R-CMD-check.yaml` calls r-actions' `r-cmd-check.yml@v1` and adds Windows
  on R-devel to the default runners, the combination CRAN's incoming pretest
  runs. **Deviation from `ci.md`:** it runs the quick profile on pull
  requests and the full profile on every push to `main` or with the
  `full-ci` label, rather than quick after merge. It alone sets
  `ZUHTML_TIMING_TESTS=true`.
- **Deviation from `ci.md`:** stage pull requests carried the `full-ci`
  label, so the full R CMD check matrix (all three platforms) ran before
  merge rather than only after.
- `coverage.yaml` calls `coverage.yml@v1` and writes the badge under
  `.github/badges/`.
- `native-checks.yaml` runs R CMD check instrumented through r-actions:
  `sanitizers.yml` (UBSan and ASan), `valgrind.yml` with leak checking,
  `gctorture.yml`, `rchk.yml` (hard-failing) and `cran-special.yml`.
- `hardening.yaml` (own) runs every gate script above with its canary, plus
  a nightly 30-minute fuzz run.
- `corpus.yaml` (own) fetches the external corpus and runs
  `tools/corpus/run`. It is separate because it fetches 52 MB over the
  network, which the package's own checks must never depend on; one platform
  is enough.
- `pkgdown.yaml` (own, from r-lib/actions' example) builds and deploys the
  site.
- The own workflows gate with `paths-ignore`, not `changes.yml` as `ci.md`
  asks; migrating them is open work.

## Vendored native code

Gumbo, the codeberg fork, **Apache-2.0**, pinned at **0.14.0**
(tag commit `f7145e6e7700`, archive SHA-256
`eac82480b916d520e4c7938cbd593ceda34c9241cba04022a078550d0d324cfe`), in
`src/vendor/gumbo/` with provenance in `src/vendor/PROVENANCE`. Re-vendor
with `tools/update-gumbo <version>`, never by hand.

- Record the tag, the commit and the checksums in `src/vendor/PROVENANCE`, and
  keep `tools/update-gumbo` mechanical: download, verify, extract the file
  list, apply `tools/patches/` in order.
- Keep upstream `COPYING` under `src/vendor/gumbo/`, declare every copyright
  holder found in the vendored file headers as `cph` in `Authors@R` (Google
  Inc.; Bjoern Hoehrmann for the UTF-8 decoder in `utf8.c`), and keep
  `inst/COPYRIGHTS` and `LICENSE.note` current. Do not describe the whole
  package as MIT. The `License:`/`Copyright:` fields follow the CRAN
  precedent of `data.sketches` 0.1.1 (MIT package bundling Apache-2.0 code):
  `MIT + file LICENSE` and `Copyright: file inst/COPYRIGHTS`.
- Only the 12 parser translation units, their headers and `doc/COPYING` are
  vendored (`tools/gumbo-files.txt`): no Python bindings, tests, benchmarks,
  examples, `visualc/`, Meson or autotools.
- The patch series is `tools/patches/0001-max-tree-depth.patch`,
  `0002-no-stdio.patch`, `0003-modification-notices.patch`,
  `0004-selectedcontent-descendant.patch`,
  `0005-selectedcontent-end-tag.patch` and
  `0006-document-quirks-init.patch`. 0003 is licence-mandated
  (Apache-2.0 §4(b)) and local only; it must mark every file the series
  touches, so extend it when a new patch touches a new file.
  `tools/verify-vendor` fails on a modified file without the notice.
  0004 and 0005 fix upstream memory-safety bugs the fuzzer found, and 0006
  an uninitialized read valgrind found (issue #22).
- Every patch identifier is also listed in `src/zuh_gumbo.c`, reported by
  `zuhtml_info()` and asserted in `test-info.R`: update all three together.
