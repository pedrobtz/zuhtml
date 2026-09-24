/* Version-specific adapter over the vendored Gumbo. See zuh_gumbo.h.
 *
 * Every Gumbo allocation goes through the ledger in zuh_memory.c. On any
 * allocation failure the ledger long-jumps back to parse_core(), which then
 * frees every block. gumbo_destroy_output() is never called: it recurses
 * once per nesting level, and bulk free through the ledger is complete, so
 * success and failure share one teardown path. */
#include <limits.h>
#include <setjmp.h>
#include <stdlib.h>
#include <string.h>

#include "gumbo.h"
#include "error.h"

#include "zuh_gumbo.h"
#include "zuh_memory.h"

/* tools/verify-vendor checks this against src/vendor/PROVENANCE. */
#define ZUH_GUMBO_VERSION "0.14.0"

static const char *const zuh_patch_ids[] = {
  "0001-max-tree-depth",
  "0002-no-stdio",
  "0003-modification-notices",
  "0004-selectedcontent-descendant",
  "0005-selectedcontent-end-tag",
  "0006-document-quirks-init"
};

const char *
zuh_gumbo_version(void) {
  return ZUH_GUMBO_VERSION;
}

int
zuh_gumbo_patches(const char *const **ids) {
  *ids = zuh_patch_ids;
  return (int) (sizeof(zuh_patch_ids) / sizeof(zuh_patch_ids[0]));
}

/* ---- problem codes ------------------------------------------------------
 *
 * Package-owned names. Tokenizer errors are named after Gumbo's
 * GumboErrorType, in kebab case without the GUMBO_ERR_ prefix; tree
 * construction errors (GUMBO_ERR_PARSER) are named after the token the
 * parser did not expect. Gumbo's numeric enums never reach R. */

static const char *const tokenizer_codes[] = {
  "utf8-invalid",                       /* GUMBO_ERR_UTF8_INVALID */
  "utf8-truncated",
  "utf8-null",
  "numeric-char-ref-no-digits",
  "numeric-char-ref-without-semicolon",
  "numeric-char-ref-invalid",
  "named-char-ref-without-semicolon",
  "named-char-ref-invalid",
  "tag-starts-with-question",
  "tag-eof",
  "tag-invalid",
  "close-tag-empty",
  "close-tag-eof",
  "close-tag-invalid",
  "script-eof",
  "attr-name-eof",
  "attr-name-invalid",
  "attr-double-quote-eof",
  "attr-single-quote-eof",
  "attr-unquoted-eof",
  "attr-unquoted-right-bracket",
  "attr-unquoted-equals",
  "attr-after-eof",
  "attr-after-invalid",
  "duplicate-attr",
  "solidus-eof",
  "solidus-invalid",
  "dashes-or-doctype",
  "comment-eof",
  "comment-invalid",
  "comment-bang-after-double-dash",
  "comment-dash-after-double-dash",
  "comment-space-after-double-dash",
  "comment-end-bang-eof",
  "doctype-eof",
  "doctype-invalid",
  "doctype-space",
  "doctype-right-bracket",
  "doctype-space-or-right-bracket",
  "doctype-end"                         /* GUMBO_ERR_DOCTYPE_END */
};
#define N_TOKENIZER_CODES \
  (sizeof(tokenizer_codes) / sizeof(tokenizer_codes[0]))

/* Indexed by GumboTokenType. */
static const char *const parser_codes[] = {
  "unexpected-doctype",
  "unexpected-start-tag",
  "unexpected-end-tag",
  "unexpected-comment",
  "unexpected-whitespace",
  "unexpected-character",
  "unexpected-cdata",
  "unexpected-null",
  "unexpected-eof",
  "unexpected-processing-instruction"
};
#define N_PARSER_CODES (sizeof(parser_codes) / sizeof(parser_codes[0]))

/* Compile-time checks that the tables still line up with the pinned
 * Gumbo's enums: a negative array size is a compile error. Re-check both
 * tables whenever Gumbo is updated. */
