# Tree-construction conformance fixtures

`tree-construction/*.dat` are the 61 html5lib-format tree-construction
tests that Gumbo 0.14.0 ships under `tests/tree_construction/`, copied
unchanged from the pinned archive (see `src/vendor/PROVENANCE`). Upstream
takes them from web-platform-tests, `html/syntax/parsing/resources/`
(<https://github.com/web-platform-tests/wpt>), distributed under the
3-Clause BSD License.

They are maintainer tooling, outside the CRAN tarball (`tools/` is
`.Rbuildignore`d). `tools/run-conformance` runs them; `deviations.txt` lists
every case zuhtml is expected to render differently, with the reason.
