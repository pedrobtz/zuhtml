/* HTML serialization. See zuh_write.h and
 * https://html.spec.whatwg.org/multipage/parsing.html#serialising-html-fragments
 *
 * Iterative: the traversal follows the tree's parent and sibling links, so
 * depth costs no C stack. */
#include <stdlib.h>
#include <string.h>

#include "zuh_write.h"

typedef zuh_buf wbuf;

static void
put(wbuf *w, const char *s, size_t n) {
  zuh_buf_put(w, s, n);
}

static void
puts_(wbuf *w, const char *s) {
  zuh_buf_str(w, s);
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

/* ---- pretty printing ------------------------------------------------
 *
 * Block-level elements start on their own line, indented two spaces per
 * level, and an element holding block-level children closes on its own
 * line too. Inline content stays on its line. Whitespace-only text in an
 * element laid out this way is dropped, since the layout replaces it. Inside elements whose
 * whitespace matters (pre, textarea, listing, plaintext) and raw-text
 * elements, nothing is changed. This is for reading, never a round trip. */

/* Sorted, for bsearch. */
static const char *const pretty_blocks[] = {
  "address", "article", "aside", "base", "blockquote", "body", "caption",
  "col", "colgroup", "dd", "details", "dialog", "div", "dl", "dt",
  "fieldset", "figcaption", "figure", "footer", "form", "h1", "h2", "h3",
  "h4", "h5", "h6", "head", "header", "hgroup", "hr", "html", "legend",
  "li", "link", "main", "menu", "meta", "nav", "noscript", "ol",
  "optgroup", "option", "p", "pre", "script", "section", "style",
  "summary", "table", "tbody", "td", "template", "tfoot", "th", "thead",
  "title", "tr", "ul"};

/* Their contents are left exactly as they are. */
static const char *const keep_whitespace[] = {
  "iframe", "listing", "noembed", "noframes", "plaintext", "pre", "script",
  "style", "textarea", "xmp"};

static int
cmp_name(const void *key, const void *elt) {
  return strcmp((const char *) key, *(const char *const *) elt);
}

static int
in_sorted(const zuh_doc *doc, const zuh_node *n, const char *const *list,
          size_t len) {
  return is_html_element(n) &&
         bsearch(zuh_str(doc, n->name), list, len, sizeof(list[0]),
                 cmp_name) != NULL;
}

static int
is_pretty_block(const zuh_doc *doc, const zuh_node *n) {
  return in_sorted(doc, n, pretty_blocks,
                   sizeof(pretty_blocks) / sizeof(pretty_blocks[0]));
}

static int
keeps_whitespace(const zuh_doc *doc, const zuh_node *n) {
  return in_sorted(doc, n, keep_whitespace,
                   sizeof(keep_whitespace) / sizeof(keep_whitespace[0]));
}

static int
has_block_child(const zuh_doc *doc, const zuh_node *n) {
  zuh_id c;
  for (c = n->first_child; c != ZUH_NONE; c = doc->nodes[c].next_sibling)
    if (is_pretty_block(doc, &doc->nodes[c]))
      return 1;
  return 0;
}

static int
whitespace_only(const char *s) {
  for (; *s; s++)
    if (*s != ' ' && *s != '\t' && *s != '\n' && *s != '\r' && *s != '\f')
      return 0;
  return 1;
}

typedef struct {
  int pretty;
  unsigned depth; /* elements open within the serialized subtree */
  unsigned kept;  /* open elements whose whitespace is kept */
} layout;

static void
newline(wbuf *w, unsigned depth) {
  unsigned i;
  if (w->len == 0)
    return;
  put(w, "\n", 1);
  for (i = 0; i < depth; i++)
    put(w, "  ", 2);
}

/* Emit node `id`'s opening markup, with layout. Returns 0 when the node
 * is skipped (whitespace-only text the layout replaces). */
static int
open_laid_out(wbuf *w, const zuh_doc *doc, zuh_id id, layout *l) {
  const zuh_node *n = &doc->nodes[id];
  if (l->pretty && l->kept == 0) {
    if (n->type == ZUH_NODE_TEXT && whitespace_only(zuh_str(doc, n->value))) {
      /* Only where the parent is laid out on lines, because it has
       * block-level children: a space between inline elements stays. */
      const zuh_node *p =
          n->parent != ZUH_NONE ? &doc->nodes[n->parent] : NULL;
      if (p == NULL || p->type == ZUH_NODE_DOCUMENT || has_block_child(doc, p))
        return 0;
    }
    if (is_pretty_block(doc, n) || n->type == ZUH_NODE_DOCTYPE)
      newline(w, l->depth);
    else if (n->type == ZUH_NODE_COMMENT) {
      /* A comment between blocks gets a line; one inside text stays. */
      const zuh_node *p =
          n->parent != ZUH_NONE ? &doc->nodes[n->parent] : NULL;
      if (p == NULL || p->type == ZUH_NODE_DOCUMENT || is_pretty_block(doc, p))
        newline(w, l->depth);
    }
  }
  open_node(w, doc, id);
  return 1;
}

static void
close_laid_out(wbuf *w, const zuh_doc *doc, zuh_id id, layout *l) {
  const zuh_node *n = &doc->nodes[id];
  if (l->pretty && l->kept == 0 && is_pretty_block(doc, n) &&
      !is_void(doc, n) && has_block_child(doc, n))
    newline(w, l->depth);
  close_node(w, doc, id);
}

/* Descend into `id`'s children. */
static void
enter(const zuh_doc *doc, zuh_id id, layout *l) {
  l->depth++;
  if (keeps_whitespace(doc, &doc->nodes[id]))
    l->kept++;
}

/* Climb out of `id`, before closing it. */
static void
leave(const zuh_doc *doc, zuh_id id, layout *l) {
  l->depth--;
  if (keeps_whitespace(doc, &doc->nodes[id]))
    l->kept--;
}

/* Serialize the subtree of `top`, including `top` itself when
 * `include_top`. A void element's children, if the tree somehow had any,
 * are not serialized, as the spec says. */
static void
serialize_subtree(wbuf *w, const zuh_doc *doc, zuh_id top, int include_top,
                  int pretty) {
  layout l = {0, 0, 0};
  zuh_id id;
  l.pretty = pretty;
  if (include_top) {
    open_laid_out(w, doc, top, &l);
    if (is_void(doc, &doc->nodes[top]))
      return;
    enter(doc, top, &l);
  }
  id = doc->nodes[top].first_child;
  while (id != ZUH_NONE && !w->failed) {
    const zuh_node *n = &doc->nodes[id];
    int shown = open_laid_out(w, doc, id, &l);
    if (shown && n->first_child != ZUH_NONE && !is_void(doc, n)) {
      enter(doc, id, &l);
      id = n->first_child;
      continue;
    }
    if (shown)
      close_laid_out(w, doc, id, &l);
    /* Climb, closing each ancestor, until one has a next sibling. */
    while (doc->nodes[id].next_sibling == ZUH_NONE) {
      id = doc->nodes[id].parent;
      if (id == top || id == ZUH_NONE) {
        id = ZUH_NONE;
        break;
      }
      leave(doc, id, &l);
      close_laid_out(w, doc, id, &l);
    }
    if (id != ZUH_NONE)
      id = doc->nodes[id].next_sibling;
  }
  if (include_top) {
    leave(doc, top, &l);
    close_laid_out(w, doc, top, &l);
  }
}

zuh_status
zuh_serialize(const zuh_doc *doc, zuh_id id, int outer, int pretty,
              zuh_buf *out) {
  if (id < doc->n_nodes) {
    const zuh_node *n = &doc->nodes[id];
    serialize_subtree(out, doc, id, outer && n->type != ZUH_NODE_DOCUMENT,
                      pretty);
  }
  return out->failed ? ZUH_LIMIT_MEMORY : ZUH_OK;
}
