/* Extraction entry points: cleaned text, table grids, outermost nodes.
 * R-facing. Scratch memory is R_alloc'd throughout, so an interrupt or an
 * R allocation failure strands nothing. */
#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Utils.h>

#include <limits.h>
#include <string.h>

#include "zuh_document.h"
#include "zuh_markdown.h"
#include "zuh_r.h"
#include "zuh_table.h"
#include "zuh_text.h"

static const zuh_doc *
doc_ids(SEXP ptr, SEXP ids) {
  const zuh_doc *doc = zuh_r_doc(ptr);
  R_xlen_t i, n;
  if (doc == NULL || TYPEOF(ids) != INTSXP)
    return NULL;
  n = XLENGTH(ids);
  for (i = 0; i < n; i++) {
    int id = INTEGER(ids)[i];
    if (id != NA_INTEGER && (id < 0 || (uint32_t) id >= doc->n_nodes))
      return NULL;
  }
  return doc;
}

/* Aligned: html_text_clean() of each node. NA for missing nodes and for
 * nodes other than elements, documents, fragments and text. */
SEXP
C_zuh_text_clean(SEXP ptr, SEXP ids, SEXP opts) {
  const zuh_doc *doc = doc_ids(ptr, ids);
  zuh_clean_opts o;
  R_xlen_t i, n;
  SEXP out;
  if (doc == NULL || TYPEOF(opts) != LGLSXP || XLENGTH(opts) != 4)
    return R_NilValue;
  o.trim = LOGICAL(opts)[0] == TRUE;
  o.nbsp = LOGICAL(opts)[1] == TRUE;
  o.skip_lists = LOGICAL(opts)[2] == TRUE;
  o.skip_tables = LOGICAL(opts)[3] == TRUE;
  n = XLENGTH(ids);
  out = PROTECT(Rf_allocVector(STRSXP, n));
  for (i = 0; i < n; i++) {
    int id = INTEGER(ids)[i];
    uint8_t type;
    const void *vmax;
    zuh_buf b;
    if (id == NA_INTEGER) {
      SET_STRING_ELT(out, i, NA_STRING);
      continue;
    }
    type = doc->nodes[id].type;
    if (type != ZUH_NODE_ELEMENT && type != ZUH_NODE_DOCUMENT &&
        type != ZUH_NODE_TEXT) {
      SET_STRING_ELT(out, i, NA_STRING);
      continue;
    }
    vmax = vmaxget();
    zuh_buf_init(&b, zuh_r_alloc, NULL);
    if (zuh_text_clean(doc, (zuh_id) id, &o, &b) != ZUH_OK)
      Rf_error("out of memory extracting text");
    if (b.len > (size_t) INT_MAX)
      Rf_error("text too long for an R string");
    SET_STRING_ELT(out, i, Rf_mkCharLenCE(b.buf, (int) b.len, CE_UTF8));
    vmaxset(vmax);
    if ((i & 0xFFF) == 0xFFF)
      R_CheckUserInterrupt();
  }
  UNPROTECT(1);
  return out;
}

/* Aligned: html_markdown() of each node. `url_ids` (ascending) and `urls`
 * are the resolved link and image URLs, NA where the attribute is to be
 * used as written. NA for missing nodes and for nodes other than elements,
 * documents, fragments and text. */
SEXP
C_zuh_markdown(SEXP ptr, SEXP ids, SEXP url_ids, SEXP urls) {
  const zuh_doc *doc = doc_ids(ptr, ids);
  zuh_md_urls u;
  zuh_id *uid;
  const char **ustr;
  R_xlen_t i, n, nu;
  SEXP out;
  if (doc == NULL || TYPEOF(url_ids) != INTSXP || TYPEOF(urls) != STRSXP ||
      XLENGTH(url_ids) != XLENGTH(urls))
    return R_NilValue;
  nu = XLENGTH(url_ids);
  uid = (zuh_id *) R_alloc((size_t) nu + 1, sizeof(zuh_id));
  ustr = (const char **) R_alloc((size_t) nu + 1, sizeof(char *));
  for (i = 0; i < nu; i++) {
    int id = INTEGER(url_ids)[i];
    SEXP s = STRING_ELT(urls, i);
    if (id == NA_INTEGER || id < 0 || (i > 0 && (zuh_id) id <= uid[i - 1]))
      return R_NilValue;
    uid[i] = (zuh_id) id;
    ustr[i] = s == NA_STRING ? NULL : Rf_translateCharUTF8(s);
  }
  u.ids = uid;
  u.urls = ustr;
  u.n = (size_t) nu;
  n = XLENGTH(ids);
  out = PROTECT(Rf_allocVector(STRSXP, n));
  for (i = 0; i < n; i++) {
    int id = INTEGER(ids)[i];
    uint8_t type;
    const void *vmax;
    zuh_buf b;
    if (id == NA_INTEGER) {
      SET_STRING_ELT(out, i, NA_STRING);
      continue;
    }
    type = doc->nodes[id].type;
    if (type != ZUH_NODE_ELEMENT && type != ZUH_NODE_DOCUMENT &&
        type != ZUH_NODE_TEXT) {
      SET_STRING_ELT(out, i, NA_STRING);
      continue;
    }
    vmax = vmaxget();
    zuh_buf_init(&b, zuh_r_alloc, NULL);
    if (zuh_markdown(doc, (zuh_id) id, &u, &b) != ZUH_OK)
      Rf_error("out of memory writing Markdown");
    if (b.len > (size_t) INT_MAX)
      Rf_error("Markdown too long for an R string");
    SET_STRING_ELT(out, i, Rf_mkCharLenCE(b.buf, (int) b.len, CE_UTF8));
    vmaxset(vmax);
    if ((i & 0xFFF) == 0xFFF)
      R_CheckUserInterrupt();
  }
  UNPROTECT(1);
  return out;
}