typedef char zuh_check_tokenizer_codes
    [(N_TOKENIZER_CODES == (size_t) GUMBO_ERR_PARSER) ? 1 : -1];
typedef char zuh_check_parser_codes
    [(N_PARSER_CODES == (size_t) GUMBO_TOKEN_PROCESSING_INSTRUCTION + 1) ? 1
                                                                        : -1];

#define CODE_PARSER_BASE ((unsigned int) N_TOKENIZER_CODES)
#define CODE_SELF_CLOSING \
  ((unsigned int) (N_TOKENIZER_CODES + N_PARSER_CODES))
#define N_CODES (CODE_SELF_CLOSING + 1u)

const char *
zuh_problem_code_name(unsigned int code) {
  if (code < CODE_PARSER_BASE)
    return tokenizer_codes[code];
  if (code < CODE_SELF_CLOSING)
    return parser_codes[code - CODE_PARSER_BASE];
  if (code == CODE_SELF_CLOSING)
    return "non-void-self-closing-tag";
  return NULL;
}

int
zuh_problem_code_stage(unsigned int code) {
  if (code < CODE_PARSER_BASE)
    return 0;
  if (code < N_CODES)
    return 1;
  return -1;
}

static unsigned int
translate_code(const GumboError *e) {
  if (e->type == GUMBO_ERR_PARSER) {
    unsigned int t = (unsigned int) e->v.parser.input_type;
    if (t >= N_PARSER_CODES)
      t = (unsigned int) GUMBO_TOKEN_EOF;
    return CODE_PARSER_BASE + t;
  }
  if (e->type == GUMBO_ERR_UNACKNOWLEDGED_SELF_CLOSING_TAG)
    return CODE_SELF_CLOSING;
  return (unsigned int) e->type;
}

int
zuh_gumbo_tag_lookup(const char *name, int allow_unknown) {
  GumboTag t = gumbo_tag_enum(name);
  if (t == GUMBO_TAG_LAST || (t == GUMBO_TAG_UNKNOWN && !allow_unknown))
    return -1;
  return (int) t;
}

/* ---- the abortable region ------------------------------------------- */

/* Runs on a complete Gumbo tree, before bulk free, with the abort
 * disarmed: it must not allocate through the ledger. `lg` is there for its
 * counters. Returns ZUH_OK or a status to fail the parse with. */
typedef zuh_status (*zuh_visit_fn)(const GumboOutput *out, void *ctx,
                                   zuh_ledger *lg, zuh_parse_stats *stats);

static zuh_status
parse_core(const char *buf, size_t len, const zuh_parse_opts *opts,
           zuh_visit_fn visit, void *ctx, zuh_parse_stats *stats) {
  GumboOptions go = kGumboDefaultOptions;
  jmp_buf env;
  zuh_ledger *lg;
  GumboOutput *out;
  zuh_status st;

  memset(stats, 0, sizeof(*stats));
  if (len > opts->max_input) {
    stats->observed = len;
    return ZUH_LIMIT_INPUT;
  }
  lg = zuh_ledger_new(opts->max_memory, opts->fail_at);
  if (lg == NULL)
    return ZUH_LIMIT_MEMORY;

  go.allocator = zuh_ledger_alloc;
  go.deallocator = zuh_ledger_free;
  go.userdata = lg;
  go.max_tree_depth = opts->max_depth;
  if (opts->fragment_tag >= 0 && opts->fragment_tag <= (int) GUMBO_TAG_UNKNOWN) {
    go.fragment_context = (GumboTag) opts->fragment_tag;
    go.fragment_namespace = opts->fragment_ns == ZUH_NS_SVG
                                ? GUMBO_NAMESPACE_SVG
                                : opts->fragment_ns == ZUH_NS_MATHML
                                      ? GUMBO_NAMESPACE_MATHML
                                      : GUMBO_NAMESPACE_HTML;
  }
  /* One more than kept, so that truncation is detectable. */
  go.max_errors = opts->max_errors < INT_MAX ? opts->max_errors + 1 : -1;

  /* Nothing here is modified between setjmp() and longjmp() except through
   * lg, which points at heap memory. */
  lg->abort_to = &env;
  if (setjmp(env) != 0) {
    st = lg->status;
    stats->n_allocs = lg->n_allocs;
    stats->peak_bytes = lg->peak_bytes;
    stats->observed = lg->live_bytes;
    zuh_ledger_free_all(lg);
    return st;
  }
  out = gumbo_parse_with_options(&go, buf, len);
  lg->abort_to = NULL;

  stats->peak_bytes = lg->peak_bytes;
  if (lg->corrupt) {
    st = ZUH_ERR_INTERNAL;
  } else if (out->status == GUMBO_STATUS_TREE_TOO_DEEP) {
    stats->observed = (size_t) opts->max_depth + 1;
    st = ZUH_LIMIT_DEPTH;
  } else {
    st = visit(out, ctx, lg, stats);
  }
  /* After the visit: conversion's allocations count too. */
  stats->n_allocs = lg->n_allocs;
  zuh_ledger_free_all(lg);
  return st;
}

