/* Extraction-oriented text: html_text_clean(). Pure C: no R headers. */
#ifndef ZUH_TEXT_H
#define ZUH_TEXT_H

#include "zuh_buf.h"
#include "zuh_document.h"
#include "zuh_status.h"

typedef struct {
  int trim;         /* drop leading and trailing whitespace */
  int nbsp;         /* treat U+00A0 as whitespace */
  int skip_lists;   /* skip <ul>/<ol> subtrees below the node (list items);
                       each still separates text as a block would */
  int skip_tables;  /* skip <table> subtrees below the node (table cells),
                       likewise */
} zuh_clean_opts;

/* Append the cleaned text of node `id` to `out`:
 * - text in <script>, <style> and template contents is skipped, and so
 *   are comments;
 * - runs of ASCII whitespace collapse to one space, except inside <pre>,
 *   <textarea>, <listing> and <plaintext>, whose text is kept as is;
 * - <br> is a line break; a block element (a fixed list of tag names) is a
 *   line break before and after, and adjacent ones merge into one; a <td>
 *   or <th> is a space before and after.
 * Only an element, document, fragment or text node has cleaned text; for
 * other nodes nothing is appended. */
zuh_status zuh_text_clean(const zuh_doc *doc, zuh_id id,
                          const zuh_clean_opts *opts, zuh_buf *out);

#endif
