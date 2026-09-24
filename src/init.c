#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>

#include "zuh_gumbo.h"

static SEXP
mk_scalar_utf8(const char *s) {
  return Rf_ScalarString(Rf_mkCharCE(s, CE_UTF8));
}

static SEXP
C_zuhtml_info(void) {
  const char *names[] = {"gumbo_version", "gumbo_patches", "parser_ok",
                         "depth_limit_ok", ""};
  const char *const *ids;
  int n = zuh_gumbo_patches(&ids);
  SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
  SEXP patches = PROTECT(Rf_allocVector(STRSXP, n));
  int i;

  for (i = 0; i < n; i++)
    SET_STRING_ELT(patches, i, Rf_mkCharCE(ids[i], CE_UTF8));
  SET_VECTOR_ELT(out, 0, mk_scalar_utf8(zuh_gumbo_version()));
  SET_VECTOR_ELT(out, 1, patches);
  SET_VECTOR_ELT(out, 2, Rf_ScalarLogical(zuh_gumbo_selftest()));
  SET_VECTOR_ELT(out, 3, Rf_ScalarLogical(zuh_gumbo_depth_selftest()));

  UNPROTECT(2);
  return out;
}

/* Entry points are added here as they are implemented; see
 * .agents/roadmap.md. Symbol search is off and symbols are forced from the
 * first commit rather than being retrofitted later. */
static const R_CallMethodDef call_methods[] = {
  {"C_zuhtml_info", (DL_FUNC) &C_zuhtml_info, 0},
  {NULL, NULL, 0}
};

void R_init_zuhtml(DllInfo *dll);

void attribute_visible
R_init_zuhtml(DllInfo *dll) {
  R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
}