/* ---- conversion into the frozen document ----------------------------
 *
 * Two iterative passes over the Gumbo tree. The first counts nodes,
 * attributes and string bytes, enforcing max_nodes, a second-line depth
 * check and the memory budget before anything is allocated. The second
 * fills contiguous arrays in preorder, so node IDs are document order.
 * Every string is copied: nothing points into Gumbo or the input. */

/* Conversion allocations share the ledger's fault-injection counter, so
 * that failing "every allocation index" also covers them. */
static void *
conv_malloc(zuh_ledger *lg, size_t n) {
  lg->n_allocs++;
  if (lg->fail_at != 0 && lg->n_allocs == lg->fail_at)
    return NULL;
  return malloc(n != 0 ? n : 1);
}

static const GumboVector *
children_of(const GumboNode *n) {
  switch (n->type) {
  case GUMBO_NODE_DOCUMENT:
    return &n->v.document.children;
  case GUMBO_NODE_ELEMENT:
  case GUMBO_NODE_TEMPLATE:
    return &n->v.element.children;
  default:
    return NULL;
  }
}

static int
is_element(const GumboNode *n) {
  return n->type == GUMBO_NODE_ELEMENT || n->type == GUMBO_NODE_TEMPLATE;
}

/* The source text of an unknown element's name: the start tag's name,
 * which the tokenizer ends at whitespace or '/' (and '\r', which input
 * preprocessing turns into a newline but original_tag still holds). */
static GumboStringPiece
unknown_tag_text(const GumboElement *e) {
  GumboStringPiece t = e->original_tag;
  size_t i;
  if (t.data == NULL || t.length < 2) {
    t.data = "";
    t.length = 0;
    return t;
  }
  gumbo_tag_from_original_text(&t);
  for (i = 0; i < t.length; i++) {
    if (t.data[i] == '\r') {
      t.length = i;
      break;
    }
  }
  return t;
}

#define N_INTERN ((size_t) GUMBO_TAG_LAST * 3u)

typedef struct {
  const zuh_parse_opts *opts;
  int keep_comments;
  zuh_doc *doc;
  size_t len;
  /* pass 1 */
  size_t n_nodes;
  size_t n_attrs;
  size_t pool_len;
  /* pass 2 */
  uint32_t *intern;   /* pool offset per (tag, namespace), or UINT32_MAX */
  size_t pool_used;
} conv_ctx;

static int
keep_node(const conv_ctx *c, const GumboNode *n) {
  return n->type != GUMBO_NODE_COMMENT || c->keep_comments;
}

/* Pool bytes a string of `n` bytes needs, with checked arithmetic. */
static int
add_bytes(size_t *acc, size_t n) {
  if (n > (size_t) -1 - 1 || *acc > (size_t) -1 - (n + 1))
    return 0;
  *acc += n + 1;
  return 1;
}

typedef struct {
  const GumboNode *node;
  unsigned int next;   /* index of the next child to visit */
  zuh_id id;           /* pass 2: the node's ID */
} conv_frame;

/* Grow the explicit stack. The depth it can reach is bounded by max_depth
 * (checked by the callers), so this never grows without limit. */
