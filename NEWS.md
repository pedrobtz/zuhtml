# zuhtml 0.0.0.9000

* Bundles the 'Gumbo' HTML5 parser 0.14.0 from the maintained fork at
  <https://codeberg.org/gumbo-parser/gumbo-parser>, with local patches that
  add a parse-time nesting-depth limit and remove the library's only
  `printf()`. No system library is needed.

* New `html_parse()` and `html_read()` parse HTML from a string, raw vector
  or local file under explicit resource limits from the new
  `html_limits()`. Nesting depth is bounded while parsing, and all parser
  memory goes through an allocation ledger with a budget, so a failed
  parse always releases everything. Raw input is decoded from an explicit
  encoding, a byte-order mark or UTF-8; invalid input is an error, never
  silently replaced.

* Parsed documents are converted into a compact immutable tree that holds
  no reference to the parser or the input. All 1,686 applicable html5lib
  tree-construction tests that the bundled parser ships produce the
  expected tree.

* New `html_fragment()` parses markup in the context of a given element,
  as `innerHTML` does.

* Nodes are `zuhtml_nodeset`s: vectors of nodes tied to their document,
  with missing nodes where an aligned operation has no answer. Navigate
  with `html_children()`, `html_parent()`, `html_ancestors()`,
  `html_next_sibling()`, `html_previous_sibling()`, `html_root()`,
  `html_document()` and `html_template_content()`; read values with
  `html_name()`, `html_namespace()`, `html_type()`, `html_attr()`,
  `html_attrs()`, `html_classes()` and `html_text()`. `html_info()`
  describes a document.

* New `html_problems()` lists the parse errors the parser repaired, with
  package-owned codes and positions.

* Errors are classed conditions under `zuhtml_error`; see
  `?zuhtml-conditions`.

* New `zuhtml_info()` reports the bundled parser version and patches, and
  self-tests the compiled parser.
