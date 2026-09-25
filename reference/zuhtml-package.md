# zuhtml: parse HTML with a bundled Gumbo parser

zuhtml parses real-world HTML the way a browser does, with a bundled
copy of the 'Gumbo' parser, and extracts ordinary R objects from it:
nodes selected by a documented subset of CSS, attributes, text, lists,
tables and links. It needs no system library and has no hard
dependencies.

## Details

It reads files, URLs and connections, but has no HTTP client of its own,
and does not run JavaScript, sanitize, edit documents or support XPath.

## Getting started

- Parse with
  [`html_parse()`](https://pedrobtz.github.io/zuhtml/reference/html_parse.md),
  [`html_read()`](https://pedrobtz.github.io/zuhtml/reference/html_parse.md)
  or
  [`html_fragment()`](https://pedrobtz.github.io/zuhtml/reference/html_fragment.md).

- Select elements with
  [`html_elements()`](https://pedrobtz.github.io/zuhtml/reference/html_elements.md)
  and
  [`html_element()`](https://pedrobtz.github.io/zuhtml/reference/html_elements.md),
  or move around with
  [`html_children()`](https://pedrobtz.github.io/zuhtml/reference/html_children.md)
  and friends.

- Read values with
  [`html_text_clean()`](https://pedrobtz.github.io/zuhtml/reference/html_text_clean.md),
  [`html_attr()`](https://pedrobtz.github.io/zuhtml/reference/html_attr.md)
  and
  [`html_serialize()`](https://pedrobtz.github.io/zuhtml/reference/html_serialize.md);
  extract structures with
  [`html_table()`](https://pedrobtz.github.io/zuhtml/reference/html_table.md),
  [`html_list()`](https://pedrobtz.github.io/zuhtml/reference/html_list.md),
  [`html_links()`](https://pedrobtz.github.io/zuhtml/reference/html_links.md)
  and
  [`html_url()`](https://pedrobtz.github.io/zuhtml/reference/html_url.md).

- Every call runs under
  [`html_limits()`](https://pedrobtz.github.io/zuhtml/reference/html_limits.md),
  and every error is a classed condition: see
  [zuhtml-conditions](https://pedrobtz.github.io/zuhtml/reference/zuhtml-conditions.md).

[`vignette("zuhtml")`](https://pedrobtz.github.io/zuhtml/articles/zuhtml.md)
walks through a complete extraction.

## See also

Useful links:

- <https://github.com/pedrobtz/zuhtml>

- <https://pedrobtz.github.io/zuhtml/>

- Report bugs at <https://github.com/pedrobtz/zuhtml/issues>

## Author

**Maintainer**: Pedro Baltazar <pedrobtz@gmail.com> \[copyright holder\]

Authors:

- Pedro Baltazar <pedrobtz@gmail.com> \[copyright holder\]

Other contributors:

- Google Inc. (Gumbo, bundled in src/vendor/gumbo) \[copyright holder\]

- Bjoern Hoehrmann (UTF-8 decoder in src/vendor/gumbo/utf8.c)
  \[copyright holder\]
