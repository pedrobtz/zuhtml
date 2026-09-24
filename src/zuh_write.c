/* HTML serialization. See zuh_write.h and
 * https://html.spec.whatwg.org/multipage/parsing.html#serialising-html-fragments
 *
 * Iterative: the traversal follows the tree's parent and sibling links, so
 * depth costs no C stack. */
#include <stdlib.h>
#include <string.h>

#include "zuh_write.h"

typedef struct {
  char *buf;
  size_t len;
  size_t cap;
  int failed;
} wbuf;

static void
put(wbuf *w, const char *s, size_t n) {
  if (w->failed || n == 0)
    return;
  if (n > (size_t) -1 - w->len - 1) {
    w->failed = 1;
    return;
  }
  if (w->len + n + 1 > w->cap) {
    size_t cap = w->cap ? w->cap : 1024;
    char *grown;
    while (cap < w->len + n + 1) {
      if (cap > (size_t) -1 / 2) {
        w->failed = 1;
        return;
      }
      cap *= 2;
    }
    grown = (char *) realloc(w->buf, cap);
    if (grown == NULL) {
      w->failed = 1;
      return;
    }
    w->buf = grown;
    w->cap = cap;
  }
  memcpy(w->buf + w->len, s, n);
  w->len += n;
  w->buf[w->len] = '\0';
}

static void
puts_(wbuf *w, const char *s) {
  put(w, s, strlen(s));
}

/* Escape per "escaping a string": & and U+00A0 always; in attribute mode
 * also ", and < and > (added to the spec in 2025); otherwise < and >. */
static void
put_escaped(wbuf *w, const char *s, int attr) {
  const char *run = s;
  const unsigned char *p = (const unsigned char *) s;
  while (*p != '\0') {
    const char *rep = NULL;
    size_t skip = 1;
    switch (*p) {
    case '&':
      rep = "&amp;";
      break;
    case '<':
      rep = "&lt;";
      break;
    case '>':
      rep = "&gt;";
      break;
    case '"':
      if (attr)
        rep = "&quot;";
      break;
    case 0xC2:
      if (p[1] == 0xA0) {
        rep = "&nbsp;";
        skip = 2;
      }
      break;
    default:
      break;
    }
    if (rep != NULL) {
      put(w, run, (size_t) ((const char *) p - run));
      puts_(w, rep);
      p += skip;
      run = (const char *) p;
    } else {
      p++;
    }
  }
  put(w, run, (size_t) ((const char *) p - run));
}

static int
is_html_element(const zuh_node *n) {
  return n->type == ZUH_NODE_ELEMENT && n->ns == ZUH_NS_HTML;
}

static int
name_in(const char *name, const char *const *list) {
  for (; *list != NULL; list++)
    if (strcmp(name, *list) == 0)
      return 1;
  return 0;
}

static const char *const void_elements[] = {
  "area", "base", "basefont", "bgsound", "br", "col", "embed", "frame",
  "hr", "img", "input", "keygen", "link", "meta", "param", "source",
  "track", "wbr", NULL};

/* Text children of these are emitted literally. noscript is not listed:
 * the bundled parser runs with scripting disabled, and the spec lists it
 * only when scripting is enabled. */
static const char *const raw_text_parents[] = {
  "style", "script", "xmp", "iframe", "noembed", "noframes", "plaintext",
  NULL};

static int
is_void(const zuh_doc *doc, const zuh_node *n) {
  return is_html_element(n) && name_in(zuh_str(doc, n->name), void_elements);
}

static void
put_attr_name(wbuf *w, const zuh_doc *doc, const zuh_attr *a) {
  const char *nm = zuh_str(doc, a->name);
  switch (a->ns) {
  case ZUH_ATTR_NS_XML:
    puts_(w, "xml:");
    break;
  case ZUH_ATTR_NS_XLINK:
    puts_(w, "xlink:");
    break;
  case ZUH_ATTR_NS_XMLNS:
    if (strcmp(nm, "xmlns") != 0)
      puts_(w, "xmlns:");
    break;
  default:
    break;
  }
  puts_(w, nm);
}

