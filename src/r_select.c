/* CSS selection over the frozen document. R-facing.
 *
 * The compiled selector is malloc'd by the pure-C core, so it is owned by
 * an external pointer created before compiling: an interrupt that
 * long-jumps out of the matching loop leaves it to the finalizer. Every
 * other buffer here is R_alloc memory. */
#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Utils.h>

#include <string.h>

#include "zuh_document.h"
#include "zuh_r.h"
#include "zuh_selector.h"

static void
selector_finalize(SEXP ptr) {
  zuh_selector *sel = (zuh_selector *) R_ExternalPtrAddr(ptr);
  if (sel != NULL) {
    R_ClearExternalPtr(ptr);
    zuh_selector_free(sel);
  }
}

static SEXP
selector_error(const zuh_sel_error *err) {
  static const char *const kinds[] = {"ok", "syntax", "unsupported",
                                      "too_complex", "no_memory"};
  const char *names[] = {"error", "position", "reason", ""};
  SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
  SET_VECTOR_ELT(out, 0, Rf_mkString(kinds[err->status]));
  SET_VECTOR_ELT(out, 1, Rf_ScalarReal((double) err->position));
  SET_VECTOR_ELT(out, 2, Rf_mkString(err->reason ? err->reason : ""));
  UNPROTECT(1);
  return out;
}

static SEXP
work_error(void) {
  const char *names[] = {"error", ""};
  SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
  SET_VECTOR_ELT(out, 0, Rf_mkString("work"));
  UNPROTECT(1);
  return out;
}

/* The candidates of a search from context `c` are its descendants in
 * document order, skipping template contents; the context itself when the
 * selector's subject has :scope. Calls `visit` on each element until it
 * returns nonzero. Returns 1 if a visit stopped the walk. */
typedef int (*visit_fn)(zuh_match_ctx *m, zuh_id id, zuh_id scope,
                        void *data);

static int
walk(zuh_match_ctx *m, zuh_id c, visit_fn visit, void *data,
     R_xlen_t *polled) {
  const zuh_doc *doc = m->doc;
  const zuh_node *cn = &doc->nodes[c];
  zuh_id scope, id, end;

  if (cn->type == ZUH_NODE_DOCUMENT) {
    scope = doc->root;
  } else if (cn->type == ZUH_NODE_ELEMENT) {
    scope = c;
    if (zuh_selector_scopes_subject(m->sel) && visit(m, c, scope, data))
      return 1;
    /* A template's descendants are its inert contents. */
    if ((cn->flags & ZUH_FLAG_TEMPLATE) != 0)
      return 0;
  } else {
    return 0;
  }
  end = cn->subtree_end;
  for (id = c + 1; id <= end && id != ZUH_NONE; id++) {
    const zuh_node *n = &doc->nodes[id];
    if (n->type != ZUH_NODE_ELEMENT)
      continue;
    if (visit(m, id, scope, data))
      return 1;
    if (m->exceeded)
      return 0;
    if ((n->flags & ZUH_FLAG_TEMPLATE) != 0)
      id = n->subtree_end;
    if ((++*polled & 0x3FFF) == 0)
      R_CheckUserInterrupt();
  }
  return 0;
}

static int
visit_mark(zuh_match_ctx *m, zuh_id id, zuh_id scope, void *data) {
  unsigned char *mark = (unsigned char *) data;
  if (!mark[id] && zuh_selector_matches(m, id, scope))
    mark[id] = 1;
  return 0;
}

static int
visit_first(zuh_match_ctx *m, zuh_id id, zuh_id scope, void *data) {
  zuh_id *found = (zuh_id *) data;
  if (zuh_selector_matches(m, id, scope)) {
    *found = id;
    return 1;
  }
  return 0;
}

/* C_zuh_select(ptr, ids, css, mode, work_limit)
 *
 *   mode 0: every match below every context, deduplicated, in document
 *           order (integer IDs)
 *   mode 1: the first match below each context (integer, aligned, NA for
 *           none or a missing context)
 *   mode 2: whether each node itself matches (logical, aligned, NA for a
 *           missing node)
 *   mode 3: the nearest inclusive ancestor of each node that matches
 *           (integer, aligned, NA for none or a missing node)
 *
 * Returns NULL for a dead pointer or an out-of-range ID, and a list with
 * an `error` element for a selector that does not compile ("syntax",
 * "unsupported", "too_complex", "no_memory") or a search that exceeded
 * the work limit ("work"). */
