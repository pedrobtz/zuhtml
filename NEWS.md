# zuhtml 0.0.0.9000

First release.

* Bundles the 'Gumbo' HTML5 parser 0.14.0 from the maintained fork at
  <https://codeberg.org/gumbo-parser/gumbo-parser>, with local patches that
  add a parse-time nesting-depth limit, remove the library's only
  `printf()`, and fix two memory-safety bugs in its `<selectedcontent>`
  support that fuzzing found (a use-after-free and a NULL dereference, both
  reachable from untrusted HTML) and an uninitialized read in fragment
  parsing. No system library is needed.

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
  describes a document. `lapply()` and friends over a nodeset pass one
  node at a time; `rep()`, `rev()`, `unique()` and `c()` keep nodesets
  nodesets.

* New extraction functions. `html_text_clean()` gives text as a reader
  wants it: scripts and styles skipped, whitespace collapsed outside
  `<pre>`, line breaks at `<br>` and block elements. `html_list()` reads a
  `<ul>`/`<ol>` as text or a tree, without nested items leaking into their
  parents. `html_table()` and `html_tables()` read tables into data frames
  of character columns, with row and column spans, `rowspan="0"`, row
  groups, header detection and an error rather than a silent overwrite
  for overlapping cells. `html_url()` resolves URL attributes with RFC
  3986 reference resolution, honouring `<base href>`, and `html_links()`
  lists a page's links.

* New `html_elements()`, `html_element()`, `html_matches()` and
  `html_filter()` select elements with a documented subset of CSS
  selectors: type, universal, ID, class and attribute selectors (with the
  `i` and `s` flags), the four combinators, selector lists, `:scope`,
  `:root`, `:empty`, `:first-child`, `:last-child`, `:only-child`,
  `:nth-child()`, `:nth-of-type()` and `:not()`. Anything else is a
  `zuhtml_selector_error` pointing at the offending position.
  `html_element()` keeps one result per input node, so extracted columns
  stay aligned.

* New `html_closest()` finds each node's nearest ancestor matching a
  selector, and `html_strings()` returns the text pieces `html_text()`
  joins, keeping element boundaries. `html_serialize(pretty = TRUE)` lays
  block-level elements out on indented lines for reading.

* New `html_title()`, `html_meta()`, `html_json_ld()` and `html_microdata()`
  read page metadata: the document title, every `<meta>` tag (OpenGraph,
  Twitter cards and Dublin Core included), JSON-LD blocks (parsed with
  jsonlite if asked) and microdata items per the HTML standard, `itemref`
  included.

* New `html_serialize()` (and `as.character()` on nodesets) writes nodes
  as normalized HTML following the WHATWG serialization algorithm, outer
  or inner.

* New `html_problems()` lists the parse errors the parser repaired, with
  package-owned codes and positions.

* Errors are classed conditions under `zuhtml_error`; see
  `?zuhtml-conditions`.

* New `zuhtml_info()` reports the bundled parser version and patches, and
  self-tests the compiled parser.
