# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this repository.

## What this is

An R package that parses real-world HTML with a **vendored copy of the
Gumbo parser** (the maintained fork at
<https://codeberg.org/gumbo-parser/gumbo-parser>) and extracts R objects
from it: nodesets selected by a CSS subset, attributes, text, and
ordinary data frames from lists, tables and links. No system HTML
library, no libxml2, no Python, no browser. Zero hard runtime
dependencies. It deliberately does not fetch, execute JavaScript,
sanitize, mutate the DOM, or support XPath. A fetcher such as `zuhttp`
hands it a string.

Two documents outrank this file.
[.agents/design.md](https://pedrobtz.github.io/zuhtml/.agents/design.md)
is the specification of every contract.
[.agents/roadmap.md](https://pedrobtz.github.io/zuhtml/.agents/roadmap.md)
is the stage-by-stage plan to 0.1.0; its opening review records where
the design was found wrong by measurement and the seven amendments the
design still owes. `CLAUDE.md` orients, the design decides, the roadmap
sequences.

The sibling package `zuxml` (Expat, same author) is the pattern to copy
for vendoring, the immutable index-addressed arena, vectorized nodesets,
gate scripts and CRAN comments. zuhtml does not depend on it or share
code with it.

## Current state

Stage 0 is done: the design carries the seven amendments, `DESCRIPTION`
is real, and `src/init.c` registers one smoke entry point
(`C_zuh_loaded`) with dynamic lookup off and symbols forced. There is no
vendored Gumbo and no exported function yet. The probe harness
([.agents/probe-gumbo.c](https://pedrobtz.github.io/zuhtml/.agents/probe-gumbo.c))
holds the measurements the roadmap cites.

The roadmap’s **Status:** line under each stage is authoritative for
progress; update it there, not here.

## Stage tracking

Progress toward the next version is tracked as GitHub sub-issues, so the
parent issue shows a progress bar such as “6 of 7”.

- **One parent issue per target version**, titled with the bare version,
  for example `v0.1.0` (#2). Stages 0 to 10 are sub-issues \#3 to \#13.
- **One sub-issue per roadmap stage**, titled as the roadmap titles it,
  for example `Stage 2 — Ledger, abort and limits (the safety seam)`,
  linking to that section’s anchor. The roadmap has eleven stages, 0 to
  10.
- **Every tracking issue carries the `stage` label.**
- **Close a stage by merging its pull request.** Put `Closes #<n>` in
  the body. Never close a stage whose exit criteria are not met; record
  a deviation in the stage’s **Status:** line first.
- **The roadmap stays authoritative.** Adding, removing or renaming a
  stage means editing the roadmap and the sub-issues in the same change.
  Status never goes in a heading: it would change the anchor every issue
  links to.
- Close the parent issue when the version is tagged and released.

## Versioning

The first CRAN release is `0.1.0`. Until then the public API may change
freely; there are no reverse dependencies. After it, use the `.9000`
development convention. The roadmap’s scope table lists the 33 exports
that 0.1.0 ships and what is deferred; an argument or helper left out
can be added in a patch release, one shipped is a commitment.

## Commands

Run from the package root.

``` sh
Rscript -e 'devtools::load_all()'                # compile src/ and load
Rscript -e 'devtools::document()'                # roxygen -> NAMESPACE, man/
Rscript -e 'devtools::test()'                    # full testthat suite
Rscript -e 'devtools::test(filter = "<name>")'   # one test file
Rscript -e 'devtools::test(shuffle = TRUE)'      # order independence
Rscript -e 'devtools::check()'                   # R CMD check
air format .                                     # format R sources
```

The gate scripts under `tools/` do not exist yet. The roadmap names them
stage by stage, in zuxml’s shape: `verify-vendor`, `update-gumbo`,
`run-lint`, `run-sanitizers`, `run-fuzz`, `run-conformance`,
`run-benchmarks`. Add each to this list when it lands, and say whether
CI runs it.

## Architecture

Planned layout, from design §13 and the roadmap. Nothing below exists
yet.

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

The pipeline is: validate and decode input in R → `zuh_gumbo_parse()`
(pure C, the abortable region: Gumbo runs with the ledger as its
allocator) → iterative conversion into the frozen arena → bulk-free
every ledger block → an external pointer owned by R. Everything after
that (navigation, CSS matching, text, tables, serialization) reads the
arena and never touches Gumbo. Only `zuh_gumbo.c` includes a Gumbo
header.

## Invariants that are easy to break

- **The C core contains no R.** `zuh_*.c` never includes `R.h`; R glue
  lives in `r_api.c` and `init.c`. The sanitizer and fuzz drivers
  compile the core standalone, and that is the only reason those gates
  work.
- **No R API inside the abortable region.** `R_CheckUserInterrupt()` or
  `Rf_error()` between `setjmp` and Gumbo’s return long-jumps past the
  ledger and leaks every block. Parse latency is bounded by the depth
  and input caps instead; interrupts are polled only in loops over the
  frozen arena, which hold nothing but `R_alloc` memory.
- **Never call `gumbo_destroy_output()`.** It recurses per nesting
  level. All Gumbo memory goes through the ledger, so bulk free is the
  one teardown path, on success and on failure alike. A second path is a
  second set of bugs.
- **The depth limit is a parse-time patch, not a conversion check.**
  Parse time is quadratic in nesting depth (100k nested divs, half a
  megabyte, take 16 s; see the roadmap review). A check after Gumbo
  returns runs after the damage.
- **The vendor tree is upstream plus exactly the patch series.**
  `tools/verify-vendor` re-derives `src/vendor/gumbo/` from the pinned
  archive and `tools/patches/`; any other edit fails it. Each patch is
  minimal, versioned and submitted upstream. The no-stdio patch has a
  canary: the lint gate asserts the shared object references no
  `printf`/`stderr` symbol.
- **The memory cap is the real guard; the input cap is a pre-check.**
  Gumbo allocates about 17 bytes per input byte on ordinary markup and
  up to 47 on formatting-heavy markup. The two defaults must stay
  consistent with that ratio, and a page that trips the memory cap first
  is a classed error, not a bug.
- **Portable make only** in `src/Makevars`: no GNU conditionals, no
  `$(shell)`, no `-W*` overrides. Any of them costs a CRAN rejection or
  `SystemRequirements: GNU make`.
- **Node IDs are document-local and an `NA_integer_` ID is a missing
  node**, distinct from a zero-length nodeset. Aligned operations
  (`html_element()`, `html_parent()`) preserve length and return missing
  nodes; set operations (`html_elements()`) deduplicate in document
  order. Mixing the two conventions silently misaligns extracted
  columns.
- **Template children stay children.** The template node carries a flag
  and descendant traversal skips them unless `html_template_content()`
  asks. There is no separate fragment object.
- **Errors are classed conditions** under `zuhtml_error`, with the
  subclasses listed in design §12. C returns a status enum; R maps the
  enumerator, never the message text.

## Testing conventions

- **Self-sufficient.** Every test builds its own inputs inside the
  `test_that()` block. No file-scope objects.
- **Self-contained.** Global state goes through `withr::local_*()`,
  randomised input through
  [`withr::local_seed()`](https://withr.r-lib.org/reference/with_seed.html).
  Tests write only under
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html).
- **Assert on condition classes, never message text.** Use
  `expect_error(..., class = "zuhtml_<kind>_error")`. Wording belongs in
  snapshot tests.
- **Order independence.** `devtools::test(shuffle = TRUE)` is part of
  the definition of done.
- **Borrow a conformance suite before writing one.** Gumbo 0.14.0 ships
  61 html5lib/WPT tree-construction `.dat` files under
  `tests/tree_construction/`; they become `tools/conformance/` and the
  `run-conformance` gate, with a hand-picked dozen copied into
  `tests/testthat/fixtures/` for CRAN. They cover tree construction
  only, not selectors, text cleaning, tables or URLs. For URL
  resolution, RFC 3986 §5.4 lists the normal and abnormal examples
  verbatim; use them as-is. Serialization round-trip is an adjudicated
  oracle, not an axiom: the HTML spec does not guarantee it, so known
  non-fixed-points are listed rather than asserted away.
- **Never test through Python.** Beautiful Soup and pandas are
  exploratory comparators only; nothing under `tests/` may need them.
- **Helpers live in `tests/testthat/helper-*.R`.** None yet.
- **Stage pull requests carry the `full-ci` label**, so the full R CMD
  check matrix (all three platforms) runs before merge rather than only
  after.
- **Keep the suite inside the CRAN time budget.** No runtime to report
  yet.

## Definition of done

`devtools::document()` and `devtools::check()` clean, meaning 0 errors,
0 warnings and 0 notes. `devtools::test(shuffle = TRUE)` green.
`gctorture(TRUE)` clean when C changed. CI green on every leg. A
user-facing change also needs a test, roxygen documentation and a
`NEWS.md` entry. A change to a contract (the exports, limits, the patch
series, the arena layout) amends the design in the same commit. A stage
is done when its exit criteria pass in CI on all three platforms, not
when the code is written; a gate counts once it has been seen to fail.

## Editing rules

- roxygen comments are the source. Never edit `man/` or `NAMESPACE` by
  hand.
- There is no `README.Rmd`; edit `README.md` directly.
- Keep prose simple and short. One idea per sentence.
- Wrap roxygen text at 80 characters and run `air format .` on R
  sources.
- Use `lower_snake_case`; exported functions are `html_*` plus
  `zuhtml_info()`; native symbols are prefixed `zuh_`.
- Keep hard runtime dependencies at zero. Base data frames and
  list-columns, never tibble.
- Export and document public functions. Do not create roxygen topics for
  internal ones. Every export needs `@return` and runnable `@examples`.

## Continuous integration

Workflows come from `pedrobtz/r-actions`, pinned at `@v1`:
`r-cmd-check.yml` (quick profile on pull requests, full on `main` or
with the `full-ci` label), `coverage.yml` (writes the badge under
`.github/badges/`) and `pkgdown.yml`. The hardening and native-check
workflows the roadmap describes are not set up yet.

## Vendored native code

Gumbo, the codeberg fork, **Apache-2.0**, to be pinned at **0.14.0**
(tag commit `f7145e6e7700`, archive SHA-256
`eac82480b916d520e4c7938cbd593ceda34c9241cba04022a078550d0d324cfe`). Not
yet imported; Stage 1 of the roadmap.

- Pin a stable upstream release, never `master` or a release candidate.
- Record the tag, the commit and the checksums in
  `src/vendor/PROVENANCE`, and keep `tools/update-gumbo` mechanical:
  download, verify, extract the file list, apply `tools/patches/` in
  order.
- Keep upstream `COPYING` under `src/vendor/gumbo/`, declare every
  copyright holder found in the vendored file headers as `cph` in
  `Authors@R`, and write `inst/COPYRIGHTS` and `LICENSE.note`. Do not
  describe the whole package as MIT. Before writing the `License:`
  field, find the CRAN precedent for MIT packages bundling Apache-2.0
  code and copy it.
- Only the 11 parser translation units and their headers are vendored:
  no Python bindings, tests, benchmarks, examples, `visualc/`, Meson or
  autotools.

## Commits and pull requests

Short, imperative, sentence-case commit subjects, optionally scoped.
Keep each commit focused and do not sweep in unrelated files. A pull
request explains the user-visible outcome and the rationale, links
related issues, lists the checks that were run and the tests that were
skipped, and flags platform-sensitive or vendored changes. Performance
claims need evidence.

Never commit or push to the default branch. Work on a branch, open a
pull request, and leave it for review. Do not merge a pull request
unless you are told to.

When you find a defect, in this package or in an upstream tool, open an
issue for it rather than only working around it.
