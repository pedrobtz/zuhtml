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
  "0003-modification-notices"
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

/* ---- the abortable region ------------------------------------------- */

/* Runs on a complete Gumbo tree, before bulk free. Must not allocate
 * through the ledger. Returns ZUH_OK or a status to fail the parse with. */
typedef zuh_status (*zuh_visit_fn)(const GumboOutput *out, void *ctx,
                                   zuh_parse_stats *stats);

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

  stats->n_allocs = lg->n_allocs;
  stats->peak_bytes = lg->peak_bytes;
  if (lg->corrupt) {
    st = ZUH_ERR_INTERNAL;
  } else if (out->status == GUMBO_STATUS_TREE_TOO_DEEP) {
    stats->observed = (size_t) opts->max_depth + 1;
    st = ZUH_LIMIT_DEPTH;
  } else {
    st = visit(out, ctx, stats);
  }
  zuh_ledger_free_all(lg);
  return st;
}

typedef struct {
  const zuh_parse_opts *opts;
  zuh_doc *doc;
  size_t len;
} parse_ctx;

static zuh_status
collect_document(const GumboOutput *out, void *vctx, zuh_parse_stats *stats) {
  parse_ctx *ctx = (parse_ctx *) vctx;
  const GumboVector *errs = &out->errors;
  size_t keep = errs->length;
  zuh_problem *problems = NULL;
  size_t i;

  (void) stats;
  if (keep > (size_t) ctx->opts->max_errors)
    keep = (size_t) ctx->opts->max_errors;
  if (keep > 0) {
    problems = (zuh_problem *) malloc(keep * sizeof(zuh_problem));
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
  ctx->doc->input_bytes = ctx->len;
  ctx->doc->quirks_mode =
      (int) out->document->v.document.doc_type_quirks_mode;
  return ZUH_OK;
}

zuh_status
zuh_gumbo_parse(const char *buf, size_t len, const zuh_parse_opts *opts,
                zuh_doc *doc, zuh_parse_stats *stats) {
  parse_ctx ctx;
  zuh_status st;
  ctx.opts = opts;
  ctx.doc = doc;
  ctx.len = len;
  st = parse_core(buf, len, opts, collect_document, &ctx, stats);
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
  0         /* fail_at */
};

static zuh_status
check_selftest_tree(const GumboOutput *out, void *vctx,
                    zuh_parse_stats *stats) {
  int *ok = (int *) vctx;
  const GumboNode *root = out->root;
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
visit_nothing(const GumboOutput *out, void *vctx, zuh_parse_stats *stats) {
  (void) out;
  (void) vctx;
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