/* Of `ids`, sorted ascending, those not inside the subtree of an earlier
 * one: the outermost nodes. */
SEXP
C_zuh_outermost(SEXP ptr, SEXP ids) {
  const zuh_doc *doc = doc_ids(ptr, ids);
  R_xlen_t i, n, k = 0;
  int *keep;
  zuh_id end = 0;
  int have = 0;
  SEXP out;
  if (doc == NULL)
    return R_NilValue;
  n = XLENGTH(ids);
  keep = (int *) R_alloc((size_t) n + 1, sizeof(int));
  for (i = 0; i < n; i++) {
    int id = INTEGER(ids)[i];
    if (id == NA_INTEGER)
      continue;
    if (have && (zuh_id) id <= end)
      continue;
    keep[k++] = id;
    end = doc->nodes[id].subtree_end;
    have = 1;
  }
  out = PROTECT(Rf_allocVector(INTSXP, k));
  if (k > 0)
    memcpy(INTEGER(out), keep, (size_t) k * sizeof(int));
  UNPROTECT(1);
  return out;
}

static SEXP
int_vec(const uint32_t *v, uint32_t n) {
  SEXP out = PROTECT(Rf_allocVector(INTSXP, n));
  uint32_t i;
  for (i = 0; i < n; i++)
    INTEGER(out)[i] = (int) v[i];
  UNPROTECT(1);
  return out;
}

/* The grid of one <table>: list(nrows, ncols, row_group, row_all_th,
 * cell_node, slot), slot being row-major 0-based cell indices or -1. On
 * failure list(error = "overlap", row, cell) or list(error = "limit",
 * slots). NULL for a bad pointer or ID. */
SEXP
C_zuh_table(SEXP ptr, SEXP id, SEXP max_cells) {
  const zuh_doc *doc = doc_ids(ptr, id);
  zuh_table t;
  zuh_status st;
  SEXP out;
  size_t k, nslots;
  if (doc == NULL || XLENGTH(id) != 1 || INTEGER(id)[0] == NA_INTEGER)
    return R_NilValue;
  st = zuh_table_grid(doc, (zuh_id) INTEGER(id)[0], Rf_asReal(max_cells),
                      zuh_r_alloc, NULL, &t);
  if (st == ZUH_ERR_TABLE_OVERLAP) {
    const char *names[] = {"error", "row", "cell", ""};
    out = PROTECT(Rf_mkNamed(VECSXP, names));
    SET_VECTOR_ELT(out, 0, Rf_mkString("overlap"));
    SET_VECTOR_ELT(out, 1, Rf_ScalarInteger((int) t.err_row));
    SET_VECTOR_ELT(out, 2, Rf_ScalarInteger((int) t.err_cell));
    UNPROTECT(1);
    return out;
  }
  if (st == ZUH_LIMIT_TABLE) {
    const char *names[] = {"error", "slots", ""};
    out = PROTECT(Rf_mkNamed(VECSXP, names));
    SET_VECTOR_ELT(out, 0, Rf_mkString("limit"));
    SET_VECTOR_ELT(out, 1, Rf_ScalarReal(t.err_slots));
    UNPROTECT(1);
    return out;
  }
  if (st != ZUH_OK)
    Rf_error("out of memory building a table grid");
  {
    const char *names[] = {"nrows", "ncols", "row_group", "row_all_th",
                           "cell_node", "slot", ""};
    SEXP rg, th, sl;
    out = PROTECT(Rf_mkNamed(VECSXP, names));
    SET_VECTOR_ELT(out, 0, Rf_ScalarInteger((int) t.nrows));
    SET_VECTOR_ELT(out, 1, Rf_ScalarInteger((int) t.ncols));
    rg = Rf_allocVector(INTSXP, t.nrows);
    SET_VECTOR_ELT(out, 2, rg);
    th = Rf_allocVector(LGLSXP, t.nrows);
    SET_VECTOR_ELT(out, 3, th);
    for (k = 0; k < t.nrows; k++) {
      INTEGER(rg)[k] = t.row_group[k];
      LOGICAL(th)[k] = t.row_all_th[k];
    }
    SET_VECTOR_ELT(out, 4, int_vec(t.cell_node, t.ncells));
    nslots = (size_t) t.nrows * t.ncols;
    sl = Rf_allocVector(INTSXP, (R_xlen_t) nslots);
    SET_VECTOR_ELT(out, 5, sl);
    for (k = 0; k < nslots; k++)
      INTEGER(sl)[k] = t.slot[k];
    UNPROTECT(1);
  }
  return out;
}