static int
stack_push(zuh_ledger *lg, conv_frame **st, size_t *cap, size_t *sp,
           const GumboNode *node, zuh_id id) {
  if (*sp == *cap) {
    size_t nc = *cap ? *cap * 2 : 64;
    conv_frame *grown;
    if (nc > (size_t) -1 / sizeof(conv_frame))
      return 0;
    grown = (conv_frame *) conv_malloc(lg, nc * sizeof(conv_frame));
    if (grown == NULL)
      return 0;
    if (*sp > 0)
      memcpy(grown, *st, *sp * sizeof(conv_frame));
    free(*st);
    *st = grown;
    *cap = nc;
  }
  (*st)[*sp].node = node;
  (*st)[*sp].next = 0;
  (*st)[*sp].id = id;
  (*sp)++;
  return 1;
}

/* The node whose children become node 0's children: the document, or for
 * a fragment the <html> element Gumbo wraps the fragment's nodes in. */
static const GumboNode *
top_of(const conv_ctx *c, const GumboOutput *out) {
  return c->opts->fragment_tag >= 0 ? out->root : out->document;
}

static zuh_status
count_tree(conv_ctx *c, const GumboOutput *out, zuh_ledger *lg,
           zuh_parse_stats *stats) {
  const GumboDocument *d = &out->document->v.document;
  int is_fragment = c->opts->fragment_tag >= 0;
  unsigned char *seen;
  conv_frame *st = NULL;
  size_t cap = 0, sp = 0;
  zuh_status status = ZUH_OK;

  seen = (unsigned char *) conv_malloc(lg, N_INTERN);
  if (seen == NULL)
    return ZUH_LIMIT_MEMORY;
  memset(seen, 0, N_INTERN);

  c->n_nodes = 1; /* the document */
  c->n_attrs = 0;
  c->pool_len = 1; /* offset 0 is "" */
  if (d->has_doctype && !is_fragment) {
    c->n_nodes++;
    if (!add_bytes(&c->pool_len, strlen(d->name)) ||
        !add_bytes(&c->pool_len, strlen(d->public_identifier)) ||
        !add_bytes(&c->pool_len, strlen(d->system_identifier)))
      status = ZUH_LIMIT_MEMORY;
  }

  if (status == ZUH_OK &&
      !stack_push(lg, &st, &cap, &sp, top_of(c, out), ZUH_NONE))
    status = ZUH_LIMIT_MEMORY;
  while (status == ZUH_OK && sp > 0) {
    conv_frame *f = &st[sp - 1];
    const GumboVector *kids = children_of(f->node);
    const GumboNode *n;
    if (kids == NULL || f->next >= kids->length) {
      sp--;
      continue;
    }
    n = (const GumboNode *) kids->data[f->next++];
    if (!keep_node(c, n))
      continue;
    if (++c->n_nodes > (size_t) c->opts->max_nodes) {
      stats->observed = c->n_nodes;
      status = ZUH_LIMIT_NODES;
      break;
    }
    if (is_element(n)) {
      const GumboElement *e = &n->v.element;
      unsigned int i;
      /* sp counts the document frame, so it is this element's depth. */
      if (sp > (size_t) c->opts->max_depth) {
        stats->observed = sp;
        status = ZUH_LIMIT_DEPTH;
        break;
      }
      if (e->tag != GUMBO_TAG_UNKNOWN && e->tag < GUMBO_TAG_LAST) {
        size_t key = (size_t) e->tag * 3u + (size_t) e->tag_namespace;
        if (!seen[key]) {
          seen[key] = 1;
          if (!add_bytes(&c->pool_len, strlen(gumbo_normalized_tagname(e->tag))))
            status = ZUH_LIMIT_MEMORY;
        }
      } else if (!add_bytes(&c->pool_len, unknown_tag_text(e).length)) {
        status = ZUH_LIMIT_MEMORY;
      }
      c->n_attrs += e->attributes.length;
      for (i = 0; i < e->attributes.length && status == ZUH_OK; i++) {
        const GumboAttribute *a = (const GumboAttribute *) e->attributes.data[i];
        if (!add_bytes(&c->pool_len, strlen(a->name)) ||
            !add_bytes(&c->pool_len, strlen(a->value)))
          status = ZUH_LIMIT_MEMORY;
      }
      if (status == ZUH_OK && !stack_push(lg, &st, &cap, &sp, n, ZUH_NONE))
        status = ZUH_LIMIT_MEMORY;
    } else if (!add_bytes(&c->pool_len, strlen(n->v.text.text))) {
      status = ZUH_LIMIT_MEMORY;
    }
  }
  free(st);
  free(seen);
  if (status == ZUH_OK &&
      (c->n_attrs >= (size_t) UINT32_MAX || c->pool_len >= (size_t) UINT32_MAX))
    status = ZUH_LIMIT_MEMORY;
  return status;
}

