# zuhtml — Roadmap to 0.1.0 (first CRAN release)

Companion to [design.md](design.md). Section references (§) point there. Format and rules follow zuxml's `.agents/roadmap.md`: a heading is `## Stage N — Title · Size` and nothing else; a stage's state is the **Status:** line under it, so GitHub anchors never change.

Sizes are relative: **S** ≈ a sitting, **M** ≈ a few, **L** ≈ the stage is the week.

---

## Design review 2026-09-24

A read of the design against the real Gumbo archives and a probe harness ([probe-gumbo.c](probe-gumbo.c), compiled against 0.14.0 with a counting allocator, run on macOS arm64). The design is sound in its architecture — vendored parser, index-addressed immutable arena, vectorized nodesets, CSS subset, character-first tables — and repeats what worked in zuxml. Its problems are three: it pins a superseded release, two of its safety numbers are contradicted by measurement, and its 0.1.0 surface is roughly twice what a first CRAN release can carry without shipping mistakes it can never take back.

### Verified against the archives

| Claim in the design | Finding |
|---|---|
| Pin 0.13.2 (§1, §13) | **0.14.0 was released 2026-08-26**, after the design's investigation. It adds a top-level `COPYING`, ships 61 html5lib/WPT tree-construction `.dat` fixtures under `tests/tree_construction/` (0.13.2 ships none), drops the Ragel dependency (24.8k lines vs 36.2k), fixes a doctype-token memory leak, adds `GUMBO_NODE_PROCESSING_INSTRUCTION` and `gumbo_tag_is_void()`. SHA-256 of `0.14.0.tar.gz`: `eac82480b916d520e4c7938cbd593ceda34c9241cba04022a078550d0d324cfe`. The 0.13.2 digest in §13 is correct. |
| Allocation failure is unchecked (§12) | Confirmed in 0.14.0: `gumbo_copy_stringz()` and the string-buffer paths use the result of `gumbo_parser_allocate()` unchecked, and `gumbo.h` still carries the `TODO(jdtang)` on out-of-memory. **But `GumboOptions` has `allocator`, `deallocator` and `userdata` hooks**, so the allocation ledger needs no patch; only the abort needs a `longjmp` out of the allocator. |
| Bound parser work; a post-parse depth check is insufficient (§12) | **Stronger than the design says.** Parse time is quadratic in nesting depth: 10k nested `<div>` 0.14 s, 50k 3.5 s, 100k (500 KB of input) 16.3 s, 1M killed at 120 CPU-seconds. The fork has no depth option and no work guard beyond an `assert(loop_count < 1e9)` that `-DNDEBUG` removes. `gumbo_destroy_output()` is recursive (`destroy_node`). A depth check during conversion, as §12 proposes, runs after the damage. The same mechanism makes repeated `<a><b>` (adoption agency on an ever-growing stack) quadratic. |
| 64 MiB input, 256 MiB native memory (§12) | **Contradictory.** Peak Gumbo allocation is ~17× the input for ordinary markup (16.7 MB → 277 MB), ~13× for block nesting, ~47× for formatting-element-heavy markup, ~190× for pure nesting. 64 MiB of ordinary markup needs ~1 GiB before zuhtml copies anything. 16.7 MB also produced ~1.25M nodes, past the 1M node limit. |
| Limits per operation (§12) | With depth capped at 500, 16 MiB of sawtooth markup parses in 1.5 s and 9 MB of formatting-heavy markup in 0.95 s. **Parse latency is bounded by the depth and input caps alone**, so the interrupt/cancellation machinery of §12 is not needed on the parse path for 0.1.0. |
| Compile the Meson units through Makevars (§13) | Confirmed: 11 C units. Every unit `#include <strings.h>` unconditionally; Rtools' MinGW provides it, so no shim is expected — verify on Windows CI at Stage 1. |
| R CMD check hygiene | `gumbo_print_caret_diagnostic()` in `error.c` calls `printf` and will draw the "possibly from 'printf'" NOTE. `assert` is compiled out because R adds `-DNDEBUG` (verified in `etc/Makeconf`), so no `abort` NOTE. |
| `GumboError` is internal (§5) | Confirmed: 42 `GumboErrorType` values in the non-public `error.h`; `gumbo_error_to_string()` needs the internal parser struct. `max_errors` and `stop_on_first_error` are public options and map 1:1 to `html_limits(max_errors)`. |
| Run the upstream tree-construction fixtures (§14) | Only possible from 0.14.0; they are in the html5lib `#data/#errors/#document` format with `#script-on/off` markers. |
| `<template>` needs a separate fragment (§4) | Gumbo represents template content as ordinary children of a `GUMBO_NODE_TEMPLATE` node. No separate fragment object is needed: mark the node and have descendant traversal skip its children unless `html_template_content()` is used. |

