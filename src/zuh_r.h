/* Declarations shared by the R-facing sources, init.c and r_api.c. */
#ifndef ZUH_R_H
#define ZUH_R_H

#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>

#include "zuh_document.h"

zuh_doc *zuh_r_doc(SEXP ptr);

SEXP C_zuh_doc_new(void);
SEXP C_zuh_doc_alive(SEXP ptr);
SEXP C_zuh_parse(SEXP ptr, SEXP bytes, SEXP limits, SEXP comments,
                 SEXP fail_at);
SEXP C_zuh_doc_problems(SEXP ptr);
SEXP C_zuh_doc_meta(SEXP ptr);
SEXP C_zuh_doc_dump(SEXP ptr);

#endif
