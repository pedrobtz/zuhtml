/* R-facing entry points: validation, ownership and conversion to R values.
 * The only project-owned C besides init.c that includes R headers.
 *
 * Ownership rule: a zuh_doc is owned by an external pointer from the moment
 * it exists. C_zuh_doc_new() creates the pointer (and its finalizer) before
 * any parse; C_zuh_parse() mallocs the document, stores it in the pointer
 * at once, and only then runs the parse, which makes no R call. An R
 * allocation failure anywhere therefore unwinds past nothing unowned. */
#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>

#include <limits.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "zuh_document.h"
#include "zuh_gumbo.h"
#include "zuh_r.h"

static SEXP
doc_tag(void) {
  static SEXP tag = NULL;
  if (tag == NULL)
    tag = Rf_install("zuhtml_document");
  return tag;
}

static void
doc_finalize(SEXP ptr) {
  zuh_doc *doc = (zuh_doc *) R_ExternalPtrAddr(ptr);
  if (doc != NULL) {
    R_ClearExternalPtr(ptr);
    zuh_doc_free(doc);
  }
}

/* The live document behind `ptr`, or NULL if `ptr` is not a zuhtml
 * document pointer or its document is gone (finalized, or restored from a
 * serialized session). Callers turn NULL into zuhtml_pointer_error in R. */
zuh_doc *
zuh_r_doc(SEXP ptr) {
  if (TYPEOF(ptr) != EXTPTRSXP || R_ExternalPtrTag(ptr) != doc_tag())
    return NULL;
  return (zuh_doc *) R_ExternalPtrAddr(ptr);
}

SEXP
C_zuh_doc_new(void) {
  SEXP ptr = PROTECT(R_MakeExternalPtr(NULL, doc_tag(), R_NilValue));
  R_RegisterCFinalizerEx(ptr, doc_finalize, TRUE);
  UNPROTECT(1);
  return ptr;
}

SEXP
C_zuh_doc_alive(SEXP ptr) {
  return Rf_ScalarLogical(zuh_r_doc(ptr) != NULL);
}

/* A double that R validated as a whole number in [0, 2^53], as size_t,
 * saturating at SIZE_MAX. */
static size_t
as_size(double v) {
  if (v >= (double) SIZE_MAX)
    return SIZE_MAX;
  return (size_t) v;
}

/* C_zuh_parse(ptr, bytes, limits, comments, fail_at)
 *
 *   ptr      from C_zuh_doc_new(), not yet holding a document
 *   bytes    raw: decoded, validated UTF-8 with no NUL
 *   limits   double: max_input, max_memory, max_depth, max_errors,
 *            max_nodes, validated in R
 *   comments logical: keep comment nodes
 *   fail_at  double: fault injection index, 0 for none
 *
 * Returns double(4): status (a zuh_status), observed, allocations, peak
 * bytes. R maps the status to a condition. On ZUH_OK the document is in
 * `ptr`; otherwise `ptr` is left empty and everything is freed. */
SEXP
C_zuh_parse(SEXP ptr, SEXP bytes, SEXP limits, SEXP comments,
            SEXP fail_at) {
  zuh_parse_opts opts;
  zuh_parse_stats stats;
  zuh_status st;
  zuh_doc *doc;
  SEXP out;
  double *o;

  if (TYPEOF(ptr) != EXTPTRSXP || R_ExternalPtrTag(ptr) != doc_tag() ||
      R_ExternalPtrAddr(ptr) != NULL)
    Rf_error("internal error: C_zuh_parse needs a fresh document pointer");
  if (TYPEOF(bytes) != RAWSXP || TYPEOF(limits) != REALSXP ||
      XLENGTH(limits) != 5 || TYPEOF(comments) != LGLSXP ||
      XLENGTH(comments) != 1 || TYPEOF(fail_at) != REALSXP ||
      XLENGTH(fail_at) != 1)
    Rf_error("internal error: bad arguments to C_zuh_parse");

  opts.max_input = as_size(REAL(limits)[0]);
  opts.max_memory = as_size(REAL(limits)[1]);
  opts.max_depth = REAL(limits)[2] >= (double) UINT_MAX
                       ? UINT_MAX
                       : (unsigned int) REAL(limits)[2];
  opts.max_errors = REAL(limits)[3] >= (double) INT_MAX
                        ? INT_MAX
                        : (int) REAL(limits)[3];
  opts.max_nodes = as_size(REAL(limits)[4]);
  opts.keep_comments = LOGICAL(comments)[0] == TRUE;
  opts.fail_at = as_size(REAL(fail_at)[0]);

  /* Every R allocation happens before the document exists. */
  out = PROTECT(Rf_allocVector(REALSXP, 4));
  o = REAL(out);

  doc = zuh_doc_new();
  if (doc == NULL) {
    o[0] = (double) ZUH_LIMIT_MEMORY;
    o[1] = o[2] = o[3] = 0;
    UNPROTECT(1);
    return out;
  }
  R_SetExternalPtrAddr(ptr, doc);

  st = zuh_gumbo_parse((const char *) RAW(bytes), (size_t) XLENGTH(bytes),
                       &opts, doc, &stats);
  if (st != ZUH_OK) {
    R_ClearExternalPtr(ptr);
    zuh_doc_free(doc);
  }

  o[0] = (double) st;
  o[1] = (double) stats.observed;
  o[2] = (double) stats.n_allocs;
  o[3] = (double) stats.peak_bytes;
  UNPROTECT(1);
  return out;
}

