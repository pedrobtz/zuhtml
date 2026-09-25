# Changelog

## zuhtml 0.1.0

First release.

- Bundles the ‘Gumbo’ HTML5 parser 0.14.0 from the maintained fork at
  <https://codeberg.org/gumbo-parser/gumbo-parser>, with local patches
  that add a parse-time nesting-depth limit, remove the library’s only
  `printf()`, and fix two memory-safety bugs in its `<selectedcontent>`
  support that fuzzing found (a use-after-free and a NULL dereference,
  both reachable from untrusted HTML) and an uninitialized read in
  fragment parsing. No system library is needed.

- New
  [`html_parse()`](https://pedrobtz.github.io/zuhtml/reference/html_parse.md)
  and
  [`html_read()`](https://pedrobtz.github.io/zuhtml/reference/html_parse.md)
  parse HTML from a string, raw vector or local file under explicit
  resource limits from the new
  [`html_limits()`](https://pedrobtz.github.io/zuhtml/reference/html_limits.md).
  Nesting depth is bounded while parsing, and all parser memory goes
  through an allocation ledger with a budget, so a failed parse always
  releases everything. Raw input is decoded from a byte-order mark, an
  explicit encoding, the page’s `<meta>` declaration or UTF-8; invalid
  input is an error, never silently replaced.

- Parsed documents are converted into a compact immutable tree that
  holds no reference to the parser or the input. All 1,686 applicable
  html5lib tree-construction tests that the bundled parser ships produce
  the expected tree.

- New
  [`html_fragment()`](https://pedrobtz.github.io/zuhtml/reference/html_fragment.md)
  parses markup in the context of a given element, as `innerHTML` does.

- Nodes are `zuhtml_nodeset`s: vectors of nodes tied to their document,
  with missing nodes where an aligned operation has no answer. Navigate
  with
  [`html_children()`](https://pedrobtz.github.io/zuhtml/reference/html_children.md),
  [`html_parent()`](https://pedrobtz.github.io/zuhtml/reference/html_children.md),
  [`html_ancestors()`](https://pedrobtz.github.io/zuhtml/reference/html_children.md),
  [`html_next_sibling()`](https://pedrobtz.github.io/zuhtml/reference/html_children.md),
  [`html_previous_sibling()`](https://pedrobtz.github.io/zuhtml/reference/html_children.md),
  [`html_root()`](https://pedrobtz.github.io/zuhtml/reference/html_children.md),
  [`html_document()`](https://pedrobtz.github.io/zuhtml/reference/html_children.md)
  and
  [`html_template_content()`](https://pedrobtz.github.io/zuhtml/reference/html_children.md);
  read values with
  [`html_name()`](https://pedrobtz.github.io/zuhtml/reference/html_name.md),
  [`html_namespace()`](https://pedrobtz.github.io/zuhtml/reference/html_name.md),
  [`html_type()`](https://pedrobtz.github.io/zuhtml/reference/html_name.md),
  [`html_attr()`](https://pedrobtz.github.io/zuhtml/reference/html_attr.md),
  [`html_attrs()`](https://pedrobtz.github.io/zuhtml/reference/html_attr.md),
  [`html_classes()`](https://pedrobtz.github.io/zuhtml/reference/html_attr.md)
  and
  [`html_text()`](https://pedrobtz.github.io/zuhtml/reference/html_text.md).
  [`html_info()`](https://pedrobtz.github.io/zuhtml/reference/html_info.md)
  describes a document. [`lapply()`](https://rdrr.io/r/base/lapply.html)
  and friends over a nodeset pass one node at a time;
  [`rep()`](https://rdrr.io/r/base/rep.html),
  [`rev()`](https://rdrr.io/r/base/rev.html),
  [`unique()`](https://rdrr.io/r/base/unique.html) and
  [`c()`](https://rdrr.io/r/base/c.html) keep nodesets nodesets.

- New extraction functions.
  [`html_text_clean()`](https://pedrobtz.github.io/zuhtml/reference/html_text_clean.md)
  gives text as a reader wants it: scripts and styles skipped,
  whitespace collapsed outside `<pre>`, line breaks at `<br>` and block
  elements.
  [`html_list()`](https://pedrobtz.github.io/zuhtml/reference/html_list.md)
  reads a `<ul>`/`<ol>` as text or a tree, without nested items leaking
  into their parents.
  [`html_table()`](https://pedrobtz.github.io/zuhtml/reference/html_table.md)
  and
  [`html_tables()`](https://pedrobtz.github.io/zuhtml/reference/html_table.md)
  read tables into data frames of character columns, with row and column
  spans, `rowspan="0"`, row groups, header detection and an error rather
  than a silent overwrite for overlapping cells.
  [`html_url()`](https://pedrobtz.github.io/zuhtml/reference/html_url.md)
  resolves URL attributes with RFC 3986 reference resolution, honouring
  `<base href>`, and
  [`html_links()`](https://pedrobtz.github.io/zuhtml/reference/html_links.md)
  lists a page’s links.

- New
  [`html_elements()`](https://pedrobtz.github.io/zuhtml/reference/html_elements.md),
  [`html_element()`](https://pedrobtz.github.io/zuhtml/reference/html_elements.md),
  [`html_matches()`](https://pedrobtz.github.io/zuhtml/reference/html_elements.md)
  and
  [`html_filter()`](https://pedrobtz.github.io/zuhtml/reference/html_elements.md)
  select elements with a documented subset of CSS selectors: type,
  universal, ID, class and attribute selectors (with the `i` and `s`
  flags), the four combinators, selector lists, `:scope`, `:root`,
  `:empty`, `:first-child`, `:last-child`, `:only-child`,
  `:nth-child()`, `:nth-of-type()` and `:not()`. Anything else is a
  `zuhtml_selector_error` pointing at the offending position.
  [`html_element()`](https://pedrobtz.github.io/zuhtml/reference/html_elements.md)
  keeps one result per input node, so extracted columns stay aligned.

- New
  [`html_closest()`](https://pedrobtz.github.io/zuhtml/reference/html_closest.md)
  finds each node’s nearest ancestor matching a selector, and
  [`html_strings()`](https://pedrobtz.github.io/zuhtml/reference/html_strings.md)
  returns the text pieces
  [`html_text()`](https://pedrobtz.github.io/zuhtml/reference/html_text.md)
  joins, keeping element boundaries. `html_serialize(pretty = TRUE)`
  lays block-level elements out on indented lines for reading.

- New
  [`html_title()`](https://pedrobtz.github.io/zuhtml/reference/html_title.md),
  [`html_meta()`](https://pedrobtz.github.io/zuhtml/reference/html_meta.md),
  [`html_json_ld()`](https://pedrobtz.github.io/zuhtml/reference/html_json_ld.md)
  and
  [`html_microdata()`](https://pedrobtz.github.io/zuhtml/reference/html_microdata.md)
  read page metadata: the document title, every `<meta>` tag (OpenGraph,
  Twitter cards and Dublin Core included), JSON-LD blocks (parsed with
  jsonlite if asked) and microdata items per the HTML standard,
  `itemref` included.

- New
  [`html_table_cells()`](https://pedrobtz.github.io/zuhtml/reference/html_table_cells.md)
  returns one row per table cell with its grid position, spans, section,
  whether it is a header, and its links.
  [`html_tables()`](https://pedrobtz.github.io/zuhtml/reference/html_table.md)
  gains `match =` to keep tables whose text matches a regular
  expression.
  [`html_table()`](https://pedrobtz.github.io/zuhtml/reference/html_table.md)
  gains `convert =`, `decimal =` and `thousands =` to convert columns
  that are entirely numbers or logicals, keeping identifiers with
  leading zeros as text.

- New
  [`html_markdown()`](https://pedrobtz.github.io/zuhtml/reference/html_markdown.md)
  converts nodes to CommonMark: headings, paragraphs, emphasis, code,
  fenced code blocks, block quotes, nested lists, links and images with
  resolved URLs, and GFM pipe tables for data tables.
  Markdown-significant characters in text are escaped, and only emphasis
  that CommonMark parses back is written.

- The `<meta>` declaration of raw input is found as browsers find it, by
  the HTML standard’s prescan of the first 1024 bytes, and read with the
  Encoding Standard’s labels (so `iso-8859-1` means windows-1252).
  [`html_info()`](https://pedrobtz.github.io/zuhtml/reference/html_info.md)
  reports where the encoding came from in `encoding_source`.

- New
  [`html_forms()`](https://pedrobtz.github.io/zuhtml/reference/html_forms.md)
  describes each form and the controls it owns, by the HTML standard’s
  form-owner rules (`form=` references included), with DOM values for
  every control type and the options of each select. It only inspects:
  nothing is submitted.

- [`html_read()`](https://pedrobtz.github.io/zuhtml/reference/html_parse.md)
  reads a URL (through base R’s
  [`url()`](https://rdrr.io/r/base/connections.html), which also sets
  the default `base_url`) or any connection, such as
  [`gzfile()`](https://rdrr.io/r/base/connections.html), as well as a
  file path. Reading stops once the input passes four times `max_input`.

- New
  [`html_serialize()`](https://pedrobtz.github.io/zuhtml/reference/html_serialize.md)
  (and [`as.character()`](https://rdrr.io/r/base/character.html) on
  nodesets) writes nodes as normalized HTML following the WHATWG
  serialization algorithm, outer or inner.

- New
  [`html_problems()`](https://pedrobtz.github.io/zuhtml/reference/html_problems.md)
  lists the parse errors the parser repaired, with package-owned codes
  and positions.

- Errors are classed conditions under `zuhtml_error`; see
  `?zuhtml-conditions`.

- New
  [`zuhtml_info()`](https://pedrobtz.github.io/zuhtml/reference/zuhtml_info.md)
  reports the bundled parser version and patches, and self-tests the
  compiled parser.