SEXP
C_zuh_select(SEXP ptr, SEXP ids, SEXP css, SEXP mode, SEXP work_limit) {
  const zuh_doc *doc = zuh_r_doc(ptr);
  zuh_selector *sel = NULL;
  zuh_sel_error err;
  zuh_match_ctx m;
  SEXP sp, out;
  R_xlen_t i, n, polled = 0;
  int md = Rf_asInteger(mode);
  const char *text;

  if (doc == NULL || TYPEOF(ids) != INTSXP)
    return R_NilValue;
  n = XLENGTH(ids);
  for (i = 0; i < n; i++) {
    int id = INTEGER(ids)[i];
    if (id != NA_INTEGER && (id < 0 || (uint32_t) id >= doc->n_nodes))
      return R_NilValue;
  }

  sp = PROTECT(R_MakeExternalPtr(NULL, R_NilValue, R_NilValue));
  R_RegisterCFinalizerEx(sp, selector_finalize, TRUE);
  text = Rf_translateCharUTF8(STRING_ELT(css, 0));
  if (zuh_selector_compile(text, strlen(text), &sel, &err) != ZUH_SEL_OK) {
    UNPROTECT(1);
    return selector_error(&err);
  }
  R_SetExternalPtrAddr(sp, sel);

  memset(&m, 0, sizeof(m));
  m.doc = doc;
  m.sel = sel;
  m.work_limit = (uint64_t) Rf_asReal(work_limit);
  if (zuh_selector_needs_positions(sel)) {
    int32_t *pos = (int32_t *) R_alloc(doc->n_nodes, sizeof(int32_t));
    int32_t *cnt = (int32_t *) R_alloc(doc->n_nodes, sizeof(int32_t));
    zuh_selector_positions(doc, pos, cnt);
    m.elem_pos = pos;
    m.elem_count = cnt;
  }

  if (md == 0) {
    unsigned char *mark = (unsigned char *) R_alloc(doc->n_nodes, 1);
    R_xlen_t k = 0, total = 0;
    zuh_id id;
    memset(mark, 0, doc->n_nodes);
    for (i = 0; i < n && !m.exceeded; i++) {
      int c = INTEGER(ids)[i];
      if (c != NA_INTEGER)
        walk(&m, (zuh_id) c, visit_mark, mark, &polled);
    }
    if (m.exceeded) {
      UNPROTECT(1);
      return work_error();
    }
    for (id = 0; id < doc->n_nodes; id++)
      total += mark[id];
    out = PROTECT(Rf_allocVector(INTSXP, total));
    for (id = 0; id < doc->n_nodes; id++)
      if (mark[id])
        INTEGER(out)[k++] = (int) id;
  } else if (md == 1) {
    out = PROTECT(Rf_allocVector(INTSXP, n));
    for (i = 0; i < n && !m.exceeded; i++) {
      int c = INTEGER(ids)[i];
      zuh_id found = ZUH_NONE;
      if (c != NA_INTEGER)
        walk(&m, (zuh_id) c, visit_first, &found, &polled);
      INTEGER(out)[i] = found == ZUH_NONE ? NA_INTEGER : (int) found;
    }
  } else if (md == 3) {
    /* The nearest inclusive ancestor element that matches, with :scope
     * the node itself, as the DOM's closest(). */
    out = PROTECT(Rf_allocVector(INTSXP, n));
    for (i = 0; i < n && !m.exceeded; i++) {
      int c = INTEGER(ids)[i];
      zuh_id cur = c == NA_INTEGER ? ZUH_NONE : (zuh_id) c, found = ZUH_NONE;
      while (cur != ZUH_NONE && doc->nodes[cur].type != ZUH_NODE_DOCUMENT) {
        if (zuh_selector_matches(&m, cur, (zuh_id) c)) {
          found = cur;
          break;
        }
        cur = doc->nodes[cur].parent;
      }
      INTEGER(out)[i] = found == ZUH_NONE ? NA_INTEGER : (int) found;
      if ((i & 0x3FFF) == 0x3FFF)
        R_CheckUserInterrupt();
    }
  } else {
    out = PROTECT(Rf_allocVector(LGLSXP, n));
    for (i = 0; i < n && !m.exceeded; i++) {
      int c = INTEGER(ids)[i];
      LOGICAL(out)[i] =
          c == NA_INTEGER ? NA_LOGICAL
                          : zuh_selector_matches(&m, (zuh_id) c, (zuh_id) c);
      if ((i & 0x3FFF) == 0x3FFF)
        R_CheckUserInterrupt();
    }
  }
  if (m.exceeded) {
    UNPROTECT(2);
    return work_error();
  }
  /* Free the selector now rather than at the next collection. */
  selector_finalize(sp);
  UNPROTECT(2);
  return out;
}