An alternative to the codeberg fork is the Gumbo tree vendored inside Nokogiri, which already has `max_tree_depth`, `max_attributes`, quirks-mode and string fragment contexts. Decision: **stay on the codeberg fork** — it has standalone releases and tags, so provenance and updates stay simple — and port Nokogiri's depth guard (an option field plus a ~10-line check in the parse loop that forces an EOF token) as a local patch, offered upstream.

### Amendments to make to design.md (Stage 0)

1. Pin **0.14.0**; update §13's measurements and digest; replace "abort to a live parser boundary" in §12 with the concrete mechanism in Stage 2.
2. §12: a **parse-time depth limit is a local patch**, not a conversion check; the conversion check stays as a second line. Add processing-instruction nodes (0.14.0) to `html_type()`.
3. §12 limits table: input **16 MiB**, native memory **512 MiB**, and state the measured memory ratios so the two are consistent. The memory cap is the real guard; the input cap is the cheap pre-check. A 16 MiB formatting-heavy page can trip the memory cap first — that is a classed error, not a bug.
4. §12: drop interrupt/cancellation from the parse path for 0.1.0; R-side loops over the frozen document (selector matching, text, tables) poll `R_CheckUserInterrupt()` and hold nothing that a long jump would leak (temporary buffers via `R_alloc`).
5. §2/§15: replace the first-release list with the scope below.
6. §4: template content as flagged children, not a separate fragment.
7. §8, §9, §10: remove the shared extraction-diagnostics framework (`html_extraction_problems()`, provenance attributes). Overlapping table cells are an error; rowspan clipping is silent and documented, as pandas does. Everything else that would have been a "problem record" is `NA`.

### Scope for 0.1.0

The principle: **an argument or export left out now can be added in 0.1.1 without breaking anyone; one shipped is a commitment.** Every helper below the line is pure R over the kept API and can ship in a fast follow-up.

**33 exports.**

| Area | Exports | Cut from the design (and why) |
|---|---|---|
| Parse | `html_parse(x, encoding, base_url, comments, limits)`, `html_read(path, ...)`, `html_fragment(x, context, ...)`, `html_problems()`, `html_info()`, `html_limits()`, `zuhtml_info()` | `html_read_connection()` (a fetcher passes a string); `keep_source`, `html_source_position()` (repaired trees make positions hints of little value); `errors=` (real pages always have parse errors, so `"warn"`/`"error"` fire on everything — `html_problems()` is the honest interface); `html_extract_limits()` folded into `html_limits()`; fragment `namespace=` |
| Navigate | `html_elements(x, css)`, `html_element(x, css)`, `html_matches()`, `html_filter()`, `html_children()`, `html_parent()`, `html_ancestors()`, `html_next_sibling()`, `html_previous_sibling()`, `html_root()`, `html_document()`, `html_template_content()` | `group=` on `html_elements()` (`lapply` does it); `html_find()` (a second query language, plus regex on text, to maintain and secure) |
| Values | `html_name()`, `html_namespace()`, `html_type()`, `html_attr(x, name, default)`, `html_attrs()`, `html_classes()`, `html_text(x, recursive)`, `html_text_clean(x, trim, nbsp)`, `html_serialize(x, outer)` | `html_has_attr()` (`!is.na(html_attr())`); `html_strings()`; `html_write()` (`writeLines(html_serialize())`) |
| Extract | `html_list(x, mode = c("text", "tree"))`, `html_table(x, header, trim, na, limits)`, `html_tables(x, css)`, `html_links(x, absolute)`, `html_url(x, attr, base_url)` | `mode = "data.frame"`, `nested_text`, `html_lists()`; `html_dl()`; `span = "anchor"`, `col_types`/`decimal_mark`/`grouping_mark` (a typed-conversion sub-project; `type.convert()` and readr exist), `name_repair` (always `make.unique()`, blanks become `V<n>`), `nested=` (outermost only), `html_table_cells()`, `html_table_meta()`; `html_images()`, `html_headings()`, `html_meta()`, `html_title()`, `html_description()`, `html_canonical()`, `html_data()`; `strict=` on `html_url()` |