static SEXP
mk_utf8(const char *s) {
  return Rf_mkCharCE(s, CE_UTF8);
}

static int
as_int(unsigned int v) {
  return v > (unsigned int) INT_MAX ? NA_INTEGER : (int) v;
}

/* list(stage, code, line, column, byte_offset, truncated), or NULL for a
 * dead pointer. */
SEXP
C_zuh_doc_problems(SEXP ptr) {
  const char *names[] = {"stage", "code", "line", "column", "byte_offset",
                         "truncated", ""};
  zuh_doc *doc = zuh_r_doc(ptr);
  SEXP out, stage, code, line, col, off;
  R_xlen_t n, i;

  if (doc == NULL)
    return R_NilValue;
  n = (R_xlen_t) doc->n_problems;
  out = PROTECT(Rf_mkNamed(VECSXP, names));
  stage = Rf_allocVector(STRSXP, n);
  SET_VECTOR_ELT(out, 0, stage);
  code = Rf_allocVector(STRSXP, n);
  SET_VECTOR_ELT(out, 1, code);
  line = Rf_allocVector(INTSXP, n);
  SET_VECTOR_ELT(out, 2, line);
  col = Rf_allocVector(INTSXP, n);
  SET_VECTOR_ELT(out, 3, col);
  off = Rf_allocVector(INTSXP, n);
  SET_VECTOR_ELT(out, 4, off);
  SET_VECTOR_ELT(out, 5, Rf_ScalarLogical(doc->problems_truncated));

  for (i = 0; i < n; i++) {
    const zuh_problem *p = &doc->problems[i];
    const char *name = zuh_problem_code_name(p->code);
    int st = zuh_problem_code_stage(p->code);
    SET_STRING_ELT(stage, i,
                   st == 0 ? mk_utf8("tokenizer")
                           : st == 1 ? mk_utf8("parser") : NA_STRING);
    SET_STRING_ELT(code, i, name != NULL ? mk_utf8(name) : NA_STRING);
    INTEGER(line)[i] = as_int(p->line);
    INTEGER(col)[i] = as_int(p->column);
    INTEGER(off)[i] = as_int(p->offset);
  }
  UNPROTECT(1);
  return out;
}

/* list(input_bytes, parse_peak_bytes, quirks_mode, n_problems,
 * problems_truncated, n_nodes, n_attrs, frozen_bytes), or NULL for a dead
 * pointer. */
SEXP
C_zuh_doc_meta(SEXP ptr) {
  const char *names[] = {"input_bytes", "parse_peak_bytes", "quirks_mode",
                         "n_problems", "problems_truncated", "n_nodes",
                         "n_attrs", "frozen_bytes", ""};
  static const char *const quirks[] = {"no-quirks", "quirks",
                                       "limited-quirks"};
  zuh_doc *doc = zuh_r_doc(ptr);
  SEXP out;

  if (doc == NULL)
    return R_NilValue;
  out = PROTECT(Rf_mkNamed(VECSXP, names));
  SET_VECTOR_ELT(out, 0, Rf_ScalarReal((double) doc->input_bytes));
  SET_VECTOR_ELT(out, 1, Rf_ScalarReal((double) doc->parse_peak_bytes));
  SET_VECTOR_ELT(out, 2,
                 Rf_ScalarString(doc->quirks_mode >= 0 && doc->quirks_mode <= 2
                                     ? mk_utf8(quirks[doc->quirks_mode])
                                     : NA_STRING));
  SET_VECTOR_ELT(out, 3, Rf_ScalarReal((double) doc->n_problems));
  SET_VECTOR_ELT(out, 4, Rf_ScalarLogical(doc->problems_truncated));
  SET_VECTOR_ELT(out, 5, Rf_ScalarReal((double) doc->n_nodes));
  SET_VECTOR_ELT(out, 6, Rf_ScalarReal((double) doc->n_attrs));
  SET_VECTOR_ELT(out, 7, Rf_ScalarReal((double) doc->frozen_bytes));
  UNPROTECT(1);
  return out;
}

/* The tree in the html5lib test format, as one string, or NULL for a dead
 * pointer. Internal: the conformance gate and the tests use it. */
SEXP
C_zuh_doc_dump(SEXP ptr) {
  zuh_doc *doc = zuh_r_doc(ptr);
  char *buf;
  size_t len;
  SEXP out;

  if (doc == NULL)
    return R_NilValue;
  if (zuh_doc_dump(doc, &buf, &len) != ZUH_OK)
    Rf_error("out of memory rendering the tree");
  if (len > (size_t) INT_MAX) {
    free(buf);
    Rf_error("tree rendering too long for an R string");
  }
  /* mkCharLenCE can fail and long-jump; free the buffer first by copying
   * into R_alloc memory, which R reclaims either way. */
  {
    char *copy = R_alloc(len + 1, 1);
    memcpy(copy, buf, len + 1);
    free(buf);
    out = PROTECT(Rf_ScalarString(Rf_mkCharLenCE(copy, (int) len, CE_UTF8)));
  }
  UNPROTECT(1);
  return out;
}