static uint32_t
pool_add(conv_ctx *c, const char *s, size_t n) {
  uint32_t off = (uint32_t) c->pool_used;
  memcpy(c->doc->pool + c->pool_used, s, n);
  c->doc->pool[c->pool_used + n] = '\0';
  c->pool_used += n + 1;
  return off;
}

static uint32_t
element_name(conv_ctx *c, const GumboElement *e) {
  uint32_t off;
  size_t i, n;
  char *p;
  if (e->tag != GUMBO_TAG_UNKNOWN && e->tag < GUMBO_TAG_LAST) {
    size_t key = (size_t) e->tag * 3u + (size_t) e->tag_namespace;
    if (c->intern[key] == UINT32_MAX) {
      const char *nm = gumbo_normalized_tagname(e->tag);
      off = pool_add(c, nm, strlen(nm));
      if (e->tag_namespace == GUMBO_NAMESPACE_SVG) {
        GumboStringPiece piece;
        const char *fixed;
        piece.data = c->doc->pool + off;
        piece.length = strlen(nm);
        fixed = gumbo_normalize_svg_tagname(&piece);
        if (fixed != NULL && strlen(fixed) == piece.length)
          memcpy(c->doc->pool + off, fixed, piece.length);
      }
      c->intern[key] = off;
    }
    return c->intern[key];
  }
  {
    GumboStringPiece t = unknown_tag_text(e);
    off = pool_add(c, t.data, t.length);
    p = c->doc->pool + off;
    n = t.length;
    for (i = 0; i < n; i++)
      if (p[i] >= 'A' && p[i] <= 'Z')
        p[i] = (char) (p[i] - 'A' + 'a');
    if (e->tag_namespace == GUMBO_NAMESPACE_SVG) {
      GumboStringPiece piece;
      const char *fixed;
      piece.data = p;
      piece.length = n;
      fixed = gumbo_normalize_svg_tagname(&piece);
      if (fixed != NULL && strlen(fixed) == n)
        memcpy(p, fixed, n);
    }
  }
  return off;
}

static void
link_child(zuh_doc *doc, zuh_id parent, zuh_id child) {
  zuh_node *p = &doc->nodes[parent];
  zuh_node *k = &doc->nodes[child];
  k->parent = parent;
  k->prev_sibling = p->last_child;
  k->next_sibling = ZUH_NONE;
  if (p->last_child != ZUH_NONE)
    doc->nodes[p->last_child].next_sibling = child;
  else
    p->first_child = child;
  p->last_child = child;
}

static zuh_id
new_node(zuh_doc *doc, uint8_t type, uint8_t ns) {
  zuh_id id = doc->n_nodes++;
  zuh_node *n = &doc->nodes[id];
  memset(n, 0, sizeof(*n));
  n->type = type;
  n->ns = ns;
  n->parent = n->first_child = n->last_child = ZUH_NONE;
  n->next_sibling = n->prev_sibling = ZUH_NONE;
  n->subtree_end = id;
  return id;
}

