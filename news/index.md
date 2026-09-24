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
