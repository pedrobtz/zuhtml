/* Vectorized node accessors over the frozen document. R-facing.
 *
 * Every entry takes the document's external pointer and an integer vector
 * of node IDs. It returns NULL (R's NULL) when the pointer is dead or not
 * a document, or when an ID is out of range; the R wrappers turn that into
 * zuhtml_pointer_error. NA_integer_ IDs are missing nodes: aligned results
 * carry NA for them, and set results skip them.
 *
 * These loops touch only the frozen document, which a long jump cannot
 * leak, and R_alloc memory, so they may be interrupted. */
#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Utils.h>

#include <limits.h>
#include <stdlib.h>
#include <string.h>

#include "zuh_document.h"
#include "zuh_r.h"
#include "zuh_write.h"

/* The document behind `ptr` if `ids` are all NA or in range. */
static const zuh_doc *
checked(SEXP ptr, SEXP ids) {
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

static void
poll(R_xlen_t i) {
  if ((i & 0xFFFF) == 0xFFFF)
    R_CheckUserInterrupt();
}

static SEXP
utf8(const char *s) {
  return Rf_mkCharCE(s, CE_UTF8);
}

static const char *
type_name(const zuh_doc *doc, zuh_id id) {
  switch (doc->nodes[id].type) {
  case ZUH_NODE_DOCUMENT:
    return doc->is_fragment ? "fragment" : "document";
  case ZUH_NODE_DOCTYPE:
    return "doctype";
  case ZUH_NODE_ELEMENT:
    return "element";
  case ZUH_NODE_TEXT:
    return "text";
  case ZUH_NODE_COMMENT:
    return "comment";
  case ZUH_NODE_PI:
    return "processing_instruction";
  default:
    return NULL;
  }
}

SEXP
C_zuh_node_type(SEXP ptr, SEXP ids) {
  const zuh_doc *doc = checked(ptr, ids);
  R_xlen_t i, n;
  SEXP out;
  if (doc == NULL)
    return R_NilValue;
  n = XLENGTH(ids);
  out = PROTECT(Rf_allocVector(STRSXP, n));
  for (i = 0; i < n; i++) {
    int id = INTEGER(ids)[i];
    const char *t = id == NA_INTEGER ? NULL : type_name(doc, (zuh_id) id);
    SET_STRING_ELT(out, i, t == NULL ? NA_STRING : utf8(t));
    poll(i);
  }
  UNPROTECT(1);
  return out;
}

/* Element and doctype names; NA for everything else. */
SEXP
C_zuh_node_name(SEXP ptr, SEXP ids) {
  const zuh_doc *doc = checked(ptr, ids);
  R_xlen_t i, n;
  SEXP out;
  if (doc == NULL)
    return R_NilValue;
  n = XLENGTH(ids);
  out = PROTECT(Rf_allocVector(STRSXP, n));
  for (i = 0; i < n; i++) {
    int id = INTEGER(ids)[i];
    const zuh_node *nd;
    if (id == NA_INTEGER) {
      SET_STRING_ELT(out, i, NA_STRING);
      continue;
    }
    nd = &doc->nodes[id];
    SET_STRING_ELT(out, i,
                   nd->type == ZUH_NODE_ELEMENT || nd->type == ZUH_NODE_DOCTYPE
                       ? utf8(zuh_str(doc, nd->name))
                       : NA_STRING);
    poll(i);
  }
  UNPROTECT(1);
  return out;
}

SEXP
C_zuh_node_namespace(SEXP ptr, SEXP ids) {
  static const char *const uris[] = {"http://www.w3.org/1999/xhtml",
                                     "http://www.w3.org/2000/svg",
                                     "http://www.w3.org/1998/Math/MathML"};
  const zuh_doc *doc = checked(ptr, ids);
  R_xlen_t i, n;
  SEXP out;
  if (doc == NULL)
    return R_NilValue;
  n = XLENGTH(ids);
  out = PROTECT(Rf_allocVector(STRSXP, n));
  for (i = 0; i < n; i++) {
    int id = INTEGER(ids)[i];
    const zuh_node *nd = id == NA_INTEGER ? NULL : &doc->nodes[id];
    SET_STRING_ELT(out, i,
                   nd != NULL && nd->type == ZUH_NODE_ELEMENT && nd->ns <= 2
                       ? utf8(uris[nd->ns])
                       : NA_STRING);
    poll(i);
  }
  UNPROTECT(1);
  return out;
}

/* Aligned: the parent of each node; NA for the document node and for
 * missing nodes. */
SEXP
C_zuh_node_parent(SEXP ptr, SEXP ids) {
  const zuh_doc *doc = checked(ptr, ids);
  R_xlen_t i, n;
  SEXP out;
  if (doc == NULL)
    return R_NilValue;
  n = XLENGTH(ids);
  out = PROTECT(Rf_allocVector(INTSXP, n));
  for (i = 0; i < n; i++) {
    int id = INTEGER(ids)[i];
    zuh_id p = id == NA_INTEGER ? ZUH_NONE : doc->nodes[id].parent;
    INTEGER(out)[i] = p == ZUH_NONE ? NA_INTEGER : (int) p;
    poll(i);
  }
  UNPROTECT(1);
  return out;
}

/* Aligned: the next (or previous) sibling of each node, optionally the
 * next element sibling. NA when there is none. */
SEXP
C_zuh_node_sibling(SEXP ptr, SEXP ids, SEXP next, SEXP elements_only) {
  const zuh_doc *doc = checked(ptr, ids);
  int fwd = Rf_asLogical(next) == TRUE;
  int elts = Rf_asLogical(elements_only) == TRUE;
  R_xlen_t i, n;
  SEXP out;
  if (doc == NULL)
    return R_NilValue;
  n = XLENGTH(ids);
  out = PROTECT(Rf_allocVector(INTSXP, n));
  for (i = 0; i < n; i++) {
    int id = INTEGER(ids)[i];
    zuh_id s = ZUH_NONE;
    if (id != NA_INTEGER) {
      s = fwd ? doc->nodes[id].next_sibling : doc->nodes[id].prev_sibling;
      while (elts && s != ZUH_NONE && doc->nodes[s].type != ZUH_NODE_ELEMENT)
        s = fwd ? doc->nodes[s].next_sibling : doc->nodes[s].prev_sibling;
    }
    INTEGER(out)[i] = s == ZUH_NONE ? NA_INTEGER : (int) s;
    poll(i);
  }
  UNPROTECT(1);
  return out;
}

/* Set: the children of every node, concatenated in input order. R sorts
 * and deduplicates. `templates_only` returns only the children of template
 * elements (their template contents). */
SEXP
C_zuh_node_children(SEXP ptr, SEXP ids, SEXP elements_only,
                    SEXP templates_only) {
  const zuh_doc *doc = checked(ptr, ids);
  int elts = Rf_asLogical(elements_only) == TRUE;
  int tmpl = Rf_asLogical(templates_only) == TRUE;
  R_xlen_t i, n, total = 0, k = 0;
  SEXP out;
  if (doc == NULL)
    return R_NilValue;
  n = XLENGTH(ids);
  for (i = 0; i < n; i++) {
    int id = INTEGER(ids)[i];
    zuh_id c;
    if (id == NA_INTEGER ||
        (tmpl && (doc->nodes[id].flags & ZUH_FLAG_TEMPLATE) == 0))
      continue;
    for (c = doc->nodes[id].first_child; c != ZUH_NONE;
         c = doc->nodes[c].next_sibling)
      if (!elts || doc->nodes[c].type == ZUH_NODE_ELEMENT)
        total++;
    poll(i);
  }
  out = PROTECT(Rf_allocVector(INTSXP, total));
  for (i = 0; i < n; i++) {
    int id = INTEGER(ids)[i];
    zuh_id c;
    if (id == NA_INTEGER ||
        (tmpl && (doc->nodes[id].flags & ZUH_FLAG_TEMPLATE) == 0))
      continue;
    for (c = doc->nodes[id].first_child; c != ZUH_NONE;
         c = doc->nodes[c].next_sibling)
      if (!elts || doc->nodes[c].type == ZUH_NODE_ELEMENT)
        INTEGER(out)[k++] = (int) c;
  }
  UNPROTECT(1);
  return out;
}

/* Set: every ancestor of every node, excluding the document node. R sorts
 * and deduplicates. */
SEXP
C_zuh_node_ancestors(SEXP ptr, SEXP ids) {
  const zuh_doc *doc = checked(ptr, ids);
  R_xlen_t i, n, total = 0, k = 0;
  SEXP out;
  if (doc == NULL)
    return R_NilValue;
  n = XLENGTH(ids);
  for (i = 0; i < n; i++) {
    int id = INTEGER(ids)[i];
    zuh_id p;
    if (id == NA_INTEGER)
      continue;
    for (p = doc->nodes[id].parent; p != ZUH_NONE && p != 0;
         p = doc->nodes[p].parent)
      total++;
    poll(i);
  }
  out = PROTECT(Rf_allocVector(INTSXP, total));
  for (i = 0; i < n; i++) {
    int id = INTEGER(ids)[i];
    zuh_id p;
    if (id == NA_INTEGER)
      continue;
    for (p = doc->nodes[id].parent; p != ZUH_NONE && p != 0;
         p = doc->nodes[p].parent)
      INTEGER(out)[k++] = (int) p;
  }
  UNPROTECT(1);
  return out;
}

/* Does attribute `a` match the requested name? HTML attribute names are
 * stored lowercase, so the request is compared ASCII-case-insensitively
 * on HTML elements and exactly on foreign ones, as the DOM's getAttribute
 * does. "xlink:href" and the like name a namespaced attribute. */
static int
attr_matches(const zuh_doc *doc, const zuh_node *nd, const zuh_attr *a,
             const char *want, uint8_t want_ns) {
  const char *have = zuh_str(doc, a->name);
  if (a->ns != want_ns)
    return 0;
  if (nd->ns == ZUH_NS_HTML) {
    for (; *have != '\0' && *want != '\0'; have++, want++) {
      char w = *want;
      if (w >= 'A' && w <= 'Z')
        w = (char) (w - 'A' + 'a');
      if (*have != w)
        return 0;
    }
    return *have == '\0' && *want == '\0';
  }
  return strcmp(have, want) == 0;
}

static const char *
split_attr_name(const char *name, uint8_t *ns) {
  static const struct {
    const char *prefix;
    uint8_t ns;
  } prefixes[] = {{"xlink:", ZUH_ATTR_NS_XLINK},
                  {"xml:", ZUH_ATTR_NS_XML},
                  {"xmlns:", ZUH_ATTR_NS_XMLNS}};
  size_t i;
  for (i = 0; i < sizeof(prefixes) / sizeof(prefixes[0]); i++) {
    size_t lp = strlen(prefixes[i].prefix);
    if (strncmp(name, prefixes[i].prefix, lp) == 0) {
      *ns = prefixes[i].ns;
      return name + lp;
    }
  }
  /* A bare "xmlns" is itself in the XMLNS namespace in foreign content;
   * in HTML it is an ordinary attribute. Match it as stored. */
  *ns = ZUH_ATTR_NS_NONE;
  return name;
}

/* Aligned: the value of attribute `name` on each node; `dflt` where the
 * node has no such attribute (or is not an element), NA for missing
 * nodes. */
SEXP
C_zuh_node_attr(SEXP ptr, SEXP ids, SEXP name, SEXP dflt) {
  const zuh_doc *doc = checked(ptr, ids);
  const char *want;
  uint8_t want_ns;
  R_xlen_t i, n;
  SEXP out, d;
  if (doc == NULL)
    return R_NilValue;
  want = split_attr_name(Rf_translateCharUTF8(STRING_ELT(name, 0)), &want_ns);
  d = STRING_ELT(dflt, 0);
  n = XLENGTH(ids);
  out = PROTECT(Rf_allocVector(STRSXP, n));
  for (i = 0; i < n; i++) {
    int id = INTEGER(ids)[i];
    const zuh_node *nd;
    SEXP v = d;
    uint32_t j;
    if (id == NA_INTEGER) {
      SET_STRING_ELT(out, i, NA_STRING);
      continue;
    }
    nd = &doc->nodes[id];
    if (nd->type == ZUH_NODE_ELEMENT) {
      for (j = 0; j < nd->attr_count; j++) {
        const zuh_attr *a = &doc->attrs[nd->attr_start + j];
        if (attr_matches(doc, nd, a, want, want_ns)) {
          v = utf8(zuh_str(doc, a->value));
          break;
        }
      }
    }
    SET_STRING_ELT(out, i, v);
    poll(i);
  }
  UNPROTECT(1);
  return out;
}

static const char *
attr_prefix(uint8_t ns) {
  switch (ns) {
  case ZUH_ATTR_NS_XLINK:
    return "xlink:";
  case ZUH_ATTR_NS_XML:
    return "xml:";
  case ZUH_ATTR_NS_XMLNS:
    return "xmlns:";
  default:
    return "";
  }
}

/* A list: one named character vector of attributes per node, in source
 * order; NA_character_ for a missing node. */
SEXP
C_zuh_node_attrs(SEXP ptr, SEXP ids) {
  const zuh_doc *doc = checked(ptr, ids);
  R_xlen_t i, n;
  SEXP out;
  if (doc == NULL)
    return R_NilValue;
  n = XLENGTH(ids);
  out = PROTECT(Rf_allocVector(VECSXP, n));
  for (i = 0; i < n; i++) {
    int id = INTEGER(ids)[i];
    const zuh_node *nd;
    uint32_t j, k;
    SEXP vals, nms;
    if (id == NA_INTEGER) {
      SET_VECTOR_ELT(out, i, Rf_ScalarString(NA_STRING));
      continue;
    }
    nd = &doc->nodes[id];
    k = nd->type == ZUH_NODE_ELEMENT ? nd->attr_count : 0;
    vals = PROTECT(Rf_allocVector(STRSXP, k));
    nms = PROTECT(Rf_allocVector(STRSXP, k));
    for (j = 0; j < k; j++) {
      const zuh_attr *a = &doc->attrs[nd->attr_start + j];
      const char *p = attr_prefix(a->ns);
      const char *nm = zuh_str(doc, a->name);
      SET_STRING_ELT(vals, j, utf8(zuh_str(doc, a->value)));
      if (*p == '\0') {
        SET_STRING_ELT(nms, j, utf8(nm));
      } else {
        size_t lp = strlen(p), ln = strlen(nm);
        char *buf = R_alloc(lp + ln + 1, 1);
        memcpy(buf, p, lp);
        memcpy(buf + lp, nm, ln + 1);
        SET_STRING_ELT(nms, j, utf8(buf));
      }
    }
    Rf_setAttrib(vals, R_NamesSymbol, nms);
    SET_VECTOR_ELT(out, i, vals);
    UNPROTECT(2);
    poll(i);
  }
  UNPROTECT(1);
  return out;
}

/* Text of one node. Recursive: every text node in its subtree, in tree
 * order, skipping template contents. Otherwise its direct text children.
 * A text, comment or PI node is its own content; a doctype has none. */
static SEXP
node_text(const zuh_doc *doc, zuh_id id, int recursive) {
  const zuh_node *nd = &doc->nodes[id];
  size_t len = 0, pos = 0;
  zuh_id c, end = 0;
  char *buf;

  if (nd->type == ZUH_NODE_TEXT || nd->type == ZUH_NODE_COMMENT ||
      nd->type == ZUH_NODE_PI)
    return utf8(zuh_str(doc, nd->value));
  if (nd->type == ZUH_NODE_DOCTYPE)
    return NA_STRING;
  if ((nd->flags & ZUH_FLAG_TEMPLATE) != 0)
    return utf8("");

  /* Two passes: measure, then copy into R_alloc memory. */
  if (recursive) {
    end = nd->subtree_end;
    for (c = id + 1; c <= end; c++) {
      const zuh_node *k = &doc->nodes[c];
      if (k->type == ZUH_NODE_TEXT)
        len += strlen(zuh_str(doc, k->value));
      else if ((k->flags & ZUH_FLAG_TEMPLATE) != 0)
        c = k->subtree_end;
    }
  } else {
    for (c = nd->first_child; c != ZUH_NONE; c = doc->nodes[c].next_sibling)
      if (doc->nodes[c].type == ZUH_NODE_TEXT)
        len += strlen(zuh_str(doc, doc->nodes[c].value));
  }
  if (len > (size_t) INT_MAX)
    Rf_error("text too long for an R string");
  buf = R_alloc(len + 1, 1);
  if (recursive) {
    for (c = id + 1; c <= end; c++) {
      const zuh_node *k = &doc->nodes[c];
      if (k->type == ZUH_NODE_TEXT) {
        const char *t = zuh_str(doc, k->value);
        size_t l = strlen(t);
        memcpy(buf + pos, t, l);
        pos += l;
      } else if ((k->flags & ZUH_FLAG_TEMPLATE) != 0) {
        c = k->subtree_end;
      }
    }
  } else {
    for (c = nd->first_child; c != ZUH_NONE; c = doc->nodes[c].next_sibling)
      if (doc->nodes[c].type == ZUH_NODE_TEXT) {
        const char *t = zuh_str(doc, doc->nodes[c].value);
        size_t l = strlen(t);
        memcpy(buf + pos, t, l);
        pos += l;
      }
  }
  buf[pos] = '\0';
  return Rf_mkCharLenCE(buf, (int) pos, CE_UTF8);
}

SEXP
C_zuh_node_text(SEXP ptr, SEXP ids, SEXP recursive) {
  const zuh_doc *doc = checked(ptr, ids);
  int rec = Rf_asLogical(recursive) == TRUE;
  R_xlen_t i, n;
  SEXP out;
  if (doc == NULL)
    return R_NilValue;
  n = XLENGTH(ids);
  out = PROTECT(Rf_allocVector(STRSXP, n));
  for (i = 0; i < n; i++) {
    int id = INTEGER(ids)[i];
    const void *vmax = vmaxget();
    SET_STRING_ELT(out, i,
                   id == NA_INTEGER ? NA_STRING : node_text(doc, (zuh_id) id, rec));
    vmaxset(vmax);
    poll(i);
  }
  UNPROTECT(1);
  return out;
}

void *
zuh_r_alloc(void *userdata, size_t n) {
  (void) userdata;
  return R_alloc(n, 1);
}

/* Aligned: the HTML serialization of each node, NA for missing nodes. */
SEXP
C_zuh_node_serialize(SEXP ptr, SEXP ids, SEXP outer) {
  const zuh_doc *doc = checked(ptr, ids);
  int out_ = Rf_asLogical(outer) == TRUE;
  R_xlen_t i, n;
  SEXP out;
  if (doc == NULL)
    return R_NilValue;
  n = XLENGTH(ids);
  out = PROTECT(Rf_allocVector(STRSXP, n));
  for (i = 0; i < n; i++) {
    int id = INTEGER(ids)[i];
    const void *vmax = vmaxget();
    zuh_buf b;
    if (id == NA_INTEGER) {
      SET_STRING_ELT(out, i, NA_STRING);
      continue;
    }
    /* R_alloc-backed: an allocation failure long-jumps with nothing to
     * free. */
    zuh_buf_init(&b, zuh_r_alloc, NULL);
    if (zuh_serialize(doc, (zuh_id) id, out_, &b) != ZUH_OK)
      Rf_error("out of memory serializing a node");
    if (b.len > (size_t) INT_MAX)
      Rf_error("serialization too long for an R string");
    SET_STRING_ELT(out, i, Rf_mkCharLenCE(b.buf, (int) b.len, CE_UTF8));
    vmaxset(vmax);
    R_CheckUserInterrupt();
  }
  UNPROTECT(1);
  return out;
}