Plus S3 methods on `zuhtml_nodeset`: `print`, `format`, `length`, `[`, `[[`, `c`, `rev`, `as.character` (serialize).

Kept deliberately even though each is a sub-project: the CSS subset of §6 unchanged (it is the product); `html_serialize()` (the round-trip oracle, as in zuxml); `html_url()` with RFC 3986 §5 resolution (without it `html_links()` is not useful, and the RFC's own §5.4 examples are a ready fixture); `html_table()` with the full grid algorithm (spans, `rowspan=0`, row groups, header policy).

---

## Sequencing principles

1. **The safety seam lands before the tree.** Ledger, abort, depth patch and limits are Stage 2, before anything converts a Gumbo tree. Retrofitting limits into code that assumes they hold is how zuxml's design says limit bugs get shipped, and the depth measurement above shows the parser cannot be trusted unbounded even for a test.
2. **Portability is proven at Stage 1.** `strings.h`, the patch series and the Windows toolchain are the schedule risk, and they surface on Windows.
3. **The serializer lands before the selector engine.** It is the oracle for the conformance gate and for every later stage's fixtures.
4. **Every stage ends with something runnable, tested, and green on all three platforms.** A criterion met differently from its wording goes in the **Status:** line.
5. **Gates need canaries.** A gate counts once it has been seen to fail (zuxml #35): a deliberate warning, a dropped patch, a target that must crash.
6. **The C core contains no R.** `zuh_*.c` files that the sanitizer and fuzz drivers compile standalone never include `R.h`; R glue lives in `r_api.c` and `init.c`.
7. **A change to a contract amends the design in the same commit.**

---

## Stage 0 — Repo hygiene and design amendments · S

**Status:** done 2026-09-24. Deviation: `knitr`, `rmarkdown` and `VignetteBuilder: knitr` are left out until Stage 9 adds the vignettes; with no vignette they draw an incoming-feasibility NOTE and a dependency INFO.

- Amend `design.md` per the seven points above; keep §17's evidence section and add the probe measurements.
- `DESCRIPTION`: real `Title` (title case, under 65 characters, software names quoted, e.g. `Parse 'HTML' with a Bundled 'Gumbo' Parser`), a 3–4 sentence `Description` that does not start with the package name, `Authors@R` with Pedro Baltazar as `aut`/`cre`/`cph`, `Depends: R (>= 4.1)`, `URL` (GitHub and pkgdown), `BugReports`, `Suggests: testthat (>= 3.0.0), knitr, rmarkdown`, `VignetteBuilder: knitr`. Gumbo's copyright holders are added at Stage 1, when the code exists.
- `LICENSE`/`LICENSE.md` name the real holder and year 2026.
- `.Rbuildignore`: `^\.agents$`, `^tools$`, `^fuzz$`, `^cran-comments\.md$`, and patterns for vendored `*.o` (zuxml hit this at Stage 1).
- `src/init.c` with `R_registerRoutines()`, `R_useDynamicSymbols(dll, FALSE)`, `R_forceSymbols(dll, TRUE)` and one smoke entry point; `NAMESPACE` gets `useDynLib(zuhtml, .registration = TRUE)`.
- Replace the template test with a real `test-init.R`; an empty `testthat/` is a hard check ERROR.
- Set up `CLAUDE.md` in the zuxml shape: what this is, non-negotiables, layout, commands, gates, definition of done.
- Create the tracking issue for 0.1.0 with one `stage`-labelled sub-issue per stage, linking to these anchors.

**Exit:** `R CMD check --as-cran` passes with only the development-version NOTE; CI green on the existing r-actions matrix.

---

## Stage 1 — Vendor Gumbo 0.14.0, patch series, prove it builds · L

**Status:** done 2026-09-24. Deviations, each measured against the archive: meson compiles **12** units, not 11 (`char_ref_gperf.c` is separate), and the licence is `doc/COPYING`, not top-level. A third, licence-mandated patch `0003-modification-notices.patch` marks each modified file (Apache-2.0 §4(b)); `verify-vendor` enforces it, and it is never offered upstream. 0002 removes only `gumbo_print_caret_diagnostic()`: the `gumbo_debug()` `vprintf` is compiled only under `-DGUMBO_DEBUG`, and the symbol gate proves the shared object imports no stdio. Codeberg has no uploaded release asset, so the pin is the forge-generated archive (noted in `PROVENANCE`). `zuhtml_info()` reports version, patches and two self-tests; the compiled limits join it at Stage 2 with `html_limits()`. `License:`/`Copyright:` follow the CRAN precedent `data.sketches` 0.1.1. Patches 0001 and 0002 are **not yet submitted upstream**: that needs the maintainer's Codeberg account. Vendored Gumbo draws `-Wall -pedantic` warnings under clang (`-Wvoid-pointer-to-enum-cast`, `-Wunused-variable`, `-Wnewline-eof`), which R CMD check does not escalate; no patch until a check leg does.

The highest-risk stage; do not proceed until Windows is green.

**Do**
- Import the 11 parser units and their headers from the 0.14.0 archive into `src/vendor/gumbo/`, plus `COPYING`. No Python bindings, tests, benchmarks, examples, `visualc/`, Meson or autotools. Include the generated `char_ref_gperf.c`, `tag_*.h` and `tokenizer_states.h` as-is; regeneration is out of scope.
- `tools/update-gumbo <version>`: download the archive, verify its SHA-256, extract the file list in `tools/gumbo-files.txt`, apply `tools/patches/*.patch` in order. `tools/verify-vendor`: re-derive the tree from the pristine archive plus the patch series and diff it against `src/vendor/gumbo/`, so "byte-identical to upstream plus exactly these patches" is provable. Both run in CI.
- **Patch series**, each minimal, versioned, and submitted upstream on codeberg:
  - `0001-max-tree-depth.patch`: an `unsigned int max_tree_depth` field in `GumboOptions` (default 0 = unlimited, to keep `kGumboDefaultOptions` compatible), a `GumboOutput` status field, and the Nokogiri-style check in the main loop of `gumbo_parse_with_options()` that forces an EOF token once `_open_elements.length` exceeds the limit.
  - `0002-no-stdio.patch`: remove `gumbo_print_caret_diagnostic()` (the only `printf`) and the `GUMBO_DEBUG` `vprintf` body, so the shared object references no stdio symbol.
- `src/Makevars`: portable make only, `PKG_CPPFLAGS = -Ivendor/gumbo`, explicit `OBJECTS` list. No `-W*` overrides. `-fvisibility=hidden` is optional and only if it is warning-free on all three toolchains.
- `src/zuh_gumbo.c` (version-specific adapter, C only): wraps `gumbo_parse_with_options()`, includes the internal `error.h`, and exposes a stable `zuh_*` interface. Nothing else in the package includes a Gumbo header.
- `zuhtml_info()` reporting the Gumbo version, the applied patch identifiers and the compiled limits.
- **Licensing.** Gumbo is Apache-2.0. Record every copyright notice found in the vendored file headers (Google Inc. 2010 and the fork's maintainers — read the files, do not assume) as `cph` entries in `Authors@R` with a `comment` naming the bundled component. Write `inst/COPYRIGHTS`, `LICENSE.note` (zuhtml MIT, Gumbo Apache-2.0, where each text lives, that the tree is upstream plus the listed patches), `Copyright: see inst/COPYRIGHTS and src/vendor/PROVENANCE` in `DESCRIPTION`, and `src/vendor/PROVENANCE` with URL, tag, resolved commit (`f7145e6e7700`), archive digest, import date, file manifest and patch list. Before writing the `License:` field, find the CRAN precedent for a package bundling Apache-2.0 code under a different package licence and follow it exactly.

**Exit**
- Installs from source on Windows, macOS and Linux with no system library, Meson, Python or C++.
- `tools/verify-vendor` reproduces the tree; a canary run with one patch removed fails.
- `nm`/`objdump` of the installed `.so` shows no `printf`, `stderr`, `abort` or `exit` reference; `tools/run-lint` asserts it (this is the canary for patch 0002).
- `R CMD check --as-cran` shows no compiled-code NOTE.
- Windows CI confirms `<strings.h>` resolves under Rtools.

**Trap:** if Windows fights `strings.h`, add a project-owned shim header via `-I` ahead of the vendor tree, never a vendor edit.

---

## Stage 2 — Ledger, abort and limits (the safety seam) · L

**Status:** not started.

The stage that makes "untrusted HTML" an honest claim. No tree conversion yet.

**Do**
- `src/zuh_memory.c`: the per-parse ledger behind `GumboOptions.allocator/deallocator`. Each block carries a header `{size, index}`; the ledger is a growable pointer array; deallocation is swap-remove in O(1). Track live bytes against `max_memory`, check size arithmetic, handle zero-size requests, and detect double frees in debug builds.
- **Abort.** On allocation failure, budget breach or ledger growth failure, the allocator `longjmp`s to a `setjmp` in `zuh_gumbo_parse()`. Gumbo is plain C with no destructors, so the only state to unwind is the ledger. The boundary then **frees every ledger block in bulk**.
- **Bulk free on success too.** Never call `gumbo_destroy_output()`. All Gumbo memory went through the ledger, so bulk free is complete, O(n), non-recursive, and the same code path as failure. This removes the recursive `destroy_node` from the picture and the "partial tree" special case of §12.
- `zuh_gumbo_parse()` is the abortable region: pure C, no R API, returns a status enum (`OK`, `LIMIT_MEMORY`, `LIMIT_DEPTH`, `LIMIT_NODES`, `LIMIT_INPUT`, ...). `r_api.c` maps status to classed conditions after cleanup.
- Limits from `html_limits()`: `max_input` 16 MiB, `max_memory` 512 MiB, `max_depth` 512 (passed to the patched Gumbo option), `max_nodes` 1M (checked during Stage 3 conversion), `max_errors` 100 (Gumbo's option), `max_table_cells` 1M, `max_selector_length` 16 KiB. Validation rejects negative, missing, non-finite, fractional and overflowing values with `zuhtml_input_error`. Defaults are confirmed against measurement at Stage 8, not frozen here.
- Input contract of §5 in R: exactly one string or one raw vector, `enc2utf8()`, bytes-marked strings rejected, `encoding=` only for raw (explicit, else BOM, else UTF-8) via `iconv()`, BOM stripped, embedded NUL rejected. `html_read()` reads one local path as raw.
- `html_problems()`: translate the 42 `GumboErrorType` values into package-owned `code` strings plus `stage` (`tokenizer`/`parser`), `line`, `column`, `byte_offset`; truncation flag when `max_errors` was hit.

**Exit**
- Allocation-failure injection at every allocation index over a small corpus (the ledger makes index-k failure trivial) leaks nothing under ASan/LSan and returns `LIMIT_MEMORY` every time.
- `deep 100000` from the probe returns `LIMIT_DEPTH` in milliseconds instead of 16 s; `aaa 20000` likewise.
- A 16 MiB sawtooth input parses under the caps in under 3 s on CI.
- Each limit trips its own classed error on a targeted fixture.
- `tools/run-sanitizers` drives the seam under ASan+UBSan with no R in the way; leak checks on Linux.

**Trap:** `R_CheckUserInterrupt()` inside the abortable region is forbidden — it long-jumps past the ledger. The parse path is bounded instead; interrupts belong to R-side loops only.

---

## Stage 3 — Frozen document and conversion · M

**Status:** not started.

- `src/zuh_document.[ch]`: one document owns contiguous arrays — nodes `{type, namespace, parent, first_child, last_child, next_sibling, prev_sibling, name_off, value_off, attr_start, attr_count, flags}`, attributes `{name_off, value_off, namespace}`, a UTF-8 string pool with interned element names, doctype metadata, quirks mode, base URL, encoding, and the translated diagnostics. Indices, not pointers; `uint32_t` IDs checked against the count before conversion to R integers.
- Iterative conversion with an explicit stack; `max_nodes` and a secondary depth check enforced here. Copy decoded text and attribute values; do not retain the input buffer or any Gumbo struct. Template children keep their parent but the template node carries a flag that traversal honours.
- Node types: document, doctype, element, text, comment, template, processing instruction, whitespace text folded into text.
- Ownership: the frozen document is `malloc`-owned by an external pointer with an idempotent finalizer; R allocations happen only after conversion (an R allocation failure at `R_MakeExternalPtr` leaks one document — accepted as in zuxml #43, documented).

**Exit:** the tree-construction fixtures parse and convert without loss (checked once the Stage 5 serializer exists; until then, node counts and a hand-written tree dump); ASan-clean; peak memory of parse+convert measured on the probe inputs and recorded for Stage 8.

---

## Stage 4 — R document and node API · M

**Status:** not started.

- `R/parse.R`, `R/conditions.R`, `R/info.R`, `R/node.R`, `R/nodeset.R`, `R/attributes.R`, `R/text.R` as in §13.
- `zuhtml_document` and `zuhtml_nodeset` per §4: integer IDs plus owner; `NA_integer_` is a missing node; `[`, `[[`, `length`, `rev`, `c` preserve class and refuse cross-document concatenation; bounded `print`. Every native entry validates the pointer tag, liveness and node bounds; a dead pointer raises `zuhtml_pointer_error`.
- Navigation (§6): children/parent/ancestors/siblings with `elements_only`, length-preserving where the design says so; `html_root()`, `html_document()`, `html_template_content()`.
- Values (§7): `html_name()`, `html_namespace()`, `html_type()`, `html_attr()`, `html_attrs()`, `html_classes()`, `html_text()`. Conditions: `zuhtml_error` and the subclasses of §12 that exist by now, with machine-readable fields.
- `html_fragment()` with contexts limited to tag names Gumbo's enum has; others raise `zuhtml_input_error`.

**Exit:** forced GC with reachable nodes, repeated finalization, dead pointers and cross-document `c()` are all tested; the §16 workflow runs except for the selector lines; `R CMD check --as-cran` clean on the three platforms.

---

## Stage 5 — Serializer and round trip · M

**Status:** not started.

- `src/zuh_write.c`: WHATWG fragment-serialization rules — void elements, raw-text elements (`script`, `style`, `xmp`, `iframe`, `noembed`, `noframes`, `plaintext`), attribute and text escaping, comments, doctype, template contents, foreign-content names and namespaced attributes. Iterative traversal with a bounded stack; `html_serialize(x, outer)`.
- **Conformance gate.** `tools/conformance/` holds the 61 `.dat` files from the pinned archive (608 KB, outside the CRAN tarball); `tools/run-conformance` parses each `#data` (fragments via the `#document-fragment` line) and renders zuhtml's tree in the html5lib `| ` format, comparing against `#document`. Adjudicated deviations live in one list with reasons. A hand-picked dozen cases move into `tests/testthat/fixtures/` for CRAN.
- Round trip: `parse(serialize(parse(x)))` equals `parse(x)` structurally over the fixtures. The HTML serialization is not guaranteed by the spec to round-trip, so this is an adjudicated oracle, not an axiom: known non-fixed-points are listed, and the fuzz target at Stage 8 reports new ones rather than asserting.

**Exit:** conformance gate green with every deviation explained; round trip holds on the fixture corpus; a canary of a deliberately wrong serialization fails the gate.

---

## Stage 6 — CSS selector engine · L

**Status:** not started.

- `src/zuh_selector.c`: tokenizer (CSS Syntax subset: identifiers, escapes, strings, hashes, delims, `an+b` microsyntax), parser to a compiled selector list, right-to-left matcher with a work counter bounded per call and `R_CheckUserInterrupt()` polled from the R-facing loop. The exact production list of §6, no more; anything else raises `zuhtml_selector_error` with the offending position. No `:has()`, pseudo-elements, namespaces or `::text`.
- Case rules: type selectors ASCII-case-insensitive against HTML-namespace elements; class/id case-sensitive; attribute `i`/`s` flags; structural pseudo-classes count element siblings; `:empty` per Selectors 3.
- Scoping and results per §6: document search includes the root; element search excludes the context unless `:scope`; multi-context union deduplicated in document order; `html_element()` first match per context with `NA` for none; `html_matches()`, `html_filter()`.
- Compile once per call; no per-document cache.

**Exit:** a fixture per supported production, plus escapes, case rules, scoping, deduplication, absent matches and explicit rejection of every unsupported form; `fuzz_selector` target added (parser plus matcher on a fixed document) and run under ASan; the §16 workflow runs end to end.

---

## Stage 7 — Extraction: clean text, lists, tables, links, URLs · L

**Status:** not started.

- `src/zuh_text.c` and `R/text.R`: `html_text_clean()` per §7 — skip `script`/`style` and template content, collapse ASCII whitespace outside `pre`/`textarea`, line breaks at `<br>` and a fixed block-tag list, `nbsp` folding. Documented as not `innerText`.
- `R/list.R`: `html_list()` text and tree modes per §8, minus ordinals and data-frame mode. Nested lists excluded from item text; wrapper elements honoured.
- `src/zuh_table.c` and `R/table.R`: the grid algorithm of §9 steps 1–6 with `span = "repeat"` only; HTML non-negative-integer span parsing with the clamps; `rowspan=0` to end of group; positive rowspans clipped silently; overlap is `zuhtml_table_structure_error`; checked arithmetic against `max_table_cells`. Header policy `"auto"`/`TRUE`/`FALSE`/integer rows; labels joined with `" / "`, blanks `V<n>`, `make.unique()`. All-character output; `na=` applied after trimming; empty table is 0×0; header-only is 0-row with names; footers are data rows. Nested tables excluded from cell text; `html_tables()` returns outermost matches only.
- `R/links.R`: `html_url()` implementing RFC 3986 §5.2 (parse per Appendix B regex, merge, remove dot segments, protocol-relative references); base precedence per §10; malformed reference gives `NA`. `html_links()` over `a[href]` and `area[href]` with `text`, `href`, `url`.

**Exit:** the §14 extraction fixture list for lists, tables, text and URLs, including the RFC 3986 §5.4 normal and abnormal examples verbatim; leading zeros survive; the §9 example gives `c("0012", "0034")`.

---

## Stage 8 — Hardening · L

**Status:** not started.

- Fuzz targets under `fuzz/`: `fuzz_parse` (ledger, limits, conversion, serialize), `fuzz_roundtrip` (report non-fixed-points), `fuzz_selector`. `tools/run-fuzz` propagates the fuzzer's exit status (zuxml #35) and a target that must crash is the canary. Nightly runs in a `hardening.yaml` workflow; the seed corpus includes the conformance `#data` blocks and the probe generators.
- Allocation-failure injection across the corpus (Stage 2) re-run against the full pipeline including conversion and serialization.
- `tools/run-lint`: `-Werror -Wall -Wextra -Wpedantic -Wconversion -Wcast-qual` on project-owned code only; the stdio-symbol assertion from Stage 1.
- Cross-platform CI: the r-actions matrix plus the R-hub containers zuxml uses (`clang23`, `ubuntu-clang`, `ubuntu-gcc16`) and Windows R-devel.
- Set the final `html_limits()` defaults from measured peak memory of parse + convert on the probe inputs; record the numbers in the design.
- Bounded printing and interrupt polling in every R-facing loop over the frozen document; `setTimeLimit()` test for the interrupt path (zuxml #37).

**Exit:** all gates have been seen to fail once and pass now; no memory-safety finding in project-owned code across the fuzz runs; limits table in the design matches the code.

---

## Stage 9 — Documentation, benchmarks, CRAN preparation · M

**Status:** not started.

- Roxygen for all 33 exports: `@return` on every one, runnable `@examples` (no `\dontrun{}`, no commented-out code, errors shown with `try()`), `@family` groups; `devtools::document()` leaves no diff.
- Vignettes: `zuhtml` (parse, select, extract — the §16 workflow), `selectors` (the supported subset and what is rejected), `tables-and-lists`, `limits-and-encoding` (what is and is not bounded, that parsing is not sanitization, no encoding sniffing). `vignettes/articles/` for pkgdown-only material.
- `README.md`: purpose, `install.packages("zuhtml")` alongside the pak line, no relative links, one worked example.
- `NEWS.md` for 0.1.0; `cran-comments.md` in zuxml's shape: test environments, the gates, an acceptance-criteria table mapping each §14 criterion to what verifies it, method references (WHATWG HTML parsing, Selectors, RFC 3986), and any NOTE explained.
- `tools/run-benchmarks`: parse, convert, select, table on tiny/ordinary/large/deep/malformed inputs; report time and peak native bytes separately; never a single headline number. Comparison against rvest/xml2 only if they are in `Suggests` and the script skips without them.
- Run the CRAN checklist: `urlchecker::url_check()`, title and description rules, `[cph]` roles for every holder, LICENSE year, bundled-licence review, `R CMD check --as-cran` on the matrix, win-builder R-devel once by hand.

**Exit:** 0 errors, 0 warnings, and only NOTEs that `cran-comments.md` explains (ideally just "New submission").

---

## Stage 10 — 0.1.0 release · S

**Status:** not started.

- Version to `0.1.0`; tag; submit via `devtools::submit_cran()` or the web form; respond to the CRAN incoming email within the same day; on acceptance, `usethis::use_github_release()`, pkgdown deploy, and open the 0.2.0 tracking issue with the "After 0.1.0" list.

**Exit:** on CRAN.

---

## Risk register

| Risk | Stage | Mitigation |
|---|---|---|
| Patch series drifts from upstream or is silently dropped | 1 | `tools/verify-vendor` re-derives the tree from archive plus patches; the stdio-symbol lint is the canary for 0002; both patches submitted upstream so the series can shrink |
| `longjmp` out of the allocator leaves Gumbo state behind | 2 | Gumbo holds only ledger memory; bulk free is the sole teardown path on success and failure; fault injection at every allocation index proves it |
| Memory cap trips before the input cap on formatting-heavy pages | 2, 8 | Classed `zuhtml_limit_error` with observed bytes; documented ratio; defaults set from measurement at Stage 8 |
| Conformance gate has no oracle until the serializer exists | 3, 5 | Stage 3 uses node counts and a tree dump; Stage 5 replaces them with the html5lib format |
| CSS engine grows toward a full implementation | 6 | §6's production list is closed; every unsupported form has a rejection test |
| Table grid diverges from browsers on hostile markup | 7 | Overlap is an error, never a silent overwrite; fixtures from §14 lock behaviour before release |
| CRAN objects to the `License:` field for bundled Apache-2.0 code | 1, 9 | Follow an existing CRAN precedent exactly; `LICENSE.note`, `inst/COPYRIGHTS`, `Copyright:` field, Apache text in the vendor tree |
| Scope creep back toward the design's full helper list | all | The 0.1.0 table above is the contract; helpers below the line are 0.1.1 material |

---

## Explicitly not in 0.1.0

Everything in the "Cut" column of the scope table · record extraction (`html_records()`, `html_field()`) · JSON-LD · forms · encoding sniffing from `<meta charset>` · incremental or `feed()` parsing · interrupts inside the parse (bounded instead) · a registered C interface · XPath · `:has()` and other Selectors 4 additions · typed table conversion · any `displayed_only` heuristic.

None is made harder by shipping first: the arena accommodates new accessors, the selector engine is a closed list that can open, and helpers are R over the kept API.

---

## After 0.1.0

1. **0.1.1 (R only):** `html_images()`, `html_headings()`, `html_meta()`, `html_title()`, `html_dl()`, `html_list(mode = "data.frame")` with `<ol start>`/`reversed`/`<li value>`, `html_table_cells()`, `html_lists()`.
2. **0.2.0:** `html_records()`/`html_field()` per §11; `col_types` on tables; `html_json_ld()`; fragment `namespace=`; upstream-merged patches replacing the local series.
3. **Later:** forms inspection; encoding sniffing by the standard algorithm; a registered C interface once ownership and error semantics have survived a release; `zuhttp::resp_html()` on buffered bodies.
