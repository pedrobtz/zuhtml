# zuhtml 0.1.1

* `html_strings()` skips the text of SVG `<script>` and `<style>`, as
  `html_text_clean()` does, instead of returning their code as text (#98).

* `html_markdown()` no longer escapes a `:`, `.` or `)` after a code span,
  emphasis or a link at the start of a line (`` `x`: description ``, not
  `` `x`\: description ``), and escapes `:` and `|` at a line start only
  below another line of the paragraph, where a table delimiter row could
  form (#127).

* `html_markdown()` output no longer loses content when rendered: an `<hr>`
  that opens a `-` list item is written `***` (`- ---` is a thematic break
  and dropped the list), link text with `]:` in a code span no longer
  makes a link reference definition, a leading `^` in link or image text
  is escaped (cmark-gfm read it as a footnote), and an `&` that ends a
  text node is escaped, so `&amp;` split across elements stays as written
  (#133).

* The shared object is compiled with hidden symbol visibility and exports
  only `R_init_zuhtml`, so its internal and vendored 'Gumbo' symbols cannot
  clash with another library loaded into the same session.

* `html_read()` raises a path, URL or connection that cannot be opened
  through the new `fail` hook of the shared `zu_source.R` (copied again from
  zuxml). It was already a `zuhtml_input_error` naming the cause, without
  R's warning; the change is mostly internal. The connection that failed to
  open is now destroyed at once rather than left to the garbage collector.

* The message of an invalid `path` (not a string, a directory, a text-mode
  connection) is no longer wrapped as "Cannot open ...: ..." with a
  doubled full stop.

* `html_json_ld(parse = TRUE)` parses each block with
  `jsonlite::parse_json()` instead of `jsonlite::fromJSON()`, which read a
  block whose text was the name of an existing file as that file, and
  downloaded one that was an `http(s)://` URL. Such a block is now `NULL`,
  like any other invalid JSON (#88).

* `html_forms()` and `html_microdata()` find the element named by a `form`
  or `itemref` attribute by comparing IDs, not through a CSS selector. A
  value holding a newline gave a `zuhtml_selector_error` and one over
  16 KiB a `zuhtml_limit_error`; any value now works (#96).

* `html_microdata()` gives `""` for a URL property (`href`, `src` or
  `data`) whose attribute is absent, as the HTML standard does, instead of
  the base URL (#97).

* An SVG or MathML `<base>` no longer sets the document's base URL for
  `html_url()` and the other URL resolution; `html_forms()` ignores SVG and
  MathML forms, controls and fieldsets; and `html_json_ld()` ignores SVG
  and MathML `<script>` elements (#98).

* `html_forms()` selects the first enabled option of a single select with
  nothing marked selected only when its display size is 1 (no `size`, an
  invalid one, or `size=1`), as the DOM does; a list box such as
  `<select size=5>` now has no value (#111).

* windows-1255 and windows-1258 input no longer loses its last character
  on macOS, whose iconv held it back for a combining mark (#89). Both are
  now decoded from the Encoding Standard's indexes, so a base letter and a
  combining mark stay two characters, as in a browser. Other `iconv()`
  encodings with the same behaviour, such as TCVN, keep their last
  character too.

* In a C locale, a string with non-ASCII characters that was not marked
  UTF-8 (as `readLines()` returns them there) is read as UTF-8 by
  `html_parse()`, `html_fragment()`, the selection functions and
  `html_attr()`, instead of each byte becoming the text `<c3>` (#92).
  Selector error positions count characters there too.

* The same holds for `base_url` (of `html_parse()`, `html_fragment()`,
  `html_read()` and `html_url()`) and for `html_table()`'s `na`, `decimal`
  and `thousands` and `html_tables()`'s `match`. In a C locale a non-ASCII
  base URL had come out of `html_url()`, `html_links()` and
  `html_markdown()` as the text `<c3><a9>`, `na` had matched nothing and
  `match` had failed with an unclassed error. Each of these arguments that
  is not valid UTF-8, or is marked as `"bytes"`, is now a
  `zuhtml_input_error` (#125).

* A `<meta>` charset label with a non-ASCII byte is ignored as an unknown
  label, in every locale, instead of failing with an unclassed error, so a
  later valid declaration is used (#93).

* `encoding` naming an encoding that is not ASCII-compatible, such as
  UCS-2LE or UTF-32LE, is an encoding error that names it rather than
  "The input contains a NUL byte" (#94). `encoding = "UTF-8-MAC"` decodes
  valid input instead of refusing it.

* A second byte-order mark is kept as text in UTF-16 input, as it already
  was in UTF-8, rather than dropped (#95).

* `html_read()` now has the arguments of `html_parse()` (`encoding`,
  `base_url`, `comments`, `limits`) instead of `...`, so positional and
  partial arguments work for a URL as they do for a path (#99).

* The error for raw input longer than four times `max_input` says so; it
  is a bound on raw bytes of its own, which input in a stateful encoding
  such as ISO-2022-JP can reach while decoding within `max_input` (#85).

* `html_limits(max_selector_length =)` now takes effect: a document keeps
  the limits it was parsed with, and selection on it uses their
  `max_selector_length` (#83). It bounds only the selectors the caller
  passes, so extraction functions such as `html_forms()`, `html_links()`
  and `html_title()` work on a document parsed with a small
  `max_selector_length`; their own selectors had been refused with a
  `zuhtml_limit_error` (#124).

* `print()` of `html_limits()` and `html_info()` works under
  `options(OutDec = ",")` (#110).

* A `css`, `html_attr()` `name` or `default`, `html_fragment()` `context`
  or `encoding` string marked as `"bytes"` is a `zuhtml_input_error` (part
  of #84).

* `[<-` and `[[<-` on a nodeset accept only nodes of the same document, or
  `NA`, as `c()` already did. Assigning a node of another document, or a
  bare number, used to keep its ID and silently address a different node
  of the target document; it is now a `zuhtml_input_error` (#82).
  Arithmetic, ordering and math functions on a nodeset are refused the
  same way (use `as.integer()` for the IDs), and `length<-` keeps the
  nodeset class, padding with missing nodes.

* `==` and `!=` between two nodesets of the same document compare node
  identity, as `html_parent(a) == html_parent(b)` did in 0.1.0; across
  documents, or with a number, they are a `zuhtml_input_error` (#151).
  `sum()`, `max()`, `range()` and the rest of the Summary group, `mean()`,
  `median()` and `diff()` are refused like arithmetic, instead of
  computing on the IDs; `rank()`, which needs `>`, is refused too (use
  `rank(as.integer(x))`). `sort()` and `order()` follow document order
  through a new `xtfrm()` method. `match()`, `%in%` and `setdiff()`
  compare nodes, not their serialized markup, so two identical `<p>a</p>`
  elements no longer match each other, and a node never matches one of
  another document (#128).

* Printing a nodeset shows a newline in text as `\n`, not `\\n` (#109).
  `print(x, n =)` checks that `n` is a single non-negative whole number
  before printing anything, and `n = 0` prints only the header and count.

* `html_table(convert = TRUE)` no longer changes values silently (#100). A
  column stays character when a value has a leading zero once grouping
  marks are removed (`"0,123"` with `thousands = ","` was 123), has more
  than 15 significant digits (`"12345678901234567890"` was
  12345678901234567168), or overflows, underflows or is subnormal
  (`"1e999"` was `Inf`). `thousands = "\u00a0"` now matches, since cell
  text has its non-breaking spaces turned into spaces.

* `html_tables(match =)` with an invalid regular expression is a
  `zuhtml_input_error`, not a base error and a warning (#84).

* Native failures outside parsing are classed conditions (#84). A result
  string longer than R allows, from `html_text()`, `html_text_clean()`,
  `html_markdown()` or `html_serialize()`, is a `zuhtml_limit_error` with
  `limit = "string_length"`; it was a plain R error. Running out of memory
  while building a result or a table grid is still R's own error ("cannot
  allocate vector of size ..."), because R allocates those buffers;
  `?zuhtml-conditions` now says so instead of promising a
  `zuhtml_limit_error` with `limit = "memory"` (#126). A document whose attributes or strings overflow the
  arena's 32-bit offsets is a `zuhtml_limit_error` with `limit = "arena"`
  rather than a misleading `max_memory` error. A `max_memory` error now
  reports in `observed` the native memory in use where the parse ran past
  the limit.

* A `max_memory` error says where the parse ran past the limit ("ran past
  max_memory = M bytes at N bytes"), a lower bound on what it needs; it
  said the parse "needed" N bytes, which was well short of the need.
  `html_info()$parse_peak_bytes` now counts what `max_memory` counts,
  conversion's frozen arrays included, so it is the smallest `max_memory`
  that parses that input; it was about a fifth lower. A request too
  large to count is reported as a breach rather than as memory the system
  refused (#130).

* The internal tree dump used by the tests and the conformance gate no
  longer leaks its buffer if R fails to allocate the result string (#86).

* `html_text_clean(trim = TRUE)` now trims whitespace at the ends that
  came from `<pre>` or `<textarea>`, as documented; whitespace inside them
  is still kept. This also applies to `html_table()` cells and
  `html_list()` items (#108).

* `html_text_clean()` skips the text of `<script>` and `<style>` inside
  SVG, as it does in HTML (#98).

* `html_markdown()` fixes, each found by rendering its output with
  CommonMark and comparing the result with the page:

  * A `!` before a link is escaped, so the link no longer becomes an
    image; `:` and `|` at a line start are escaped, so a line such as
    `:-: | :-:` under a line with a pipe no longer makes a table (#101).

  * Adjacent code spans join into one instead of reading as one span with
    backticks in it, and whitespace at a span's ends is written as a space
    outside it instead of being dropped ("run `ls` now", not "run`ls`now")
    (#102).

  * Nested and adjacent emphasis no longer leaves literal asterisks.
    Emphasis is now written only where no two delimiter runs touch, and
    emphasis inside emphasis of its kind is not written: `<b><i>x</i></b>`
    is `**x**`, no longer `***x***` (#103).

  * Ordered lists are numbered as their items are written: a reversed list
    counts down from its number of items, not from 1, and an empty first
    item no longer makes a nested list start at 2, which CommonMark reads
    as text (#104).

  * Text after a block inside `<pre>` keeps its line break (#105).

  * Pipe-table rows are in `html_table()`'s order, head, bodies, foot, so
    a `<tfoot>` written first is no longer the header row (#106).

  * A list right after another of its kind takes the other bullet or
    delimiter, so the two no longer merge into one list (#107).

# zuhtml 0.1.0

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
  parse always releases everything. Raw input is decoded from a byte-order
  mark, an explicit encoding, the page's `<meta>` declaration or UTF-8;
  invalid input is an error, never silently replaced.

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

* New `html_table_cells()` returns one row per table cell with its grid
  position, spans, section, whether it is a header, and its links.
  `html_tables()` gains `match =` to keep tables whose text matches a
  regular expression. `html_table()` gains `convert =`, `decimal =` and
  `thousands =` to convert columns that are entirely numbers or logicals,
  keeping identifiers with leading zeros as text.

* New `html_markdown()` converts nodes to CommonMark: headings,
  paragraphs, emphasis, code, fenced code blocks, block quotes, nested
  lists, links and images with resolved URLs, and GFM pipe tables for data
  tables. Markdown-significant characters in text are escaped, and only
  emphasis that CommonMark parses back is written.

* The `<meta>` declaration of raw input is found as browsers find it, by
  the HTML standard's prescan of the first 1024 bytes, and read with the
  Encoding Standard's labels (so `iso-8859-1` means windows-1252).
  `html_info()` reports where the encoding came from in
  `encoding_source`.

* New `html_forms()` describes each form and the controls it owns, by the
  HTML standard's form-owner rules (`form=` references included), with
  DOM values for every control type and the options of each select. It
  only inspects: nothing is submitted.

* `html_read()` reads a URL (through base R's `url()`, which also sets the
  default `base_url`) or any connection, such as `gzfile()`, as well as a
  file path. Reading stops once the input passes four times `max_input`.

* New `html_serialize()` (and `as.character()` on nodesets) writes nodes
  as normalized HTML following the WHATWG serialization algorithm, outer
  or inner.

* New `html_problems()` lists the parse errors the parser repaired, with
  package-owned codes and positions.

* Errors are classed conditions under `zuhtml_error`; see
  `?zuhtml-conditions`.

* New `zuhtml_info()` reports the bundled parser version and patches, and
  self-tests the compiled parser.