static uint8_t
attr_ns(GumboAttributeNamespaceEnum ns) {
  switch (ns) {
  case GUMBO_ATTR_NAMESPACE_XLINK:
    return ZUH_ATTR_NS_XLINK;
  case GUMBO_ATTR_NAMESPACE_XML:
    return ZUH_ATTR_NS_XML;
  case GUMBO_ATTR_NAMESPACE_XMLNS:
    return ZUH_ATTR_NS_XMLNS;
  default:
    return ZUH_ATTR_NS_NONE;
  }
}

static zuh_status
fill_tree(conv_ctx *c, const GumboOutput *out, zuh_ledger *lg) {
  zuh_doc *doc = c->doc;
  const GumboDocument *d = &out->document->v.document;
  conv_frame *st = NULL;
  size_t cap = 0, sp = 0;
  zuh_id id;

  doc->pool[0] = '\0';
  c->pool_used = 1;
  doc->n_nodes = 0;
  doc->n_attrs = 0;

  id = new_node(doc, ZUH_NODE_DOCUMENT, ZUH_NS_HTML);
  doc->is_fragment = c->opts->fragment_tag >= 0;
  doc->context[0] = '\0';
  if (doc->is_fragment && c->opts->fragment_ns == ZUH_NS_HTML &&
      c->opts->fragment_tag < (int) GUMBO_TAG_UNKNOWN) {
    const char *nm = gumbo_normalized_tagname((GumboTag) c->opts->fragment_tag);
    size_t n = strlen(nm);
    if (n < sizeof(doc->context)) {
      memcpy(doc->context, nm, n + 1);
    }
  }
  if (d->has_doctype && !doc->is_fragment) {
    zuh_id dt = new_node(doc, ZUH_NODE_DOCTYPE, ZUH_NS_HTML);
    doc->nodes[dt].name = pool_add(c, d->name, strlen(d->name));
    doc->doctype_public = pool_add(c, d->public_identifier,
                                   strlen(d->public_identifier));
    doc->doctype_system = pool_add(c, d->system_identifier,
                                   strlen(d->system_identifier));
    /* Absent identifiers point at "", like the empty string itself. */
    if (d->public_identifier[0] == '\0')
      doc->doctype_public = 0;
    if (d->system_identifier[0] == '\0')
      doc->doctype_system = 0;
    link_child(doc, id, dt);
  }

  if (!stack_push(lg, &st, &cap, &sp, top_of(c, out), id))
    return ZUH_LIMIT_MEMORY;
  while (sp > 0) {
    conv_frame *f = &st[sp - 1];
    const GumboVector *kids = children_of(f->node);
    const GumboNode *n;
    zuh_id parent = f->id, kid;
    if (kids == NULL || f->next >= kids->length) {
      doc->nodes[parent].subtree_end = doc->n_nodes - 1;
      sp--;
      continue;
    }
    n = (const GumboNode *) kids->data[f->next++];
    if (!keep_node(c, n))
      continue;
    if (is_element(n)) {
      const GumboElement *e = &n->v.element;
      unsigned int i;
      kid = new_node(doc, ZUH_NODE_ELEMENT, (uint8_t) e->tag_namespace);
      if (n->type == GUMBO_NODE_TEMPLATE)
        doc->nodes[kid].flags |= ZUH_FLAG_TEMPLATE;
      doc->nodes[kid].name = element_name(c, e);
      doc->nodes[kid].attr_start = doc->n_attrs;
      doc->nodes[kid].attr_count = e->attributes.length;
      for (i = 0; i < e->attributes.length; i++) {
        const GumboAttribute *a = (const GumboAttribute *) e->attributes.data[i];
        zuh_attr *za = &doc->attrs[doc->n_attrs++];
        za->name = pool_add(c, a->name, strlen(a->name));
        za->value = pool_add(c, a->value, strlen(a->value));
        za->ns = attr_ns(a->attr_namespace);
      }
      link_child(doc, parent, kid);
      if (e->tag == GUMBO_TAG_HTML && parent == 0 && !doc->is_fragment &&
          doc->root == ZUH_NONE)
        doc->root = kid;
      /* Cannot fail for want of memory the count did not foresee, but can
       * for the stack itself. */
      if (!stack_push(lg, &st, &cap, &sp, n, kid)) {
        free(st);
        return ZUH_LIMIT_MEMORY;
      }
    } else {
      uint8_t type = n->type == GUMBO_NODE_COMMENT
                         ? ZUH_NODE_COMMENT
                         : n->type == GUMBO_NODE_PROCESSING_INSTRUCTION
                               ? ZUH_NODE_PI
                               : ZUH_NODE_TEXT;
      kid = new_node(doc, type, ZUH_NS_HTML);
      doc->nodes[kid].value = pool_add(c, n->v.text.text,
                                       strlen(n->v.text.text));
      link_child(doc, parent, kid);
    }
  }
  free(st);
  return ZUH_OK;
}

