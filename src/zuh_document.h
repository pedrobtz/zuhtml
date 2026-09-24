/* The frozen document: everything a parse leaves behind once Gumbo's memory
 * is gone. malloc-owned; R holds it through an external pointer. Pure C: no
 * R headers.
 *
 * Stage 2 holds the translated diagnostics and parse metadata. Stage 3 adds
 * the node, attribute and string arrays. See .agents/roadmap.md. */
#ifndef ZUH_DOCUMENT_H
#define ZUH_DOCUMENT_H

#include <stddef.h>

/* One recoverable parse diagnostic. `code` indexes the package-owned code
 * table in zuh_gumbo.c (zuh_problem_code_name()); positions are Gumbo's:
 * line and column 1-based, offset a 0-based byte offset into the decoded
 * UTF-8 input. */
typedef struct {
  unsigned int code;
  unsigned int line;
  unsigned int column;
  unsigned int offset;
} zuh_problem;

typedef struct zuh_doc {
  zuh_problem *problems;
  size_t n_problems;
  int problems_truncated;   /* more problems occurred than max_errors */

  size_t input_bytes;       /* decoded UTF-8 input the parse consumed */
  size_t parse_peak_bytes;  /* peak live bytes in the parse ledger */
  int quirks_mode;          /* 0 no-quirks, 1 quirks, 2 limited-quirks */
} zuh_doc;

zuh_doc *zuh_doc_new(void);
void zuh_doc_free(zuh_doc *doc);

#endif
