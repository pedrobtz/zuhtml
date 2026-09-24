/* See zuh_text.h. One iterative walk over the subtree, with enter and exit
 * events from the tree links; no C stack per level. */
#include <stdlib.h>
#include <string.h>

#include "zuh_text.h"

/* Block-level elements: a line break before and after. Sorted, for
 * bsearch. */
static const char *const block_tags[] = {
  "address", "article", "aside", "blockquote", "body", "caption",
  "center", "dd", "details", "dialog", "dir", "div", "dl", "dt",
  "fieldset", "figcaption", "figure", "footer", "form", "h1", "h2", "h3",
  "h4", "h5", "h6", "head", "header", "hgroup", "hr", "html", "legend",
  "li", "listing", "main", "menu", "nav", "ol", "optgroup", "option", "p",
  "plaintext", "pre", "section", "summary", "table", "tbody", "tfoot",
  "thead", "title", "tr", "ul", "xmp"};

static int
cmp_name(const void *key, const void *elt) {
  return strcmp((const char *) key, *(const char *const *) elt);
}

static int
in_list(const char *name, const char *const *list, size_t n) {
  return bsearch(name, list, n, sizeof(list[0]), cmp_name) != NULL;
}

/* K_SKIP_BLOCK: skipped, but still a block boundary where it stood (a
 * nested list or table left out of an item's or a cell's text). */
enum { K_OTHER = 0, K_SKIP, K_SKIP_BLOCK, K_BLOCK, K_CELL, K_BR, K_PRE };

static int
kind_of(const zuh_doc *doc, zuh_id id, zuh_id root,
        const zuh_clean_opts *o) {
  const zuh_node *n = &doc->nodes[id];
  const char *name;
  if (n->type == ZUH_NODE_COMMENT || n->type == ZUH_NODE_PI ||
      n->type == ZUH_NODE_DOCTYPE)
    return K_SKIP;
  if (n->type != ZUH_NODE_ELEMENT || n->ns != ZUH_NS_HTML)
    return K_OTHER;
  if ((n->flags & ZUH_FLAG_TEMPLATE) != 0)
    return K_SKIP;
  name = zuh_str(doc, n->name);
  if (strcmp(name, "script") == 0 || strcmp(name, "style") == 0)
    return K_SKIP;
  if (id != root) {
    if (o->skip_lists && (strcmp(name, "ul") == 0 || strcmp(name, "ol") == 0))
      return K_SKIP_BLOCK;
    if (o->skip_tables && strcmp(name, "table") == 0)
      return K_SKIP_BLOCK;
  }
  if (strcmp(name, "br") == 0)
    return K_BR;
  if (strcmp(name, "td") == 0 || strcmp(name, "th") == 0)
    return K_CELL;
  if (strcmp(name, "pre") == 0 || strcmp(name, "textarea") == 0 ||
      strcmp(name, "listing") == 0 || strcmp(name, "plaintext") == 0)
    return K_PRE;
  if (in_list(name, block_tags, sizeof(block_tags) / sizeof(block_tags[0])))
    return K_BLOCK;
  return K_OTHER;
}

typedef struct {
  zuh_buf *out;
  const zuh_clean_opts *o;
  int started;       /* something visible has been written */
  int space;         /* collapsed whitespace is pending */
  int block;         /* a block boundary is pending */
  unsigned hard;     /* <br> line breaks pending */
  int pre;           /* depth inside preformatted elements */
} cleaner;

/* Flush pending separators before a visible character. */
static void
flush(cleaner *c) {
  if (c->started) {
    unsigned breaks = c->hard > 0 ? c->hard : (unsigned) c->block;
    unsigned i;
    if (breaks > 0) {
      for (i = 0; i < breaks; i++)
        zuh_buf_put(c->out, "\n", 1);
    } else if (c->space) {
      zuh_buf_put(c->out, " ", 1);
    }
  } else if (c->space && !c->o->trim) {
    zuh_buf_put(c->out, " ", 1);
  }
  c->space = 0;
  c->block = 0;
  c->hard = 0;
  c->started = 1;
}

