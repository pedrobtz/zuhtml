# CLAUDE.md

<!-- markdownlint-disable-next-line MD013 -->
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An R package that parses real-world HTML with a **vendored copy of the Gumbo
parser** (the maintained fork at <https://codeberg.org/gumbo-parser/gumbo-parser>)
and extracts R objects from it: nodesets selected by a CSS subset, attributes,
text, and ordinary data frames from lists, tables and links. No system HTML
library, no libxml2, no Python, no browser. Zero hard runtime dependencies.
It deliberately does not fetch, execute JavaScript, sanitize, mutate the DOM,
or support XPath. A fetcher such as `zuhttp` hands it a string.

Two documents outrank this file. [.agents/design.md](.agents/design.md) is the
specification of every contract. [.agents/roadmap.md](.agents/roadmap.md) is
the stage-by-stage plan to 0.1.0; its opening review records where the design
was found wrong by measurement and the seven amendments the design still owes.
`CLAUDE.md` orients, the design decides, the roadmap sequences.

The sibling package `zuxml` (Expat, same author) is the pattern to copy for
vendoring, the immutable index-addressed arena, vectorized nodesets, gate
scripts and CRAN comments. zuhtml does not depend on it or share code with it.

## Current state

Stages 0 to 3 are done. Gumbo 0.14.0 is vendored with a three-patch
series. `html_parse()`/`html_read()` decode input, parse under the allocation
ledger with every limit enforced, and convert Gumbo's tree into a frozen,
index-addressed document (`src/zuh_document.h`): preorder node IDs, a
`subtree_end` index, interned element names, one string pool. The document
has no R-level node API yet; tests reach it through the internal tree dump.
Stage 4 (the R document and node API) is next. The probe harness
([.agents/probe-gumbo.c](.agents/probe-gumbo.c)) holds the measurements the
roadmap cites.

The roadmap's **Status:** line under each stage is authoritative for progress;
update it there, not here.

## Stage tracking

Progress toward the next version is tracked as GitHub sub-issues, so the
parent issue shows a progress bar such as "6 of 7".

- **One parent issue per target version**, titled with the bare version, for
  example `v0.1.0` (#2). Stages 0 to 10 are sub-issues #3 to #13.
- **One sub-issue per roadmap stage**, titled as the roadmap titles it, for
  example `Stage 2 — Ledger, abort and limits (the safety seam)`, linking to
  that section's anchor. The roadmap has eleven stages, 0 to 10.
- **Every tracking issue carries the `stage` label.**
- **Close a stage by merging its pull request.** Put `Closes #<n>` in the
  body. Never close a stage whose exit criteria are not met; record a
  deviation in the stage's **Status:** line first.
- **The roadmap stays authoritative.** Adding, removing or renaming a stage
  means editing the roadmap and the sub-issues in the same change. Status
  never goes in a heading: it would change the anchor every issue links to.
- Close the parent issue when the version is tagged and released.

## Versioning

The first CRAN release is `0.1.0`. Until then the public API may change
freely; there are no reverse dependencies. After it, use the `.9000`
development convention. The roadmap's scope table lists the 33 exports that
0.1.0 ships and what is deferred; an argument or helper left out can be added
in a patch release, one shipped is a commitment.

## Commands

Run from the package root.

```sh
Rscript -e 'devtools::load_all()'                # compile src/ and load
Rscript -e 'devtools::document()'                # roxygen -> NAMESPACE, man/
Rscript -e 'devtools::test()'                    # full testthat suite
Rscript -e 'devtools::test(filter = "<name>")'   # one test file
Rscript -e 'devtools::test(shuffle = TRUE)'      # order independence
Rscript -e 'devtools::check()'                   # R CMD check
air format .                                     # format R sources
```

Gate scripts, each run from the package root:

```sh
tools/update-gumbo 0.14.0      # re-vendor: download, verify, copy, patch, PROVENANCE
tools/verify-vendor            # vendor tree == archive + patches   (CI: hardening)
tools/verify-vendor --canary   # must pass by seeing a dropped patch (CI: hardening)
tools/run-lint                 # strict warnings; no stdio symbols  (CI: hardening)
tools/run-lint --canary        # symbol check sees 0002 reversed    (CI: hardening)
tools/run-conformance          # html5lib tree-construction fixtures vs the tree
                               # dump; --canary must fail every case (CI: hardening)
tools/run-sanitizers           # ASan+UBSan seam driver, fault injection at every
                               # allocation index, overflow canary; leak check and
                               # leak canary with ASAN_OPTIONS=detect_leaks=1
                               #                                    (CI: hardening)
```

The roadmap adds `run-fuzz` and `run-benchmarks` at later stages. Add each here when it lands, and say
whether CI runs it.

## Architecture

Planned layout, from design §13 and the roadmap. The html5lib fixtures live
in `tools/conformance/`. So far `R/conditions.R`,
`R/info.R`, `R/limits.R`, `R/parse.R`, `src/init.c`, `src/r_api.c`,
`src/zuh_gumbo.[ch]`, `src/zuh_memory.[ch]`, `src/zuh_document.[ch]`,
`src/zuh_status.h`, `src/zuh_r.h`, `src/vendor/` and the vendoring, lint and
sanitizer scripts in `tools/` exist.

```
R/                 parse.R, conditions.R, info.R, node.R, nodeset.R, select.R,
                   attributes.R, text.R, write.R, list.R, table.R, links.R
src/               init.c, r_api.c                       R-facing glue only
                   zuh_gumbo.c                            version-specific Gumbo adapter
                   zuh_memory.c                           allocation ledger, abort, limits
                   zuh_document.[ch]                      frozen immutable arena
                   zuh_selector.c, zuh_text.c, zuh_table.c, zuh_write.c
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
- **Node IDs are preorder.** Conversion assigns them in document order and
  records `subtree_end`, so a node's descendants are exactly
  `(id, subtree_end]`, and sorting IDs sorts by document order. Anything
  that builds or edits the arena must keep that.
- **Conversion allocations count toward fault injection.** Use
  `conv_malloc()` in `zuh_gumbo.c` for anything conversion allocates, so
  "fail every allocation index" keeps covering it.
- **Errors are classed conditions** under `zuhtml_error`, with the subclasses
  listed in design §12. C returns a status enum (`src/zuh_status.h`); R maps
  the enumerator (`zuh_status_names` in `R/parse.R`, same order), never the
  message text.
- **A document is owned by its external pointer from birth.** `C_zuh_doc_new()`
  makes the pointer and finalizer before parsing; `C_zuh_parse()` stores the
  malloc'd document in it before Gumbo runs. Keep every R allocation outside
  the window between `zuh_doc_new()` and that store.
- **Do not trust `iconv()`'s failure signal on raw input.** It can return the
  input unchanged (macOS) or with a NUL in it (Windows). UTF-16 is decoded
  in R (`zuh_utf16()`); for the ASCII-compatible rest, `zuh_iconv()`
  converts twice with different `sub=` bytes and rejects unchanged
  non-ASCII output, any NUL, and invalid UTF-8.

## Testing conventions

- **Self-sufficient.** Every test builds its own inputs inside the
  `test_that()` block. No file-scope objects.
- **Self-contained.** Global state goes through `withr::local_*()`, randomised
  input through `withr::local_seed()`. Tests write only under `tempdir()`.
- **Assert on condition classes, never message text.** Use
  `expect_error(..., class = "zuhtml_<kind>_error")`. Wording belongs in
  snapshot tests.
- **Order independence.** `devtools::test(shuffle = TRUE)` is part of the
  definition of done.
- **Borrow a conformance suite before writing one.** Gumbo 0.14.0 ships 61
  html5lib/WPT tree-construction `.dat` files under `tests/tree_construction/`;
  they become `tools/conformance/` and the `run-conformance` gate, with a
  hand-picked dozen copied into `tests/testthat/fixtures/` for CRAN. They cover
  tree construction only, not selectors, text cleaning, tables or URLs. For
  URL resolution, RFC 3986 §5.4 lists the normal and abnormal examples
  verbatim; use them as-is. Serialization round-trip is an adjudicated oracle,
  not an axiom: the HTML spec does not guarantee it, so known non-fixed-points
  are listed rather than asserted away.
- **Never test through Python.** Beautiful Soup and pandas are exploratory
  comparators only; nothing under `tests/` may need them.
- **Helpers live in `tests/testthat/helper-*.R`.** `helper-tree.R` renders a
  document in the html5lib test format (`tree_lines()`) through the
  internal `C_zuh_doc_dump`, which is also what the conformance gate
  compares; `doc_meta()` reads the internal document metadata.
- **Fault injection from R** goes through the internal
  `zuh_parse_bytes(..., fail_at = k)`. The exhaustive run over every index,
  with leak detection, is `tools/run-sanitizers`.
- **Timing assertions run on CI only** (`CI=true` and not under covr): the
  local R may be emulated (x86_64 under Rosetta is about 4× slower).
- **Stage pull requests carry the `full-ci` label**, so the full R CMD check
  matrix (all three platforms) runs before merge rather than only after.
- **Keep the suite inside the CRAN time budget.** No runtime to report yet.

## Definition of done

`devtools::document()` and `devtools::check()` clean, meaning 0 errors, 0
warnings and 0 notes. `devtools::test(shuffle = TRUE)` green. `gctorture(TRUE)`
clean when C changed. CI green on every leg. A user-facing change also needs a
test, roxygen documentation and a `NEWS.md` entry. A change to a contract (the
exports, limits, the patch series, the arena layout) amends the design in the
same commit. A stage is done when its exit criteria pass in CI on all three
platforms, not when the code is written; a gate counts once it has been seen to
fail.

## Editing rules

- roxygen comments are the source. Never edit `man/` or `NAMESPACE` by hand.
- There is no `README.Rmd`; edit `README.md` directly.
- Keep prose simple and short. One idea per sentence.
- Wrap roxygen text at 80 characters and run `air format .` on R sources.
- Use `lower_snake_case`; exported functions are `html_*` plus
  `zuhtml_info()`; native symbols are prefixed `zuh_`.
- Keep hard runtime dependencies at zero. Base data frames and list-columns,
  never tibble.
- Export and document public functions. Do not create roxygen topics for
  internal ones. Every export needs `@return` and runnable `@examples`.

## Continuous integration

Workflows come from `pedrobtz/r-actions`, pinned at `@v1`:
`r-cmd-check.yml` (quick profile on pull requests, full on `main` or with the
`full-ci` label), `coverage.yml` (writes the badge under `.github/badges/`)
and `pkgdown.yml`. `hardening.yaml` runs the vendor and lint gates with their canaries; later
stages add sanitizers, fuzzing and conformance to it.

## Vendored native code

Gumbo, the codeberg fork, **Apache-2.0**, pinned at **0.14.0**
(tag commit `f7145e6e7700`, archive SHA-256
`eac82480b916d520e4c7938cbd593ceda34c9241cba04022a078550d0d324cfe`), in
`src/vendor/gumbo/` with provenance in `src/vendor/PROVENANCE`. Re-vendor
with `tools/update-gumbo <version>`, never by hand.

- Pin a stable upstream release, never `master` or a release candidate.
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
  `0002-no-stdio.patch` and `0003-modification-notices.patch`. 0003 is
  licence-mandated (Apache-2.0 §4(b)), local only, and stays last: extend it
  whenever an earlier patch touches a new file. `tools/verify-vendor` fails
  on a modified file without the notice. The patch identifiers are also
  listed in `src/zuh_gumbo.c` and reported by `zuhtml_info()`.

## Commits and pull requests

Short, imperative, sentence-case commit subjects, optionally scoped. Keep each
commit focused and do not sweep in unrelated files. A pull request explains the
user-visible outcome and the rationale, links related issues, lists the checks
that were run and the tests that were skipped, and flags platform-sensitive or
vendored changes. Performance claims need evidence.

Never commit or push to the default branch. Work on a branch, open a pull
request, and leave it for review. Do not merge a pull request unless you are
told to.

When you find a defect, in this package or in an upstream tool, open an issue
for it rather than only working around it.
