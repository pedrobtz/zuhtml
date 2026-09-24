# Changelog

## zuhtml 0.0.0.9000

- Bundles the ‘Gumbo’ HTML5 parser 0.14.0 from the maintained fork at
  <https://codeberg.org/gumbo-parser/gumbo-parser>, with local patches
  that add a parse-time nesting-depth limit and remove the library’s
  only `printf()`. No system library is needed.

- New
  [`zuhtml_info()`](https://pedrobtz.github.io/zuhtml/reference/zuhtml_info.md)
  reports the bundled parser version and patches, and self-tests the
  compiled parser.
