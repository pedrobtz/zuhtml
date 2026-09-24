# zuhtml: Parse 'HTML' with a Bundled 'Gumbo' Parser

Parses real-world 'HTML' with a bundled copy of the 'Gumbo' parser
(<https://codeberg.org/gumbo-parser/gumbo-parser>), which follows the
'WHATWG' parsing algorithm, so that no system library is required.
Documents become immutable trees navigated with a documented subset of
'CSS' selectors. Attributes, text, lists, tables and links are extracted
into ordinary character vectors, lists and data frames. Parsing is
bounded by limits on input size, native memory and nesting depth.

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