static void
open_node(wbuf *w, const zuh_doc *doc, zuh_id id) {
  const zuh_node *n = &doc->nodes[id];
  switch (n->type) {
  case ZUH_NODE_ELEMENT: {
    uint32_t i;
    put(w, "<", 1);
    puts_(w, zuh_str(doc, n->name));
    for (i = 0; i < n->attr_count; i++) {
      const zuh_attr *a = &doc->attrs[n->attr_start + i];
      put(w, " ", 1);
      put_attr_name(w, doc, a);
      put(w, "=\"", 2);
      put_escaped(w, zuh_str(doc, a->value), 1);
      put(w, "\"", 1);
    }
    put(w, ">", 1);
    break;
  }
  case ZUH_NODE_TEXT: {
    const zuh_node *p =
        n->parent != ZUH_NONE ? &doc->nodes[n->parent] : NULL;
    /* In a fragment, the parent of a top-level node is the context
     * element. */
    const char *parent_name =
        p == NULL ? NULL
        : is_html_element(p) ? zuh_str(doc, p->name)
        : (n->parent == 0 && doc->is_fragment) ? doc->context
        : NULL;
    if (parent_name != NULL && name_in(parent_name, raw_text_parents))
      puts_(w, zuh_str(doc, n->value));
    else
      put_escaped(w, zuh_str(doc, n->value), 0);
    break;
  }
  case ZUH_NODE_COMMENT:
    puts_(w, "<!--");
    puts_(w, zuh_str(doc, n->value));
    puts_(w, "-->");
    break;
  case ZUH_NODE_PI:
    puts_(w, "<?");
    puts_(w, zuh_str(doc, n->value));
    puts_(w, "?>");
    break;
  case ZUH_NODE_DOCTYPE:
    puts_(w, "<!DOCTYPE ");
    puts_(w, zuh_str(doc, n->name));
    put(w, ">", 1);
    break;
  default:
    break;
  }
}

static void
close_node(wbuf *w, const zuh_doc *doc, zuh_id id) {
  const zuh_node *n = &doc->nodes[id];
  if (n->type != ZUH_NODE_ELEMENT || is_void(doc, n))
    return;
  put(w, "</", 2);
  puts_(w, zuh_str(doc, n->name));
  put(w, ">", 1);
}

/* Serialize the subtree of `top`, including `top` itself when
 * `include_top`. A void element's children, if the tree somehow had any,
 * are not serialized, as the spec says. */
static void
serialize_subtree(wbuf *w, const zuh_doc *doc, zuh_id top, int include_top) {
  zuh_id id;
  if (include_top) {
    open_node(w, doc, top);
    if (is_void(doc, &doc->nodes[top]))
      return;
  }
  id = doc->nodes[top].first_child;
  while (id != ZUH_NONE && !w->failed) {
    const zuh_node *n = &doc->nodes[id];
    open_node(w, doc, id);
    if (n->first_child != ZUH_NONE && !is_void(doc, n)) {
      id = n->first_child;
      continue;
    }
    close_node(w, doc, id);
    /* Climb, closing each ancestor, until one has a next sibling. */
    while (doc->nodes[id].next_sibling == ZUH_NONE) {
      id = doc->nodes[id].parent;
      if (id == top || id == ZUH_NONE) {
        id = ZUH_NONE;
        break;
      }
      close_node(w, doc, id);
    }
    if (id != ZUH_NONE)
      id = doc->nodes[id].next_sibling;
  }
  if (include_top)
    close_node(w, doc, top);
}

zuh_status
zuh_serialize(const zuh_doc *doc, zuh_id id, int outer, char **out,
              size_t *len) {
  wbuf w = {NULL, 0, 0, 0};
  *out = NULL;
  *len = 0;
  put(&w, "", 0);
  if (w.buf == NULL) {
    w.buf = (char *) malloc(1);
    if (w.buf == NULL)
      return ZUH_LIMIT_MEMORY;
    w.buf[0] = '\0';
    w.cap = 1;
  }
  if (id < doc->n_nodes) {
    const zuh_node *n = &doc->nodes[id];
    serialize_subtree(&w, doc, id,
                      outer && n->type != ZUH_NODE_DOCUMENT);
  }
  if (w.failed) {
    free(w.buf);
    return ZUH_LIMIT_MEMORY;
  }
  *out = w.buf;
  *len = w.len;
  return ZUH_OK;
}
