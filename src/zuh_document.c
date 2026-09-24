/* The frozen document. See zuh_document.h. */
#include <stdlib.h>
#include <string.h>

#include "zuh_document.h"

zuh_doc *
zuh_doc_new(void) {
  zuh_doc *doc = (zuh_doc *) calloc(1, sizeof(zuh_doc));
  if (doc != NULL)
    doc->root = ZUH_NONE;
  return doc;
}

void
zuh_doc_free(zuh_doc *doc) {
  if (doc == NULL)
    return;
  free(doc->nodes);
  free(doc->attrs);
  free(doc->pool);
  free(doc->problems);
  free(doc);
}

/* ---- tree dump in the html5lib test format ---------------------------- */

typedef struct {
  char *buf;
  size_t len;
  size_t cap;
  int failed;
} sbuf;

static void
sb_put(sbuf *sb, const char *s, size_t n) {
  if (sb->failed)
    return;
  if (n > (size_t) -1 - sb->len - 1) {
    sb->failed = 1;
    return;
  }
  if (sb->len + n + 1 > sb->cap) {
    size_t cap = sb->cap ? sb->cap : 256;
    char *grown;
    while (cap < sb->len + n + 1) {
      if (cap > (size_t) -1 / 2) {
        sb->failed = 1;
        return;
      }
      cap *= 2;
    }
    grown = (char *) realloc(sb->buf, cap);
    if (grown == NULL) {
      sb->failed = 1;
      return;
    }
    sb->buf = grown;
    sb->cap = cap;
  }
  memcpy(sb->buf + sb->len, s, n);
  sb->len += n;
  sb->buf[sb->len] = '\0';
}

static void
sb_str(sbuf *sb, const char *s) {
  sb_put(sb, s, strlen(s));
}

static void
sb_indent(sbuf *sb, size_t depth) {
  size_t i;
  sb_put(sb, "| ", 2);
  for (i = 0; i < depth; i++)
    sb_put(sb, "  ", 2);
}

static const char *
attr_prefix(uint8_t ns) {
  switch (ns) {
  case ZUH_ATTR_NS_XLINK:
    return "xlink ";
  case ZUH_ATTR_NS_XML:
    return "xml ";
  case ZUH_ATTR_NS_XMLNS:
    return "xmlns ";
  default:
    return "";
  }
}

static int
cmp_lines(const void *a, const void *b) {
  return strcmp(*(const char *const *) a, *(const char *const *) b);
}

/* The attribute lines of one element, sorted by byte value as the fixtures
 * are, each on its own indented line. */
static void
dump_attrs(sbuf *sb, const zuh_doc *doc, const zuh_node *n, size_t depth) {
  char **lines;
  uint32_t i;
  if (n->attr_count == 0 || sb->failed)
    return;
  lines = (char **) calloc(n->attr_count, sizeof(char *));
  if (lines == NULL) {
    sb->failed = 1;
    return;
  }
  for (i = 0; i < n->attr_count; i++) {
    const zuh_attr *a = &doc->attrs[n->attr_start + i];
    const char *p = attr_prefix(a->ns);
    const char *nm = zuh_str(doc, a->name);
    const char *v = zuh_str(doc, a->value);
    size_t lp = strlen(p), ln = strlen(nm), lv = strlen(v);
    char *line = (char *) malloc(lp + ln + lv + 4);
    if (line == NULL) {
      sb->failed = 1;
      break;
    }
    memcpy(line, p, lp);
    memcpy(line + lp, nm, ln);
    memcpy(line + lp + ln, "=\"", 2);
    memcpy(line + lp + ln + 2, v, lv);
    line[lp + ln + 2 + lv] = '"';
    line[lp + ln + 3 + lv] = '\0';
    lines[i] = line;
  }
  if (!sb->failed) {
    qsort(lines, n->attr_count, sizeof(char *), cmp_lines);
    for (i = 0; i < n->attr_count; i++) {
      sb_indent(sb, depth);
      sb_str(sb, lines[i]);
      sb_put(sb, "\n", 1);
    }
  }
  for (i = 0; i < n->attr_count; i++)
    free(lines[i]);
  free(lines);
}

