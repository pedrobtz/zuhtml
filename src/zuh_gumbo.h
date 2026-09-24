/* The version-specific Gumbo adapter. The only project-owned code that
 * includes a Gumbo header is zuh_gumbo.c; everything else talks to Gumbo
 * through this interface. Pure C: no R headers. */
#ifndef ZUH_GUMBO_H
#define ZUH_GUMBO_H

#include <stddef.h>

#include "zuh_document.h"
#include "zuh_status.h"

/* The pinned Gumbo release, as recorded in src/vendor/PROVENANCE. */
const char *zuh_gumbo_version(void);

/* The local patch series applied to the vendored tree, in order. Returns
 * the number of patches and points *ids at a static array of identifiers. */
int zuh_gumbo_patches(const char *const **ids);

typedef struct {
  size_t max_input;       /* bytes of decoded input */
  size_t max_memory;      /* bytes live in the parse ledger */
  unsigned int max_depth; /* open-element stack depth; must be >= 1 */
  int max_errors;         /* diagnostics kept; >= 0 */
  size_t max_nodes;       /* nodes in the frozen document */
  int keep_comments;      /* 0 drops comment nodes */
  int fragment_tag;       /* context element for a fragment parse, from
                             zuh_gumbo_tag_lookup(); -1 for a document */
  int fragment_ns;        /* its namespace: ZUH_NS_* */
  size_t fail_at;         /* fault injection: fail this allocation
                             (1-based), counting Gumbo's and conversion's
                             allocations together; 0 never */
} zuh_parse_opts;

typedef struct {
  size_t observed;        /* for a limit status: the value that tripped it */
  size_t n_allocs;        /* allocations Gumbo requested */
  size_t peak_bytes;      /* peak live bytes in the ledger */
} zuh_parse_stats;

/* Parse `len` bytes of UTF-8 at `buf` and convert the tree into `doc`,
 * which must be fresh from zuh_doc_new(). Pure C, no R API. Every Gumbo
 * allocation is freed before it returns, whatever the status; on a status
 * other than ZUH_OK, `doc` is left empty. `buf` need not be
 * NUL-terminated. */
zuh_status zuh_gumbo_parse(const char *buf, size_t len,
                           const zuh_parse_opts *opts, zuh_doc *doc,
                           zuh_parse_stats *stats);

/* The Gumbo tag for an element name, for use as a fragment context, or -1
 * if the pinned Gumbo has no tag of that name. ASCII case-insensitive.
 * With allow_unknown, an unknown name gives Gumbo's "unknown element" tag
 * instead, as upstream's own test harness passes it; the public API does
 * not allow it. */
int zuh_gumbo_tag_lookup(const char *name, int allow_unknown);

/* The package-owned name of a problem code, and its stage: 0 tokenizer,
 * 1 parser. NULL / -1 for an unknown code. */
const char *zuh_problem_code_name(unsigned int code);
int zuh_problem_code_stage(unsigned int code);

/* Parse a fixed document and check the tree Gumbo builds. Returns 1 when
 * the vendored library is linked and working. */
int zuh_gumbo_selftest(void);

/* Parse a fixed deeply nested document with and without max_tree_depth.
 * Returns 1 when patch 0001 is in effect. */
int zuh_gumbo_depth_selftest(void);

#endif