typedef struct {
  const zuh_parse_opts *opts;
  zuh_doc *doc;
  size_t len;
} parse_ctx;

static zuh_status
collect_problems(const GumboOutput *out, parse_ctx *ctx, zuh_ledger *lg) {
  const GumboVector *errs = &out->errors;
  size_t keep = errs->length;
  zuh_problem *problems = NULL;
  size_t i;

  if (keep > (size_t) ctx->opts->max_errors)
    keep = (size_t) ctx->opts->max_errors;
  if (keep > 0) {
    problems = (zuh_problem *) conv_malloc(lg, keep * sizeof(zuh_problem));
    if (problems == NULL)
      return ZUH_LIMIT_MEMORY;
  }
  for (i = 0; i < keep; i++) {
    const GumboError *e = (const GumboError *) errs->data[i];
    problems[i].code = translate_code(e);
    problems[i].line = e->position.line;
    problems[i].column = e->position.column;
    problems[i].offset = e->position.offset;
  }
  ctx->doc->problems = problems;
  ctx->doc->n_problems = keep;
  ctx->doc->problems_truncated = errs->length > keep;
  return ZUH_OK;
}

static zuh_status
convert_document(const GumboOutput *out, void *vctx, zuh_ledger *lg,
                 zuh_parse_stats *stats) {
  parse_ctx *ctx = (parse_ctx *) vctx;
  zuh_doc *doc = ctx->doc;
  conv_ctx c;
  size_t bytes, i;
  zuh_status st;

  memset(&c, 0, sizeof(c));
  c.opts = ctx->opts;
  c.keep_comments = ctx->opts->keep_comments;
  c.doc = doc;
  c.len = ctx->len;

  st = count_tree(&c, out, lg, stats);
  if (st != ZUH_OK)
    return st;

  /* The frozen document, plus the Gumbo tree still live beside it, must
   * fit the memory budget together. Checked before allocating. */
  bytes = c.n_nodes * sizeof(zuh_node) + c.n_attrs * sizeof(zuh_attr) +
          c.pool_len + N_INTERN * sizeof(uint32_t);
  if (bytes > ctx->opts->max_memory ||
      lg->live_bytes > ctx->opts->max_memory - bytes) {
    stats->observed = lg->live_bytes + bytes;
    return ZUH_LIMIT_MEMORY;
  }

  doc->nodes = (zuh_node *) conv_malloc(lg, c.n_nodes * sizeof(zuh_node));
  doc->attrs = (zuh_attr *) conv_malloc(lg, c.n_attrs * sizeof(zuh_attr));
  doc->pool = (char *) conv_malloc(lg, c.pool_len);
  c.intern = (uint32_t *) conv_malloc(lg, N_INTERN * sizeof(uint32_t));
  if (doc->nodes == NULL || doc->attrs == NULL || doc->pool == NULL ||
      c.intern == NULL) {
    st = ZUH_LIMIT_MEMORY;
    goto fail;
  }
  for (i = 0; i < N_INTERN; i++)
    c.intern[i] = UINT32_MAX;

  st = fill_tree(&c, out, lg);
  if (st != ZUH_OK)
    goto fail;
  st = collect_problems(out, ctx, lg);
  if (st != ZUH_OK)
    goto fail;
  free(c.intern);

  doc->pool_len = c.pool_used;
  doc->input_bytes = ctx->len;
  doc->quirks_mode = (int) out->document->v.document.doc_type_quirks_mode;
  doc->frozen_bytes = sizeof(zuh_doc) + c.n_nodes * sizeof(zuh_node) +
                      c.n_attrs * sizeof(zuh_attr) + c.pool_len +
                      doc->n_problems * sizeof(zuh_problem);
  return ZUH_OK;

fail:
  free(c.intern);
  free(doc->nodes);
  free(doc->attrs);
  free(doc->pool);
  doc->nodes = NULL;
  doc->attrs = NULL;
  doc->pool = NULL;
  doc->n_nodes = 0;
  doc->n_attrs = 0;
  doc->root = ZUH_NONE;
  return st;
}

