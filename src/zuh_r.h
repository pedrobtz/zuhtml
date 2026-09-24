/* Declarations shared by the R-facing sources, init.c and r_api.c. */
#ifndef ZUH_R_H
#define ZUH_R_H

#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>

#include "zuh_document.h"

zuh_doc *zuh_r_doc(SEXP ptr);

/* A zuh_alloc_fn backed by R_alloc, for zuh_buf. */
void *zuh_r_alloc(void *userdata, size_t n);

SEXP C_zuh_doc_new(void);
SEXP C_zuh_doc_alive(SEXP ptr);
SEXP C_zuh_doc_release(SEXP ptr);
SEXP C_zuh_parse(SEXP ptr, SEXP bytes, SEXP limits, SEXP comments,
                 SEXP fragment, SEXP fail_at);
SEXP C_zuh_tag_lookup(SEXP name, SEXP allow_unknown);
SEXP C_zuh_doc_problems(SEXP ptr);
SEXP C_zuh_doc_meta(SEXP ptr);
SEXP C_zuh_doc_dump(SEXP ptr);

SEXP C_zuh_node_type(SEXP ptr, SEXP ids);
SEXP C_zuh_node_name(SEXP ptr, SEXP ids);
SEXP C_zuh_node_namespace(SEXP ptr, SEXP ids);
SEXP C_zuh_node_parent(SEXP ptr, SEXP ids);
SEXP C_zuh_node_sibling(SEXP ptr, SEXP ids, SEXP next, SEXP elements_only);
SEXP C_zuh_node_children(SEXP ptr, SEXP ids, SEXP elements_only,
                         SEXP templates_only);
SEXP C_zuh_node_ancestors(SEXP ptr, SEXP ids);
SEXP C_zuh_node_attr(SEXP ptr, SEXP ids, SEXP name, SEXP dflt);
SEXP C_zuh_node_attrs(SEXP ptr, SEXP ids);
SEXP C_zuh_node_text(SEXP ptr, SEXP ids, SEXP recursive);
SEXP C_zuh_node_serialize(SEXP ptr, SEXP ids, SEXP outer, SEXP pretty);
SEXP C_zuh_node_strings(SEXP ptr, SEXP ids);
SEXP C_zuh_select(SEXP ptr, SEXP ids, SEXP css, SEXP mode, SEXP work_limit);
SEXP C_zuh_text_clean(SEXP ptr, SEXP ids, SEXP opts);
SEXP C_zuh_markdown(SEXP ptr, SEXP ids, SEXP url_ids, SEXP urls);
SEXP C_zuh_outermost(SEXP ptr, SEXP ids);
SEXP C_zuh_table(SEXP ptr, SEXP id, SEXP max_cells);

#endif
