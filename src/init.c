#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>

/* Stage 0 smoke entry point: proves the shared object is built, loaded and
 * registered. Replaced by zuhtml_info() once Gumbo is vendored (Stage 1). */
static SEXP
C_zuh_loaded(void) {
  return Rf_ScalarLogical(TRUE);
}

/* Entry points are added here as they are implemented; see
 * .agents/roadmap.md. Symbol search is off and symbols are forced from the
 * first commit rather than being retrofitted later. */
static const R_CallMethodDef call_methods[] = {
  {"C_zuh_loaded", (DL_FUNC) &C_zuh_loaded, 0},
  {NULL, NULL, 0}
};

void attribute_visible
R_init_zuhtml(DllInfo *dll) {
  R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
}
