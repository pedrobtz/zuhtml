# Changelog

## zuhtml 0.1.0.9000

- [`html_strings()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_strings.md)
  skips the text of SVG `<script>` and `<style>`, as
  [`html_text_clean()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_text_clean.md)
  does, instead of returning their code as text
  ([\#98](https://github.com/pedrobtz/zuhtml/issues/98)).

- [`html_markdown()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_markdown.md)
  no longer escapes a `:`, `.` or `)` after a code span, emphasis or a
  link at the start of a line (`` `x`: description ``, not
  `` `x`\: description ``), and escapes `:` and `|` at a line start only
  below another line of the paragraph, where a table delimiter row could
  form ([\#127](https://github.com/pedrobtz/zuhtml/issues/127)).

- [`html_markdown()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_markdown.md)
  output no longer loses content when rendered: an `<hr>` that opens a
  `-` list item is written `***` (`- ---` is a thematic break and
  dropped the list), link text with `]:` in a code span no longer makes
  a link reference definition, a leading `^` in link or image text is
  escaped (cmark-gfm read it as a footnote), and an `&` that ends a text
  node is escaped, so `&amp;` split across elements stays as written
  ([\#133](https://github.com/pedrobtz/zuhtml/issues/133)).

- The shared object is compiled with hidden symbol visibility and
  exports only `R_init_zuhtml`, so its internal and vendored ‘Gumbo’
  symbols cannot clash with another library loaded into the same
  session.

- [`html_read()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_parse.md)
  raises a path, URL or connection that cannot be opened through the new
  `fail` hook of the shared `zu_source.R` (copied again from zuxml). It
  was already a `zuhtml_input_error` naming the cause, without R’s
  warning; the change is mostly internal. The connection that failed to
  open is now destroyed at once rather than left to the garbage
  collector.

- The message of an invalid `path` (not a string, a directory, a
  text-mode connection) is no longer wrapped as “Cannot open …: …” with
  a doubled full stop.

- `html_json_ld(parse = TRUE)` parses each block with
  [`jsonlite::parse_json()`](https://rdrr.io/pkg/jsonlite/man/read_json.html)
  instead of
  [`jsonlite::fromJSON()`](https://rdrr.io/pkg/jsonlite/man/fromJSON.html),
  which read a block whose text was the name of an existing file as that
  file, and downloaded one that was an `http(s)://` URL. Such a block is
  now `NULL`, like any other invalid JSON
  ([\#88](https://github.com/pedrobtz/zuhtml/issues/88)).

- [`html_forms()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_forms.md)
  and
  [`html_microdata()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_microdata.md)
  find the element named by a `form` or `itemref` attribute by comparing
  IDs, not through a CSS selector. A value holding a newline gave a
  `zuhtml_selector_error` and one over 16 KiB a `zuhtml_limit_error`;
  any value now works
  ([\#96](https://github.com/pedrobtz/zuhtml/issues/96)).

- [`html_microdata()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_microdata.md)
  gives `""` for a URL property (`href`, `src` or `data`) whose
  attribute is absent, as the HTML standard does, instead of the base
  URL ([\#97](https://github.com/pedrobtz/zuhtml/issues/97)).

- An SVG or MathML `<base>` no longer sets the document’s base URL for
  [`html_url()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_url.md)
  and the other URL resolution;
  [`html_forms()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_forms.md)
  ignores SVG and MathML forms, controls and fieldsets; and
  [`html_json_ld()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_json_ld.md)
  ignores SVG and MathML `<script>` elements
  ([\#98](https://github.com/pedrobtz/zuhtml/issues/98)).

- [`html_forms()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_forms.md)
  selects the first enabled option of a single select with nothing
  marked selected only when its display size is 1 (no `size`, an invalid
  one, or `size=1`), as the DOM does; a list box such as
  `<select size=5>` now has no value
  ([\#111](https://github.com/pedrobtz/zuhtml/issues/111)).

- windows-1255 and windows-1258 input no longer loses its last character
  on macOS, whose iconv held it back for a combining mark
  ([\#89](https://github.com/pedrobtz/zuhtml/issues/89)). Both are now
  decoded from the Encoding Standard’s indexes, so a base letter and a
  combining mark stay two characters, as in a browser. Other
  [`iconv()`](https://rdrr.io/r/base/iconv.html) encodings with the same
  behaviour, such as TCVN, keep their last character too.

- In a C locale, a string with non-ASCII characters that was not marked
  UTF-8 (as [`readLines()`](https://rdrr.io/r/base/readLines.html)
  returns them there) is read as UTF-8 by
  [`html_parse()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_parse.md),
  [`html_fragment()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_fragment.md),
  the selection functions and
  [`html_attr()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_attr.md),
  instead of each byte becoming the text `<c3>`
  ([\#92](https://github.com/pedrobtz/zuhtml/issues/92)). Selector error
  positions count characters there too.

- The same holds for `base_url` (of
  [`html_parse()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_parse.md),
  [`html_fragment()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_fragment.md),
  [`html_read()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_parse.md)
  and
  [`html_url()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_url.md))
  and for
  [`html_table()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_table.md)’s
  `na`, `decimal` and `thousands` and
  [`html_tables()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_table.md)’s
  `match`. In a C locale a non-ASCII base URL had come out of
  [`html_url()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_url.md),
  [`html_links()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_links.md)
  and
  [`html_markdown()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_markdown.md)
  as the text `<c3><a9>`, `na` had matched nothing and `match` had
  failed with an unclassed error. Each of these arguments that is not
  valid UTF-8, or is marked as `"bytes"`, is now a `zuhtml_input_error`
  ([\#125](https://github.com/pedrobtz/zuhtml/issues/125)).

- A `<meta>` charset label with a non-ASCII byte is ignored as an
  unknown label, in every locale, instead of failing with an unclassed
  error, so a later valid declaration is used
  ([\#93](https://github.com/pedrobtz/zuhtml/issues/93)).

- `encoding` naming an encoding that is not ASCII-compatible, such as
  UCS-2LE or UTF-32LE, is an encoding error that names it rather than
  “The input contains a NUL byte”
  ([\#94](https://github.com/pedrobtz/zuhtml/issues/94)).
  `encoding = "UTF-8-MAC"` decodes valid input instead of refusing it.

- A second byte-order mark is kept as text in UTF-16 input, as it
  already was in UTF-8, rather than dropped
  ([\#95](https://github.com/pedrobtz/zuhtml/issues/95)).

- [`html_read()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_parse.md)
  now has the arguments of
  [`html_parse()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_parse.md)
  (`encoding`, `base_url`, `comments`, `limits`) instead of `...`, so
  positional and partial arguments work for a URL as they do for a path
  ([\#99](https://github.com/pedrobtz/zuhtml/issues/99)).

- The error for raw input longer than four times `max_input` says so; it
  is a bound on raw bytes of its own, which input in a stateful encoding
  such as ISO-2022-JP can reach while decoding within `max_input`
  ([\#85](https://github.com/pedrobtz/zuhtml/issues/85)).

- `html_limits(max_selector_length =)` now takes effect: a document
  keeps the limits it was parsed with, and selection on it uses their
  `max_selector_length`
  ([\#83](https://github.com/pedrobtz/zuhtml/issues/83)). It bounds only
  the selectors the caller passes, so extraction functions such as
  [`html_forms()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_forms.md),
  [`html_links()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_links.md)
  and
  [`html_title()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_title.md)
  work on a document parsed with a small `max_selector_length`; their
  own selectors had been refused with a `zuhtml_limit_error`
  ([\#124](https://github.com/pedrobtz/zuhtml/issues/124)).

- [`print()`](https://rdrr.io/r/base/print.html) of
  [`html_limits()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_limits.md)
  and
  [`html_info()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_info.md)
  works under `options(OutDec = ",")`
  ([\#110](https://github.com/pedrobtz/zuhtml/issues/110)).

- A `css`,
  [`html_attr()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_attr.md)
  `name` or `default`,
  [`html_fragment()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_fragment.md)
  `context` or `encoding` string marked as `"bytes"` is a
  `zuhtml_input_error` (part of
  [\#84](https://github.com/pedrobtz/zuhtml/issues/84)).

- `[<-` and `[[<-` on a nodeset accept only nodes of the same document,
  or `NA`, as [`c()`](https://rdrr.io/r/base/c.html) already did.
  Assigning a node of another document, or a bare number, used to keep
  its ID and silently address a different node of the target document;
  it is now a `zuhtml_input_error`
  ([\#82](https://github.com/pedrobtz/zuhtml/issues/82)). Arithmetic,
  ordering and math functions on a nodeset are refused the same way (use
  [`as.integer()`](https://rdrr.io/r/base/integer.html) for the IDs),
  and `length<-` keeps the nodeset class, padding with missing nodes.

- `==` and `!=` between two nodesets of the same document compare node
  identity, as `html_parent(a) == html_parent(b)` did in 0.1.0; across
  documents, or with a number, they are a `zuhtml_input_error`
  ([\#151](https://github.com/pedrobtz/zuhtml/issues/151)).
  [`sum()`](https://rdrr.io/r/base/sum.html),
  [`max()`](https://rdrr.io/r/base/Extremes.html),
  [`range()`](https://rdrr.io/r/base/range.html) and the rest of the
  Summary group, [`mean()`](https://rdrr.io/r/base/mean.html),
  [`median()`](https://rdrr.io/r/stats/median.html) and
  [`diff()`](https://rdrr.io/r/base/diff.html) are refused like
  arithmetic, instead of computing on the IDs;
  [`rank()`](https://rdrr.io/r/base/rank.html), which needs `>`, is
  refused too (use `rank(as.integer(x))`).
  [`sort()`](https://rdrr.io/r/base/sort.html) and
  [`order()`](https://rdrr.io/r/base/order.html) follow document order
  through a new [`xtfrm()`](https://rdrr.io/r/base/xtfrm.html) method.
  [`match()`](https://rdrr.io/r/base/match.html), `%in%` and
  [`setdiff()`](https://rdrr.io/r/base/sets.html) compare nodes, not
  their serialized markup, so two identical `<p>a</p>` elements no
  longer match each other, and a node never matches one of another
  document ([\#128](https://github.com/pedrobtz/zuhtml/issues/128)).

- Printing a nodeset shows a newline in text as `\n`, not `\\n`
  ([\#109](https://github.com/pedrobtz/zuhtml/issues/109)).
  `print(x, n =)` checks that `n` is a single non-negative whole number
  before printing anything, and `n = 0` prints only the header and
  count.

- `html_table(convert = TRUE)` no longer changes values silently
  ([\#100](https://github.com/pedrobtz/zuhtml/issues/100)). A column
  stays character when a value has a leading zero once grouping marks
  are removed (`"0,123"` with `thousands = ","` was 123), has more than
  15 significant digits (`"12345678901234567890"` was
  12345678901234567168), or overflows, underflows or is subnormal
  (`"1e999"` was `Inf`). `thousands = "\u00a0"` now matches, since cell
  text has its non-breaking spaces turned into spaces.

- `html_tables(match =)` with an invalid regular expression is a
  `zuhtml_input_error`, not a base error and a warning
  ([\#84](https://github.com/pedrobtz/zuhtml/issues/84)).

- Native failures outside parsing are classed conditions
  ([\#84](https://github.com/pedrobtz/zuhtml/issues/84)). A result
  string longer than R allows, from
  [`html_text()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_text.md),
  [`html_text_clean()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_text_clean.md),
  [`html_markdown()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_markdown.md)
  or
  [`html_serialize()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_serialize.md),
  is a `zuhtml_limit_error` with `limit = "string_length"`; it was a
  plain R error. Running out of memory while building a result or a
  table grid is still R’s own error (“cannot allocate vector of size
  …”), because R allocates those buffers; `?zuhtml-conditions` now says
  so instead of promising a `zuhtml_limit_error` with `limit = "memory"`
  ([\#126](https://github.com/pedrobtz/zuhtml/issues/126)). A document
  whose attributes or strings overflow the arena’s 32-bit offsets is a
  `zuhtml_limit_error` with `limit = "arena"` rather than a misleading
  `max_memory` error. A `max_memory` error now reports in `observed` the
  native memory in use where the parse ran past the limit.

- A `max_memory` error says where the parse ran past the limit (“ran
  past max_memory = M bytes at N bytes”), a lower bound on what it
  needs; it said the parse “needed” N bytes, which was well short of the
  need. `html_info()$parse_peak_bytes` now counts what `max_memory`
  counts, conversion’s frozen arrays included, so it is the smallest
  `max_memory` that parses that input; it was about a fifth lower. A
  request too large to count is reported as a breach rather than as
  memory the system refused
  ([\#130](https://github.com/pedrobtz/zuhtml/issues/130)).

- The internal tree dump used by the tests and the conformance gate no
  longer leaks its buffer if R fails to allocate the result string
  ([\#86](https://github.com/pedrobtz/zuhtml/issues/86)).

- `html_text_clean(trim = TRUE)` now trims whitespace at the ends that
  came from `<pre>` or `<textarea>`, as documented; whitespace inside
  them is still kept. This also applies to
  [`html_table()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_table.md)
  cells and
  [`html_list()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_list.md)
  items ([\#108](https://github.com/pedrobtz/zuhtml/issues/108)).

- [`html_text_clean()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_text_clean.md)
  skips the text of `<script>` and `<style>` inside SVG, as it does in
  HTML ([\#98](https://github.com/pedrobtz/zuhtml/issues/98)).

- [`html_markdown()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_markdown.md)
  fixes, each found by rendering its output with CommonMark and
  comparing the result with the page:

  - A `!` before a link is escaped, so the link no longer becomes an
    image; `:` and `|` at a line start are escaped, so a line such as
    `:-: | :-:` under a line with a pipe no longer makes a table
    ([\#101](https://github.com/pedrobtz/zuhtml/issues/101)).

  - Adjacent code spans join into one instead of reading as one span
    with backticks in it, and whitespace at a span’s ends is written as
    a space outside it instead of being dropped (“run `ls` now”, not
    “run`ls`now”)
    ([\#102](https://github.com/pedrobtz/zuhtml/issues/102)).

  - Nested and adjacent emphasis no longer leaves literal asterisks.
    Emphasis is now written only where no two delimiter runs touch, and
    emphasis inside emphasis of its kind is not written:
    `<b><i>x</i></b>` is `**x**`, no longer `***x***`
    ([\#103](https://github.com/pedrobtz/zuhtml/issues/103)).

  - Ordered lists are numbered as their items are written: a reversed
    list counts down from its number of items, not from 1, and an empty
    first item no longer makes a nested list start at 2, which
    CommonMark reads as text
    ([\#104](https://github.com/pedrobtz/zuhtml/issues/104)).

  - Text after a block inside `<pre>` keeps its line break
    ([\#105](https://github.com/pedrobtz/zuhtml/issues/105)).

  - Pipe-table rows are in
    [`html_table()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_table.md)’s
    order, head, bodies, foot, so a `<tfoot>` written first is no longer
    the header row
    ([\#106](https://github.com/pedrobtz/zuhtml/issues/106)).

  - A list right after another of its kind takes the other bullet or
    delimiter, so the two no longer merge into one list
    ([\#107](https://github.com/pedrobtz/zuhtml/issues/107)).

## zuhtml 0.1.0

CRAN release: 2026-10-06

First release.

- Bundles the ‘Gumbo’ HTML5 parser 0.14.0 from the maintained fork at
  <https://codeberg.org/gumbo-parser/gumbo-parser>, with local patches
  that add a parse-time nesting-depth limit, remove the library’s only
  `printf()`, and fix two memory-safety bugs in its `<selectedcontent>`
  support that fuzzing found (a use-after-free and a NULL dereference,
  both reachable from untrusted HTML) and an uninitialized read in
  fragment parsing. No system library is needed.

- New
  [`html_parse()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_parse.md)
  and
  [`html_read()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_parse.md)
  parse HTML from a string, raw vector or local file under explicit
  resource limits from the new
  [`html_limits()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_limits.md).
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
  [`html_fragment()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_fragment.md)
  parses markup in the context of a given element, as `innerHTML` does.

- Nodes are `zuhtml_nodeset`s: vectors of nodes tied to their document,
  with missing nodes where an aligned operation has no answer. Navigate
  with
  [`html_children()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_children.md),
  [`html_parent()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_children.md),
  [`html_ancestors()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_children.md),
  [`html_next_sibling()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_children.md),
  [`html_previous_sibling()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_children.md),
  [`html_root()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_children.md),
  [`html_document()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_children.md)
  and
  [`html_template_content()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_children.md);
  read values with
  [`html_name()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_name.md),
  [`html_namespace()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_name.md),
  [`html_type()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_name.md),
  [`html_attr()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_attr.md),
  [`html_attrs()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_attr.md),
  [`html_classes()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_attr.md)
  and
  [`html_text()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_text.md).
  [`html_info()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_info.md)
  describes a document. [`lapply()`](https://rdrr.io/r/base/lapply.html)
  and friends over a nodeset pass one node at a time;
  [`rep()`](https://rdrr.io/r/base/rep.html),
  [`rev()`](https://rdrr.io/r/base/rev.html),
  [`unique()`](https://rdrr.io/r/base/unique.html) and
  [`c()`](https://rdrr.io/r/base/c.html) keep nodesets nodesets.

- New extraction functions.
  [`html_text_clean()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_text_clean.md)
  gives text as a reader wants it: scripts and styles skipped,
  whitespace collapsed outside `<pre>`, line breaks at `<br>` and block
  elements.
  [`html_list()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_list.md)
  reads a `<ul>`/`<ol>` as text or a tree, without nested items leaking
  into their parents.
  [`html_table()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_table.md)
  and
  [`html_tables()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_table.md)
  read tables into data frames of character columns, with row and column
  spans, `rowspan="0"`, row groups, header detection and an error rather
  than a silent overwrite for overlapping cells.
  [`html_url()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_url.md)
  resolves URL attributes with RFC 3986 reference resolution, honouring
  `<base href>`, and
  [`html_links()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_links.md)
  lists a page’s links.

- New
  [`html_elements()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_elements.md),
  [`html_element()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_elements.md),
  [`html_matches()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_elements.md)
  and
  [`html_filter()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_elements.md)
  select elements with a documented subset of CSS selectors: type,
  universal, ID, class and attribute selectors (with the `i` and `s`
  flags), the four combinators, selector lists, `:scope`, `:root`,
  `:empty`, `:first-child`, `:last-child`, `:only-child`,
  `:nth-child()`, `:nth-of-type()` and `:not()`. Anything else is a
  `zuhtml_selector_error` pointing at the offending position.
  [`html_element()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_elements.md)
  keeps one result per input node, so extracted columns stay aligned.

- New
  [`html_closest()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_closest.md)
  finds each node’s nearest ancestor matching a selector, and
  [`html_strings()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_strings.md)
  returns the text pieces
  [`html_text()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_text.md)
  joins, keeping element boundaries. `html_serialize(pretty = TRUE)`
  lays block-level elements out on indented lines for reading.

- New
  [`html_title()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_title.md),
  [`html_meta()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_meta.md),
  [`html_json_ld()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_json_ld.md)
  and
  [`html_microdata()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_microdata.md)
  read page metadata: the document title, every `<meta>` tag (OpenGraph,
  Twitter cards and Dublin Core included), JSON-LD blocks (parsed with
  jsonlite if asked) and microdata items per the HTML standard,
  `itemref` included.

- New
  [`html_table_cells()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_table_cells.md)
  returns one row per table cell with its grid position, spans, section,
  whether it is a header, and its links.
  [`html_tables()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_table.md)
  gains `match =` to keep tables whose text matches a regular
  expression.
  [`html_table()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_table.md)
  gains `convert =`, `decimal =` and `thousands =` to convert columns
  that are entirely numbers or logicals, keeping identifiers with
  leading zeros as text.

- New
  [`html_markdown()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_markdown.md)
  converts nodes to CommonMark: headings, paragraphs, emphasis, code,
  fenced code blocks, block quotes, nested lists, links and images with
  resolved URLs, and GFM pipe tables for data tables.
  Markdown-significant characters in text are escaped, and only emphasis
  that CommonMark parses back is written.

- The `<meta>` declaration of raw input is found as browsers find it, by
  the HTML standard’s prescan of the first 1024 bytes, and read with the
  Encoding Standard’s labels (so `iso-8859-1` means windows-1252).
  [`html_info()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_info.md)
  reports where the encoding came from in `encoding_source`.

- New
  [`html_forms()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_forms.md)
  describes each form and the controls it owns, by the HTML standard’s
  form-owner rules (`form=` references included), with DOM values for
  every control type and the options of each select. It only inspects:
  nothing is submitted.

- [`html_read()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_parse.md)
  reads a URL (through base R’s
  [`url()`](https://rdrr.io/r/base/connections.html), which also sets
  the default `base_url`) or any connection, such as
  [`gzfile()`](https://rdrr.io/r/base/connections.html), as well as a
  file path. Reading stops once the input passes four times `max_input`.

- New
  [`html_serialize()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_serialize.md)
  (and [`as.character()`](https://rdrr.io/r/base/character.html) on
  nodesets) writes nodes as normalized HTML following the WHATWG
  serialization algorithm, outer or inner.

- New
  [`html_problems()`](https://pedrobtz.github.io/zuhtml/dev/reference/html_problems.md)
  lists the parse errors the parser repaired, with package-owned codes
  and positions.

- Errors are classed conditions under `zuhtml_error`; see
  `?zuhtml-conditions`.

- New
  [`zuhtml_info()`](https://pedrobtz.github.io/zuhtml/dev/reference/zuhtml_info.md)
  reports the bundled parser version and patches, and self-tests the
  compiled parser.