zuh_status
zuh_gumbo_parse(const char *buf, size_t len, const zuh_parse_opts *opts,
                zuh_doc *doc, zuh_parse_stats *stats) {
  parse_ctx ctx;
  zuh_status st;
  ctx.opts = opts;
  ctx.doc = doc;
  ctx.len = len;
  st = parse_core(buf, len, opts, convert_document, &ctx, stats);
  if (st == ZUH_OK)
    doc->parse_peak_bytes = stats->peak_bytes;
  return st;
}

/* ---- self-tests reported by zuhtml_info() ----------------------------- */

static const zuh_parse_opts selftest_opts = {
  1u << 20, /* max_input */
  1u << 24, /* max_memory */
  512,      /* max_depth */
  100,      /* max_errors */
  1000,     /* max_nodes */
  1,        /* keep_comments */
  -1,       /* fragment_tag */
  0,        /* fragment_ns */
  0         /* fail_at */
};

static zuh_status
check_selftest_tree(const GumboOutput *out, void *vctx, zuh_ledger *lg,
                    zuh_parse_stats *stats) {
  int *ok = (int *) vctx;
  const GumboNode *root = out->root;
  (void) lg;
  (void) stats;
  *ok = 0;
  if (root != NULL && root->type == GUMBO_NODE_ELEMENT &&
      root->v.element.tag == GUMBO_TAG_HTML &&
      out->document->v.document.has_doctype &&
      root->v.element.children.length == 2) {
    const GumboNode *body =
        (const GumboNode *) root->v.element.children.data[1];
    if (body->type == GUMBO_NODE_ELEMENT &&
        body->v.element.tag == GUMBO_TAG_BODY &&
        body->v.element.children.length == 1) {
      const GumboNode *p =
          (const GumboNode *) body->v.element.children.data[0];
      const GumboAttribute *cls =
          gumbo_get_attribute(&p->v.element.attributes, "class");
      *ok = p->v.element.tag == GUMBO_TAG_P && cls != NULL &&
            strcmp(cls->value, "x") == 0;
    }
  }
  return ZUH_OK;
}

static zuh_status
visit_nothing(const GumboOutput *out, void *vctx, zuh_ledger *lg,
              zuh_parse_stats *stats) {
  (void) out;
  (void) vctx;
  (void) lg;
  (void) stats;
  return ZUH_OK;
}

int
zuh_gumbo_selftest(void) {
  static const char doc[] = "<!DOCTYPE html><title>t</title><p class=x>hi";
  zuh_parse_stats stats;
  int ok = 0;
  zuh_status st = parse_core(doc, sizeof(doc) - 1, &selftest_opts,
                             check_selftest_tree, &ok, &stats);
  return st == ZUH_OK && ok;
}

int
zuh_gumbo_depth_selftest(void) {
  enum { NEST = 64 };
  char buf[NEST * 5];
  zuh_parse_opts opts = selftest_opts;
  zuh_parse_stats stats;
  zuh_status limited, unlimited;
  int i;

  for (i = 0; i < NEST; i++)
    memcpy(buf + 5 * i, "<div>", 5);

  opts.max_depth = 16;
  limited = parse_core(buf, sizeof(buf), &opts, visit_nothing, NULL, &stats);
  opts.max_depth = 512;
  unlimited = parse_core(buf, sizeof(buf), &opts, visit_nothing, NULL, &stats);
  return limited == ZUH_LIMIT_DEPTH && unlimited == ZUH_OK;
}