static int
is_ws(unsigned char ch) {
  return ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' || ch == '\f';
}

static void
add_text(cleaner *c, const char *s) {
  const unsigned char *p = (const unsigned char *) s;
  const unsigned char *run = NULL;
  while (*p != '\0') {
    int nbsp = c->o->nbsp && p[0] == 0xC2 && p[1] == 0xA0;
    int ws = is_ws(*p) || nbsp;
    if (c->pre == 0 && ws) {
      if (run != NULL) {
        zuh_buf_put(c->out, (const char *) run, (size_t) (p - run));
        run = NULL;
      }
      c->space = 1;
      p += nbsp ? 2 : 1;
      continue;
    }
    if (run == NULL) {
      flush(c);
      run = p;
    }
    if (nbsp && c->pre > 0) {
      /* Folded to a space even when whitespace is kept. */
      zuh_buf_put(c->out, (const char *) run, (size_t) (p - run));
      zuh_buf_put(c->out, " ", 1);
      p += 2;
      run = p;
      continue;
    }
    p++;
  }
  if (run != NULL)
    zuh_buf_put(c->out, (const char *) run, (size_t) (p - run));
}

static void
enter(cleaner *c, int kind) {
  switch (kind) {
  case K_BLOCK:
    c->block = 1;
    break;
  case K_CELL:
    c->space = 1;
    break;
  case K_BR:
    if (c->started)
      c->hard++;
    c->space = 0;
    break;
  case K_PRE:
    c->block = 1;
    c->pre++;
    break;
  default:
    break;
  }
}

static void
leave(cleaner *c, int kind) {
  switch (kind) {
  case K_BLOCK:
    c->block = 1;
    break;
  case K_CELL:
    c->space = 1;
    break;
  case K_PRE:
    c->block = 1;
    c->pre--;
    break;
  default:
    break;
  }
}

zuh_status
zuh_text_clean(const zuh_doc *doc, zuh_id id, const zuh_clean_opts *opts,
               zuh_buf *out) {
  cleaner c;
  const zuh_node *root = &doc->nodes[id];
  zuh_id cur;

  memset(&c, 0, sizeof(c));
  c.out = out;
  c.o = opts;
  if (root->type == ZUH_NODE_TEXT) {
    add_text(&c, zuh_str(doc, root->value));
  } else if (root->type == ZUH_NODE_ELEMENT ||
             root->type == ZUH_NODE_DOCUMENT) {
    int rk = kind_of(doc, id, id, opts);
    if (rk != K_SKIP && rk != K_SKIP_BLOCK) {
      /* The root's own kind matters only for preformatting. */
      if (rk == K_PRE)
        c.pre++;
      cur = root->first_child;
      while (cur != ZUH_NONE) {
        const zuh_node *n = &doc->nodes[cur];
        int k = kind_of(doc, cur, id, opts);
        if (k == K_SKIP) {
          /* fall through to moving on */
        } else if (k == K_SKIP_BLOCK) {
          c.block = 1;
        } else if (n->type == ZUH_NODE_TEXT) {
          add_text(&c, zuh_str(doc, n->value));
        } else {
          enter(&c, k);
          if (n->first_child != ZUH_NONE) {
            cur = n->first_child;
            continue;
          }
          leave(&c, k);
        }
        /* Move on: to the next sibling, or up, leaving each ancestor. */
        while (cur != ZUH_NONE && doc->nodes[cur].next_sibling == ZUH_NONE) {
          cur = doc->nodes[cur].parent;
          if (cur == id || cur == ZUH_NONE) {
            cur = ZUH_NONE;
            break;
          }
          leave(&c, kind_of(doc, cur, id, opts));
        }
        if (cur != ZUH_NONE)
          cur = doc->nodes[cur].next_sibling;
      }
    }
  }
  if (!opts->trim && c.space)
    zuh_buf_put(out, " ", 1);
  return out->failed ? ZUH_LIMIT_MEMORY : ZUH_OK;
}
