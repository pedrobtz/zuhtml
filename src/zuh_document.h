/* The frozen document: everything a parse leaves behind once Gumbo's memory
 * is gone. One malloc-owned arena of contiguous arrays, addressed by index;
 * R holds it through an external pointer. Immutable once built. Pure C: no
 * R headers.
 *
 * Node IDs are assigned in document order (preorder), so ID order is tree
 * order and a node's descendants are exactly the IDs in
 * (id, subtree_end]. */
#ifndef ZUH_DOCUMENT_H
#define ZUH_DOCUMENT_H

#include <stddef.h>
#include <stdint.h>

#include "zuh_status.h"

typedef uint32_t zuh_id;
#define ZUH_NONE ((zuh_id) 0xFFFFFFFFu)

/* Node types. Gumbo's whitespace and CDATA nodes are folded into TEXT, and
 * a template element is an ELEMENT with ZUH_FLAG_TEMPLATE. */
enum {
  ZUH_NODE_DOCUMENT = 0,
  ZUH_NODE_DOCTYPE,
  ZUH_NODE_ELEMENT,
  ZUH_NODE_TEXT,
  ZUH_NODE_COMMENT,
  ZUH_NODE_PI
};

enum { ZUH_NS_HTML = 0, ZUH_NS_SVG, ZUH_NS_MATHML };
enum { ZUH_ATTR_NS_NONE = 0, ZUH_ATTR_NS_XLINK, ZUH_ATTR_NS_XML,
       ZUH_ATTR_NS_XMLNS };

/* An HTML <template>: its children are its template contents, which
 * descendant traversal skips unless asked. */
#define ZUH_FLAG_TEMPLATE 0x1u

typedef struct {
  uint8_t type;
  uint8_t ns;
  uint16_t flags;
  zuh_id parent;
  zuh_id first_child;
  zuh_id last_child;
  zuh_id next_sibling;
  zuh_id prev_sibling;
  zuh_id subtree_end;   /* last descendant, or the node itself */
  uint32_t name;        /* pool offset: element or doctype name */
  uint32_t value;       /* pool offset: text, comment or PI content */
  uint32_t attr_start;  /* index into attrs */
  uint32_t attr_count;
} zuh_node;

typedef struct {
  uint32_t name;        /* pool offset */
  uint32_t value;       /* pool offset */
  uint8_t ns;           /* ZUH_ATTR_NS_* */
} zuh_attr;

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
  zuh_node *nodes;          /* nodes[0] is the document node */
  uint32_t n_nodes;
  zuh_attr *attrs;
  uint32_t n_attrs;
  char *pool;               /* NUL-terminated UTF-8 strings; offset 0 is "" */
  size_t pool_len;

  int is_fragment;          /* node 0 is a fragment, not a document */
  zuh_id root;              /* the <html> element, or ZUH_NONE (always
                               for a fragment) */
  uint32_t doctype_public;  /* pool offsets; 0 when absent */
  uint32_t doctype_system;

  zuh_problem *problems;
  size_t n_problems;
  int problems_truncated;   /* more problems occurred than max_errors */

  size_t input_bytes;       /* decoded UTF-8 input the parse consumed */
  size_t parse_peak_bytes;  /* peak live bytes in the parse ledger */
  size_t frozen_bytes;      /* bytes owned by this document */
  int quirks_mode;          /* 0 no-quirks, 1 quirks, 2 limited-quirks */
} zuh_doc;

zuh_doc *zuh_doc_new(void);
void zuh_doc_free(zuh_doc *doc);

static inline const char *
zuh_str(const zuh_doc *doc, uint32_t off) {
  return doc->pool + off;
}

/* Render the tree in the html5lib tree-construction test format ("| "
 * lines), as upstream Gumbo's own test harness does: the doctype first,
 * attributes sorted, template contents under a "content" line. The
 * document node itself is not printed. On ZUH_OK, *out is a malloc'd,
 * NUL-terminated buffer of *len bytes that the caller frees. */
zuh_status zuh_doc_dump(const zuh_doc *doc, char **out, size_t *len);

#endif