static void
dump_node(sbuf *sb, const zuh_doc *doc, const zuh_node *n, size_t depth) {
  switch (n->type) {
  case ZUH_NODE_DOCTYPE:
    sb_str(sb, "| <!DOCTYPE ");
    sb_str(sb, zuh_str(doc, n->name));
    if (doc->doctype_public != 0 || doc->doctype_system != 0) {
      sb_str(sb, " \"");
      sb_str(sb, zuh_str(doc, doc->doctype_public));
      sb_str(sb, "\" \"");
      sb_str(sb, zuh_str(doc, doc->doctype_system));
      sb_str(sb, "\"");
    }
    sb_str(sb, ">\n");
    break;
  case ZUH_NODE_ELEMENT:
    sb_indent(sb, depth);
    sb_put(sb, "<", 1);
    if (n->ns == ZUH_NS_SVG)
      sb_str(sb, "svg ");
    else if (n->ns == ZUH_NS_MATHML)
      sb_str(sb, "math ");
    sb_str(sb, zuh_str(doc, n->name));
    sb_put(sb, ">\n", 2);
    dump_attrs(sb, doc, n, depth + 1);
    if ((n->flags & ZUH_FLAG_TEMPLATE) != 0) {
      sb_indent(sb, depth + 1);
      sb_str(sb, "content\n");
    }
    break;
  case ZUH_NODE_TEXT:
    sb_indent(sb, depth);
    sb_put(sb, "\"", 1);
    sb_str(sb, zuh_str(doc, n->value));
    sb_put(sb, "\"\n", 2);
    break;
  case ZUH_NODE_COMMENT:
    sb_indent(sb, depth);
    sb_str(sb, "<!-- ");
    sb_str(sb, zuh_str(doc, n->value));
    sb_str(sb, " -->\n");
    break;
  case ZUH_NODE_PI:
    sb_indent(sb, depth);
    sb_str(sb, "<?");
    sb_str(sb, zuh_str(doc, n->value));
    sb_str(sb, "?>\n");
    break;
  default:
    break;
  }
}

zuh_status
zuh_doc_dump(const zuh_doc *doc, char **out, size_t *len) {
  sbuf sb = {NULL, 0, 0, 0};
  zuh_id id;
  size_t depth = 0;

  *out = NULL;
  *len = 0;
  sb_put(&sb, "", 0);
  if (doc->n_nodes == 0)
    goto done;

  /* Preorder over the links; no stack. `depth` is the printed depth of the
   * node being visited: children of the document are at 0, and children of
   * a template are one deeper, under its "content" line. */
  id = doc->nodes[0].first_child;
  while (id != ZUH_NONE && !sb.failed) {
    const zuh_node *n = &doc->nodes[id];
    dump_node(&sb, doc, n, depth);
    if (n->first_child != ZUH_NONE) {
      depth += (n->flags & ZUH_FLAG_TEMPLATE) ? 2 : 1;
      id = n->first_child;
      continue;
    }
    /* Climb until a node with a next sibling, or back at the document. */
    while (id != ZUH_NONE && doc->nodes[id].next_sibling == ZUH_NONE) {
      id = doc->nodes[id].parent;
      if (id == 0 || id == ZUH_NONE) {
        id = ZUH_NONE;
        break;
      }
      depth -= (doc->nodes[id].flags & ZUH_FLAG_TEMPLATE) ? 2 : 1;
    }
    if (id != ZUH_NONE)
      id = doc->nodes[id].next_sibling;
  }

done:
  if (sb.failed) {
    free(sb.buf);
    return ZUH_LIMIT_MEMORY;
  }
  *out = sb.buf;
  *len = sb.len;
  return ZUH_OK;
}
