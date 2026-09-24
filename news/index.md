# Changelog

## zuhtml 0.0.0.9000

- Bundles the ‘Gumbo’ HTML5 parser 0.14.0 from the maintained fork at
  <https://codeberg.org/gumbo-parser/gumbo-parser>, with local patches
  that add a parse-time nesting-depth limit and remove the library’s
  only `printf()`. No system library is needed.

- New
  [`html_parse()`](https://pedrobtz.github.io/zuhtml/reference/html_parse.md)
  and
  [`html_read()`](https://pedrobtz.github.io/zuhtml/reference/html_parse.md)
  parse HTML from a string, raw vector or local file under explicit
  resource limits from the new
  [`html_limits()`](https://pedrobtz.github.io/zuhtml/reference/html_limits.md).
  Nesting depth is bounded while parsing, and all parser memory goes
  through an allocation ledger with a budget, so a failed parse always
  releases everything. Raw input is decoded from an explicit encoding, a
  byte-order mark or UTF-8; invalid input is an error, never silently
  replaced.

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
  describes a document.

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
