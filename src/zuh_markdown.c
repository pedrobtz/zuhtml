/* See zuh_markdown.h. One iterative walk with enter and leave events from
 * the tree links, as zuh_text.c; the open elements are a stack of frames
 * in a buffer, never the C stack.
 *
 * Output is lazy. Separators (a space, block breaks, hard breaks) and the
 * openers of inline markup (emphasis, links, heading markers) wait until
 * visible content arrives, so an empty element writes nothing, and
 * whitespace never ends up inside a delimiter. Line prefixes (block quote
 * markers, list markers and their continuation indent) are written at the
 * start of each line from the frames on the stack. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "zuh_markdown.h"

/* Paragraph-like elements: a blank line before and after. Sorted, for
 * bsearch. zuh_text.c's block list less the elements with their own
 * handling here. */
static const char *const block_tags[] = {
  "address", "article", "aside", "body", "center", "dd", "details",
  "dialog", "div", "dl", "dt", "fieldset", "figcaption", "figure",
  "footer", "form", "header", "hgroup", "html", "legend", "main", "nav",
  "optgroup", "option", "p", "section", "summary"};

/* Subtrees that contribute nothing. */
static const char *const skip_tags[] = {
  "head", "iframe", "noembed", "noframes", "script", "style", "template"};

static int
cmp_name(const void *key, const void *elt) {
  return strcmp((const char *) key, *(const char *const *) elt);
}

static int
in_list(const char *name, const char *const *list, size_t n) {
  return bsearch(name, list, n, sizeof(list[0]), cmp_name) != NULL;
}

#define IN_LIST(name, list) in_list(name, list, sizeof(list) / sizeof(list[0]))

enum {
  M_SKIP = 0, M_INLINE, M_BLOCK, M_HEADING, M_QUOTE, M_LIST, M_ITEM, M_PRE,
  M_CODE, M_EM, M_STRONG, M_LINK, M_IMG, M_BR, M_HR, M_TABLE, M_SECTION,
  M_ROW, M_CELL, M_CAPTION
};

enum { D_NONE = 0, D_EM, D_STRONG, D_LINK, D_HEADING };
enum { S_NONE = 0, S_PENDING, S_OPEN };

typedef struct {
  zuh_id id;
  unsigned char kind;
  unsigned char delim;      /* D_*: inline markup this element wraps */
  unsigned char dstate;     /* S_*: its opener waits, or has been written */
  unsigned char container;  /* a quote or list item: contributes a prefix */
  unsigned char marker_pending; /* list item: its marker is not yet out */
  unsigned char marker_len;
  unsigned char flat;       /* this frame raised md.flat */
  unsigned char ordered;    /* list */
  unsigned char reversed;   /* list */
  unsigned char level;      /* heading */
  char marker[16];          /* list item: "- " or "12. " */
  long next;                /* list: the next item's number */
  const char *url;          /* link */
  size_t open_at;           /* emphasis: where its opener was written */
  int table_prev;           /* table: the enclosing md.table */
} frame;

typedef struct {
  const zuh_doc *doc;
  const zuh_md_urls *urls;
  zuh_id root;
  zuh_buf *out;
  zuh_buf stack;            /* frames */
  zuh_buf tmp;              /* code text */
  int fail;

  int started;        /* visible content has been written */
  int need_prefix;    /* at a line start whose prefix is not written */
  int line_start;     /* the prefix was just written, nothing after it */
  int line_content;   /* something follows the prefix on this line */
  int lead_digits;    /* the line so far is a digit run after its prefix */
  unsigned char prev; /* last byte written */
  size_t closer_end;  /* output length right after an emphasis closer */
  unsigned char closer_delim;   /* its D_*, or D_NONE */
  size_t closer_open_at;        /* where that emphasis opened */
  int space;          /* a collapsed space is pending */
  int pending_nl;     /* line breaks wanted before the next content */
  int nl_written;     /* line breaks already at the end of the output */
  int soft_list_end;  /* a list just ended with a single pending break */
  unsigned hard;      /* <br> breaks pending */
  int flat;           /* inside a heading or table cell: one line */
  int heading;        /* inside a heading: '#' is escaped */

  int table;          /* frame index of the pipe table being written, -1 */
  int cell;           /* inside a cell of that table */
  int caption;        /* inside its caption */
  unsigned ncols;     /* its column count */
  unsigned row;       /* rows written */
  unsigned cells;     /* cells written in the current row */
} md;

#define FRAMES(m) ((frame *) (void *) (m)->stack.buf)
#define NFRAMES(m) ((int) ((m)->stack.len / sizeof(frame)))

static void
put(md *m, const char *s, size_t n) {
  if (n == 0)
    return;
  zuh_buf_put(m->out, s, n);
  m->prev = (unsigned char) s[n - 1];
}

static const char *
attr_of(const zuh_doc *doc, zuh_id id, const char *name) {
  const zuh_node *n = &doc->nodes[id];
  uint32_t i;
  for (i = 0; i < n->attr_count; i++) {
    const zuh_attr *a = &doc->attrs[n->attr_start + i];
    if (a->ns == ZUH_ATTR_NS_NONE && strcmp(zuh_str(doc, a->name), name) == 0)
      return zuh_str(doc, a->value);
  }
  return NULL;
}

static const char *
url_of(const md *m, zuh_id id, const char *attr) {
  const char *raw = attr_of(m->doc, id, attr);
  if (m->urls != NULL && m->urls->n > 0) {
    size_t lo = 0, hi = m->urls->n;
    while (lo < hi) {
      size_t mid = lo + (hi - lo) / 2;
      if (m->urls->ids[mid] < id)
        lo = mid + 1;
      else
        hi = mid;
    }
    if (lo < m->urls->n && m->urls->ids[lo] == id &&
        m->urls->urls[lo] != NULL)
      return m->urls->urls[lo];
  }
  return raw;
}

static int
is_ws(unsigned char ch) {
  return ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' || ch == '\f';
}

static int is_alnum(unsigned char ch);

/* Character classes for CommonMark's flanking rules. */
enum { C_NONE = 0, C_WS, C_PUNCT, C_OTHER };

/* The class of the code point at p (UTF-8). Unicode whitespace and the
 * common Unicode punctuation blocks are recognized; the rest is C_OTHER. */
static int
class_at(const unsigned char *p) {
  unsigned long c;
  if (*p == 0)
    return C_WS;
  if (*p < 0x80) {
    if (*p <= 0x20 || *p == 0x7F)
      return C_WS;
    return is_alnum(*p) ? C_OTHER : C_PUNCT;
  }
  if ((*p & 0xE0) == 0xC0 && (p[1] & 0xC0) == 0x80)
    c = ((unsigned long) (*p & 0x1F) << 6) | (p[1] & 0x3Fu);
  else if ((*p & 0xF0) == 0xE0 && (p[1] & 0xC0) == 0x80 &&
           (p[2] & 0xC0) == 0x80)
    c = ((unsigned long) (*p & 0x0F) << 12) |
        ((unsigned long) (p[1] & 0x3F) << 6) | (p[2] & 0x3Fu);
  else
    return C_OTHER;
  if (c == 0xA0 || c == 0x1680 || (c >= 0x2000 && c <= 0x200A) ||
      c == 0x202F || c == 0x205F || c == 0x3000)
    return C_WS;
  if ((c >= 0xA1 && c <= 0xBF && c != 0xAA && c != 0xB2 && c != 0xB3 &&
       c != 0xB5 && c != 0xB9 && c != 0xBA && c != 0xBC && c != 0xBD &&
       c != 0xBE) ||
      c == 0xD7 || c == 0xF7 || (c >= 0x2010 && c <= 0x2027) ||
      (c >= 0x2030 && c <= 0x205E) || (c >= 0x3001 && c <= 0x3003) ||
      (c >= 0x3008 && c <= 0x3011) || (c >= 0x3014 && c <= 0x301F) ||
      (c >= 0xFE10 && c <= 0xFE19) || (c >= 0xFE30 && c <= 0xFE4F) ||
      (c >= 0xFF01 && c <= 0xFF0F) || (c >= 0xFF1A && c <= 0xFF20) ||
      (c >= 0xFF3B && c <= 0xFF40) || (c >= 0xFF5B && c <= 0xFF65))
    return C_PUNCT;
  return C_OTHER;
}

/* The class of the last code point written; the start of the output
 * counts as whitespace. */
static int
tail_class(const md *m) {
  size_t i = m->out->len;
  if (m->out->failed || i == 0)
    return C_WS;
  i--;
  while (i > 0 && i + 4 > m->out->len &&
         ((unsigned char) m->out->buf[i] & 0xC0) == 0x80)
    i--;
  return class_at((const unsigned char *) m->out->buf + i);
}

/* The length of the whitespace at p: ASCII whitespace, or a no-break space,
 * which collapses like a space as in html_text_clean(nbsp = TRUE); a
 * delimiter next to one would not open or close. 0 if none. */
static int
ws_len(const unsigned char *p) {
  if (is_ws(*p))
    return 1;
  return p[0] == 0xC2 && p[1] == 0xA0 ? 2 : 0;
}

static int
is_alnum(unsigned char ch) {
  return (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'z') ||
         (ch >= 'A' && ch <= 'Z') || ch >= 0x80;
}

/* An HTML integer attribute: optional whitespace and sign, then digits.
 * `dflt` when there are none. Clamped to what a list marker can show. */
static long
int_attr(const char *s, long dflt) {
  long v = 0, sign = 1;
  int any = 0;
  if (s == NULL)
    return dflt;
  while (is_ws((unsigned char) *s))
    s++;
  if (*s == '-' || *s == '+') {
    sign = *s == '-' ? -1 : 1;
    s++;
  }
  while (*s >= '0' && *s <= '9') {
    if (v < 1000000000L)
      v = v * 10 + (*s - '0');
    any = 1;
    s++;
  }
  return any ? sign * v : dflt;
}

/* A span attribute is 1 when missing, invalid or (for colspan) 0. */
static int
span_is_one(const char *s, int is_colspan) {
  long v = int_attr(s, 1);
  if (s != NULL && v == 0 && is_colspan)
    return 1;
  return v == 1;
}

static int
elem_is(const zuh_doc *doc, zuh_id id, const char *name) {
  const zuh_node *n = &doc->nodes[id];
  return n->type == ZUH_NODE_ELEMENT && n->ns == ZUH_NS_HTML &&
         strcmp(zuh_str(doc, n->name), name) == 0;
}

static int
kind_of(const zuh_doc *doc, zuh_id id) {
  const zuh_node *n = &doc->nodes[id];
  const char *name;
  if (n->type == ZUH_NODE_DOCUMENT)
    return M_INLINE;
  if (n->type != ZUH_NODE_ELEMENT)
    return M_SKIP;
  name = zuh_str(doc, n->name);
  if (n->ns == ZUH_NS_SVG && strcmp(name, "svg") == 0)
    return M_SKIP;
  if (n->ns != ZUH_NS_HTML)
    return M_INLINE;
  if ((n->flags & ZUH_FLAG_TEMPLATE) != 0 || IN_LIST(name, skip_tags))
    return M_SKIP;
  if (name[0] == 'h' && name[1] >= '1' && name[1] <= '6' && name[2] == '\0')
    return M_HEADING;
  if (strcmp(name, "a") == 0)
    return attr_of(doc, id, "href") != NULL ? M_LINK : M_INLINE;
  if (strcmp(name, "img") == 0)
    return attr_of(doc, id, "src") != NULL ? M_IMG : M_SKIP;
  if (strcmp(name, "em") == 0 || strcmp(name, "i") == 0)
    return M_EM;
  if (strcmp(name, "strong") == 0 || strcmp(name, "b") == 0)
    return M_STRONG;
  if (strcmp(name, "code") == 0 || strcmp(name, "kbd") == 0 ||
      strcmp(name, "samp") == 0 || strcmp(name, "tt") == 0)
    return M_CODE;
  if (strcmp(name, "pre") == 0 || strcmp(name, "listing") == 0 ||
      strcmp(name, "plaintext") == 0 || strcmp(name, "xmp") == 0)
    return M_PRE;
  if (strcmp(name, "br") == 0)
    return M_BR;
  if (strcmp(name, "hr") == 0)
    return M_HR;
  if (strcmp(name, "blockquote") == 0)
    return M_QUOTE;
  if (strcmp(name, "ul") == 0 || strcmp(name, "ol") == 0 ||
      strcmp(name, "menu") == 0 || strcmp(name, "dir") == 0)
    return M_LIST;
  if (strcmp(name, "li") == 0)
    return M_ITEM;
  if (strcmp(name, "table") == 0)
    return M_TABLE;
  if (strcmp(name, "thead") == 0 || strcmp(name, "tbody") == 0 ||
      strcmp(name, "tfoot") == 0)
    return M_SECTION;
  if (strcmp(name, "tr") == 0)
    return M_ROW;
  if (strcmp(name, "td") == 0 || strcmp(name, "th") == 0)
    return M_CELL;
  if (strcmp(name, "caption") == 0)
    return M_CAPTION;
  if (IN_LIST(name, block_tags))
    return M_BLOCK;
  return M_INLINE;
}

/* ---- Prefixes, breaks and delimiters ---------------------------------- */

/* The prefix of a line: "> " per quote, and per list item its marker on
 * the item's first line, else as many spaces. A blank line takes the
 * prefix without trailing spaces and leaves markers pending. */
static void
put_prefix(md *m, int blank) {
  frame *f = FRAMES(m);
  int i, nf = NFRAMES(m);
  size_t start = m->out->len;
  for (i = 0; i < nf; i++) {
    if (!f[i].container)
      continue;
    if (f[i].kind == M_QUOTE) {
      put(m, "> ", 2);
    } else if (f[i].marker_pending && !blank) {
      put(m, f[i].marker, f[i].marker_len);
      f[i].marker_pending = 0;
    } else {
      put(m, "                ", f[i].marker_len);
    }
  }
  if (blank && !m->out->failed) {
    while (m->out->len > start && m->out->buf[m->out->len - 1] == ' ')
      m->out->len--;
    m->out->buf[m->out->len] = '\0';
  }
}

static void
put_dest(md *m, const char *url) {
  const unsigned char *p = (const unsigned char *) url;
  char hex[4];
  for (; *p != '\0'; p++) {
    if (*p == '(' || *p == ')' || *p == '\\') {
      put(m, "\\", 1);
      put(m, (const char *) p, 1);
    } else if (*p <= 0x20 || *p == 0x7F || *p == '<' || *p == '>' ||
               (*p == '|' && m->cell)) {
      snprintf(hex, sizeof(hex), "%%%02X", (unsigned) *p);
      put(m, hex, 3);
    } else {
      put(m, (const char *) p, 1);
    }
  }
}

static void
put_closer(md *m, const frame *f) {
  switch (f->delim) {
  case D_EM:
    put(m, "*", 1);
    break;
  case D_STRONG:
    put(m, "**", 2);
    break;
  case D_LINK:
    put(m, "](", 2);
    put_dest(m, f->url);
    put(m, ")", 1);
    break;
  default:
    break;
  }
}

static void
put_opener(md *m, const frame *f) {
  switch (f->delim) {
  case D_EM:
    put(m, "*", 1);
    break;
  case D_STRONG:
    put(m, "**", 2);
    break;
  case D_LINK:
    put(m, "[", 1);
    break;
  case D_HEADING:
    put(m, "######", f->level);
    put(m, " ", 1);
    break;
  default:
    break;
  }
}

/* Close the inline markup that is open, innermost first, to reopen on the
 * next content. */
static void
close_open(md *m) {
  frame *f = FRAMES(m);
  int i;
  for (i = NFRAMES(m) - 1; i >= 0; i--) {
    if (f[i].dstate == S_OPEN && f[i].delim != D_HEADING) {
      put_closer(m, &f[i]);
      f[i].dstate = S_PENDING;
    }
  }
}

static void
want_break(md *m, int n) {
  if (m->flat) {
    m->space = 1;
    return;
  }
  if (n > m->pending_nl)
    m->pending_nl = n;
  if (n > 1)
    m->soft_list_end = 0;
  m->space = 0;
  m->hard = 0;
}

/* Write the pending block breaks. Inline markup still open is closed
 * first and reopened on the next content, so it never spans blocks. */
static void
emit_breaks(md *m) {
  if (!m->started) {
    m->pending_nl = 0;
    return;
  }
  if (m->pending_nl > m->nl_written) {
    close_open(m);
    while (m->nl_written < m->pending_nl) {
      if (m->nl_written >= 1)
        put_prefix(m, 1);
      put(m, "\n", 1);
      m->nl_written++;
    }
    m->need_prefix = 1;
    m->line_content = 0;
  }
  m->pending_nl = 0;
}

/* Before visible content: breaks, prefix or space, and, if `next` (the
 * C_* class of the content's first character) is not C_NONE, the openers
 * of pending inline markup. */
static void
content_start(md *m, int next) {
  int delims = next != C_NONE;
  if (m->soft_list_end && m->pending_nl == 1) {
    /* Text after a nested list, in the same item, needs a blank line or
     * it would continue the nested list's last item. */
    frame *f = FRAMES(m);
    int i, fresh_item = 0;
    for (i = NFRAMES(m) - 1; i >= 0; i--) {
      if (f[i].container) {
        fresh_item = f[i].kind == M_ITEM && f[i].marker_pending;
        break;
      }
    }
    if (!fresh_item)
      m->pending_nl = 2;
  }
  m->soft_list_end = 0;
  emit_breaks(m);
  if (m->hard > 0 && m->line_content && !m->need_prefix) {
    unsigned i;
    for (i = 0; i < m->hard; i++) {
      if (i > 0)
        put_prefix(m, 0);
      put(m, "\\\n", 2);
    }
    m->need_prefix = 1;
    m->space = 0;
  }
  m->hard = 0;
  if (m->need_prefix) {
    put_prefix(m, 0);
    m->need_prefix = 0;
    m->line_start = 1;
    m->lead_digits = 0;
    m->line_content = 0;
    m->space = 0;
  } else if (m->space && m->line_content) {
    put(m, " ", 1);
    m->line_start = 0;
    m->lead_digits = 0;
  }
  m->space = 0;
  if (delims) {
    /* A heading marker goes first, even inside a link: "## [a](u)". */
    frame *f = FRAMES(m);
    int i, pass, nf = NFRAMES(m);
    for (pass = 0; pass < 2; pass++) {
      for (i = 0; i < nf; i++) {
        int after = next, j, emph;
        if (f[i].dstate != S_PENDING || (f[i].delim == D_HEADING) != !pass)
          continue;
        for (j = i + 1; j < nf; j++) {
          if (f[j].dstate == S_PENDING && f[j].delim != D_HEADING) {
            after = C_PUNCT;
            break;
          }
        }
        emph = f[i].delim == D_EM || f[i].delim == D_STRONG;
        if (emph && !m->out->failed && m->closer_delim == f[i].delim &&
            m->closer_end == m->out->len) {
          /* Emphasis right after emphasis of its kind continues it:
           * "*a**b*" would not parse, "*ab*" does. */
          m->out->len -= f[i].delim == D_EM ? 1 : 2;
          m->out->buf[m->out->len] = '\0';
          m->closer_delim = D_NONE;
          f[i].open_at = m->closer_open_at;
          f[i].dstate = S_OPEN;
          continue;
        }
        if (emph) {
          /* An opener before whitespace, between a letter and
           * punctuation ("a*."), or against a closer cannot open:
           * leave that emphasis out. */
          int star = !m->out->failed && m->closer_delim != D_NONE &&
                     m->closer_end == m->out->len;
          if (after == C_WS || star ||
              (after == C_PUNCT && tail_class(m) == C_OTHER)) {
            f[i].dstate = S_NONE;
            continue;
          }
          f[i].open_at = m->out->len;
        }
        put_opener(m, &f[i]);
        f[i].dstate = S_OPEN;
        m->line_start = 0;
      }
    }
  }
  m->started = 1;
  m->nl_written = 0;
}

/* Content between a simple table's cells is dropped. */
static int
suppressed(const md *m) {
  return m->table >= 0 && !m->cell && !m->caption;
}

/* ---- Text -------------------------------------------------------------- */

/* Write bytes [p, end) of non-whitespace text, escaped. */
static void
put_escaped(md *m, const unsigned char *p, const unsigned char *end) {
  const unsigned char *start = p, *run = p;
  for (; p < end; p++) {
    unsigned char ch = *p;
    unsigned char pv = p > start ? p[-1] : m->prev;
    unsigned char nx = p + 1 < end ? p[1] : 0;
    int esc = 0;
    if (m->line_start) {
      if (ch == '#' || ch == '-' || ch == '+' || ch == '=' || ch == '~')
        esc = 1;
      m->lead_digits = ch >= '0' && ch <= '9';
      m->line_start = 0;
    } else if (m->lead_digits) {
      if (ch == '.' || ch == ')')
        esc = 1;
      m->lead_digits = ch >= '0' && ch <= '9';
    }
    switch (ch) {
    case '\\': case '`': case '*': case '[': case ']': case '<': case '>':
    case '~':
      esc = 1;
      break;
    case '_':
      /* Inside a word, as in snake_case, it cannot delimit. */
      if (!(is_alnum(pv) && is_alnum(nx)))
        esc = 1;
      break;
    case '&':
      if (is_alnum(nx) || nx == '#')
        esc = 1;
      break;
    case '|':
      if (m->cell)
        esc = 1;
      break;
    case '#':
      if (m->heading)
        esc = 1;
      break;
    default:
      break;
    }
    if (esc) {
      put(m, (const char *) run, (size_t) (p - run));
      put(m, "\\", 1);
      run = p;
    }
  }
  put(m, (const char *) run, (size_t) (end - run));
}

static void
put_text(md *m, const char *s) {
  const unsigned char *p = (const unsigned char *) s;
  if (suppressed(m))
    return;
  while (*p != '\0') {
    const unsigned char *start;
    int w = ws_len(p);
    if (w > 0) {
      m->space = 1;
      p += w;
      continue;
    }
    content_start(m, class_at(p));
    start = p;
    while (*p != '\0' && ws_len(p) == 0)
      p++;
    put_escaped(m, start, p);
    m->line_content = 1;
  }
}

/* The text of a subtree into m->tmp, skipping what the walk skips. The
 * preorder range is walked directly: no stack. */
static void
collect_text(md *m, zuh_id id) {
  const zuh_doc *doc = m->doc;
  zuh_id j, end = doc->nodes[id].subtree_end;
  m->tmp.len = 0;
  zuh_buf_put(&m->tmp, "", 0);
  for (j = id + 1; j <= end && j != ZUH_NONE; j++) {
    const zuh_node *n = &doc->nodes[j];
    if (n->type == ZUH_NODE_TEXT) {
      zuh_buf_str(&m->tmp, zuh_str(doc, n->value));
    } else if (n->type == ZUH_NODE_ELEMENT) {
      int k = kind_of(doc, j);
      if (k == M_SKIP) {
        j = n->subtree_end;
      } else if (k == M_BR) {
        zuh_buf_put(&m->tmp, "\n", 1);
      } else if (k != M_INLINE && k != M_EM && k != M_STRONG &&
                 k != M_LINK && k != M_CODE && k != M_IMG &&
                 m->tmp.len > 0 && m->tmp.buf[m->tmp.len - 1] != '\n') {
        /* A block inside <pre>, as some highlighters write lines. */
        zuh_buf_put(&m->tmp, "\n", 1);
      }
    }
  }
}

static size_t
longest_run(const char *s, size_t len, char ch) {
  size_t best = 0, cur = 0, i;
  for (i = 0; i < len; i++) {
    cur = s[i] == ch ? cur + 1 : 0;
    if (cur > best)
      best = cur;
  }
  return best;
}

static void
put_repeat(md *m, char ch, size_t n) {
  while (n-- > 0)
    put(m, &ch, 1);
}

/* An inline code span, whitespace collapsed. */
static void
put_code(md *m, zuh_id id) {
  char *s;
  size_t i, len = 0, fence;
  int ws = 0;
  if (suppressed(m))
    return;
  collect_text(m, id);
  if (m->tmp.failed)
    return;
  s = m->tmp.buf;
  for (i = 0; i < m->tmp.len; i++) {
    if (is_ws((unsigned char) s[i])) {
      ws = len > 0;
      continue;
    }
    if (ws)
      s[len++] = ' ';
    ws = 0;
    s[len++] = s[i];
  }
  if (len == 0)
    return;
  content_start(m, C_PUNCT);
  fence = longest_run(s, len, '`') + 1;
  put_repeat(m, '`', fence);
  if (s[0] == '`' || s[len - 1] == '`')
    put(m, " ", 1);
  for (i = 0; i < len; i++) {
    if (s[i] == '|' && m->cell)
      put(m, "\\", 1);
    put(m, &s[i], 1);
  }
  if (s[0] == '`' || s[len - 1] == '`')
    put(m, " ", 1);
  put_repeat(m, '`', fence);
  m->line_content = 1;
}

/* The language of a code block: a "language-x" or "lang-x" class on the
 * <pre> or on a <code> that is its only element child. */
static void
put_info(md *m, zuh_id id) {
  const zuh_doc *doc = m->doc;
  zuh_id c, only = ZUH_NONE;
  const char *cls[2];
  int k;
  for (c = doc->nodes[id].first_child; c != ZUH_NONE;
       c = doc->nodes[c].next_sibling) {
    if (doc->nodes[c].type == ZUH_NODE_ELEMENT) {
      if (only != ZUH_NONE) {
        only = ZUH_NONE;
        break;
      }
      only = c;
    }
  }
  cls[0] = attr_of(doc, id, "class");
  cls[1] = only != ZUH_NONE && elem_is(doc, only, "code")
             ? attr_of(doc, only, "class") : NULL;
  for (k = 0; k < 2; k++) {
    const char *p = cls[k];
    while (p != NULL && *p != '\0') {
      const char *tok, *e;
      while (is_ws((unsigned char) *p))
        p++;
      tok = p;
      while (*p != '\0' && !is_ws((unsigned char) *p))
        p++;
      if (strncmp(tok, "language-", 9) == 0)
        tok += 9;
      else if (strncmp(tok, "lang-", 5) == 0)
        tok += 5;
      else
        continue;
      for (e = tok; e < p && *e != '`' && e - tok < 40; e++)
        ;
      if (e > tok) {
        put(m, tok, (size_t) (e - tok));
        return;
      }
    }
  }
}

/* A fenced code block, lines kept. */
static void
put_pre(md *m, zuh_id id) {
  const char *s, *line;
  size_t len, fence;
  if (suppressed(m))
    return;
  collect_text(m, id);
  if (m->tmp.failed)
    return;
  s = m->tmp.buf;
  len = m->tmp.len;
  if (len > 0 && s[len - 1] == '\n')
    len--;
  want_break(m, 2);
  content_start(m, 0);
  fence = longest_run(s, len, '`') + 1;
  if (fence < 3)
    fence = 3;
  put_repeat(m, '`', fence);
  put_info(m, id);
  put(m, "\n", 1);
  line = s;
  while (len > 0 && line <= s + len) {
    const char *nl = memchr(line, '\n', (size_t) (s + len - line));
    const char *e = nl != NULL ? nl : s + len;
    put_prefix(m, e == line);
    put(m, line, (size_t) (e - line));
    put(m, "\n", 1);
    if (nl == NULL)
      break;
    line = nl + 1;
  }
  put_prefix(m, 0);
  put_repeat(m, '`', fence);
  m->line_content = 1;
  want_break(m, 2);
}

static void
put_image(md *m, zuh_id id) {
  const char *alt = attr_of(m->doc, id, "alt");
  const unsigned char *p;
  int first = 1;
  if (suppressed(m))
    return;
  content_start(m, C_PUNCT);
  put(m, "![", 2);
  m->line_start = 0;
  m->lead_digits = 0;
  p = (const unsigned char *) (alt != NULL ? alt : "");
  while (*p != '\0') {
    const unsigned char *start;
    if (is_ws(*p)) {
      p++;
      continue;
    }
    if (!first)
      put(m, " ", 1);
    first = 0;
    start = p;
    while (*p != '\0' && !is_ws(*p))
      p++;
    put_escaped(m, start, p);
  }
  put(m, "](", 2);
  put_dest(m, url_of(m, id, "src"));
  put(m, ")", 1);
  m->line_content = 1;
}

/* ---- Tables ------------------------------------------------------------ */

/* A pipe table is for data: no spans, only inline content in the cells (a
 * table with blocks in its cells is a layout table, and its content is
 * worth more than its grid), a caption (if any) first, and at least one
 * row with a cell and something visible. Sets *ncols. */
static int
simple_table(const zuh_doc *doc, zuh_id id, unsigned *ncols) {
  zuh_id j, end = doc->nodes[id].subtree_end, first = ZUH_NONE;
  unsigned most = 0;
  int visible = 0;
  for (j = doc->nodes[id].first_child; j != ZUH_NONE;
       j = doc->nodes[j].next_sibling) {
    if (doc->nodes[j].type == ZUH_NODE_ELEMENT) {
      first = j;
      break;
    }
  }
  for (j = id + 1; j <= end && j != ZUH_NONE; j++) {
    const zuh_node *n = &doc->nodes[j];
    int kind;
    if (n->type == ZUH_NODE_TEXT && !visible) {
      const char *t = zuh_str(doc, n->value);
      while (is_ws((unsigned char) *t))
        t++;
      visible = *t != '\0';
    }
    if (n->type != ZUH_NODE_ELEMENT)
      continue;
    kind = kind_of(doc, j);
    if (kind == M_SKIP) {
      j = n->subtree_end;
      continue;
    }
    if (kind == M_IMG)
      visible = 1;
    if (n->ns != ZUH_NS_HTML)
      continue;
    if (kind == M_TABLE || kind == M_BLOCK || kind == M_HEADING ||
        kind == M_QUOTE || kind == M_LIST || kind == M_ITEM ||
        kind == M_PRE || kind == M_HR)
      return 0;
    if (elem_is(doc, j, "caption") && j != first)
      return 0;
    if (elem_is(doc, j, "td") || elem_is(doc, j, "th")) {
      if (!span_is_one(attr_of(doc, j, "colspan"), 1) ||
          !span_is_one(attr_of(doc, j, "rowspan"), 0))
        return 0;
    }
    if (elem_is(doc, j, "tr")) {
      unsigned count = 0;
      zuh_id c;
      for (c = n->first_child; c != ZUH_NONE; c = doc->nodes[c].next_sibling)
        if (elem_is(doc, c, "td") || elem_is(doc, c, "th"))
          count++;
      if (count > most)
        most = count;
    }
  }
  *ncols = most;
  return most > 0 && visible;
}

static void
row_start(md *m) {
  want_break(m, m->row == 0 ? 2 : 1);
  content_start(m, 0);
  put(m, "|", 1);
  m->cells = 0;
  m->line_content = 1;
}

static void
row_end(md *m) {
  unsigned i;
  for (; m->cells < m->ncols; m->cells++)
    put(m, "  |", 3);
  if (m->row == 0) {
    put(m, "\n", 1);
    put_prefix(m, 0);
    put(m, "|", 1);
    for (i = 0; i < m->ncols; i++)
      put(m, " --- |", 6);
  }
  m->row++;
  m->space = 0;
  want_break(m, 1);
}

/* ---- Enter and leave ----------------------------------------------------- */

/* Enter element or document `id`. Returns 1 if a frame was pushed (the
 * walk descends and calls leave()), 0 if the node was handled whole or
 * skipped. */
static int
enter(md *m, zuh_id id) {
  const zuh_doc *doc = m->doc;
  int kind = kind_of(doc, id);
  frame f;

  if (m->fail)
    return 0;
  if (kind == M_SKIP) {
    /* An image-like element left out still separates words. */
    const zuh_node *n = &doc->nodes[id];
    if (n->type == ZUH_NODE_ELEMENT &&
        (strcmp(zuh_str(doc, n->name), "svg") == 0 ||
         strcmp(zuh_str(doc, n->name), "iframe") == 0))
      m->space = 1;
    return 0;
  }
  if (m->flat) {
    /* One line: blocks are spaces, and some constructs lose their
     * markup. */
    switch (kind) {
    case M_PRE:
      m->space = 1;
      put_code(m, id);
      m->space = 1;
      return 0;
    case M_BR:
    case M_HR:
      m->space = 1;
      return 0;
    case M_HEADING: case M_QUOTE: case M_LIST: case M_ITEM: case M_TABLE:
    case M_CAPTION: case M_SECTION: case M_ROW: case M_CELL:
      kind = M_BLOCK;
      break;
    default:
      break;
    }
  }
  switch (kind) {
  case M_CODE:
    put_code(m, id);
    return 0;
  case M_PRE:
    put_pre(m, id);
    return 0;
  case M_IMG:
    put_image(m, id);
    return 0;
  case M_BR:
    if (m->line_content && !suppressed(m))
      m->hard++;
    m->space = 0;
    return 0;
  case M_HR:
    if (suppressed(m))
      return 0;
    want_break(m, 2);
    content_start(m, 0);
    put(m, "---", 3);
    m->line_content = 1;
    want_break(m, 2);
    return 0;
  default:
    break;
  }

  memset(&f, 0, sizeof(f));
  f.id = id;
  f.kind = (unsigned char) kind;
  f.table_prev = -1;
  switch (kind) {
  case M_BLOCK:
    want_break(m, 2);
    break;
  case M_CAPTION:
    want_break(m, 2);
    if (m->table >= 0)
      m->caption++;
    break;
  case M_HEADING:
    want_break(m, 2);
    f.delim = D_HEADING;
    f.dstate = S_PENDING;
    f.level = (unsigned char) (zuh_str(doc, doc->nodes[id].name)[1] - '0');
    f.flat = 1;
    m->flat++;
    m->heading++;
    break;
  case M_EM:
  case M_STRONG:
    f.delim = kind == M_EM ? D_EM : D_STRONG;
    f.dstate = S_PENDING;
    break;
  case M_LINK:
    f.delim = D_LINK;
    f.dstate = S_PENDING;
    f.url = url_of(m, id, "href");
    break;
  case M_QUOTE:
    want_break(m, 2);
    emit_breaks(m);
    f.container = 1;
    break;
  case M_LIST: {
    const frame *fr = FRAMES(m);
    int i, in_item = 0;
    for (i = NFRAMES(m) - 1; i >= 0; i--) {
      if (fr[i].container) {
        in_item = fr[i].kind == M_ITEM;
        break;
      }
    }
    f.ordered = (unsigned char) elem_is(doc, id, "ol");
    f.reversed = (unsigned char) (f.ordered &&
                                  attr_of(doc, id, "reversed") != NULL);
    f.next = int_attr(attr_of(doc, id, "start"), 1);
    /* A nested list follows its item's text on the next line, except an
     * ordered one not starting at 1, which cannot interrupt a paragraph. */
    want_break(m, in_item && (!f.ordered || f.next == 1) ? 1 : 2);
    break;
  }
  case M_ITEM: {
    frame *fr = FRAMES(m);
    frame *list = NULL;
    int i;
    for (i = NFRAMES(m) - 1; i >= 0; i--) {
      if (fr[i].kind == M_LIST) {
        list = &fr[i];
        break;
      }
      if (fr[i].container)
        break;
    }
    want_break(m, 1);
    emit_breaks(m);
    if (list != NULL && list->ordered) {
      long n = int_attr(attr_of(doc, id, "value"), list->next);
      list->next = list->reversed ? n - 1 : n + 1;
      if (n < 0)
        n = 0;
      if (n > 999999999L)
        n = 999999999L;
      snprintf(f.marker, sizeof(f.marker), "%ld. ", n);
    } else {
      strcpy(f.marker, "- ");
    }
    f.marker_len = (unsigned char) strlen(f.marker);
    f.marker_pending = 1;
    f.container = 1;
    break;
  }
  case M_TABLE: {
    unsigned ncols;
    want_break(m, 2);
    if (m->table < 0 && simple_table(doc, id, &ncols)) {
      f.table_prev = m->table;
      m->table = NFRAMES(m);
      m->ncols = ncols;
      m->row = 0;
    }
    break;
  }
  case M_ROW:
    if (m->table >= 0 && !m->cell)
      row_start(m);
    else
      want_break(m, 2);
    break;
  case M_CELL:
    if (m->table >= 0 && !m->cell) {
      put(m, " ", 1);
      m->cell = 1;
      m->space = 0;
      m->line_content = 0;
      m->line_start = 0;
      m->lead_digits = 0;
      f.flat = 1;
      m->flat++;
    } else {
      m->space = 1;
    }
    break;
  default:
    break;
  }
  zuh_buf_put(&m->stack, (const char *) &f, sizeof(f));
  if (m->stack.failed) {
    m->fail = 1;
    return 0;
  }
  return 1;
}

static int
inline_kind(int kind) {
  return kind == M_INLINE || kind == M_EM || kind == M_STRONG ||
         kind == M_LINK;
}

/* The class of what the walk writes after element `id`: whitespace for a
 * block boundary or the end, punctuation for markup, else the class of the
 * next text. A lookahead in document order, so an estimate. */
static int
class_after(const md *m, zuh_id id) {
  const zuh_doc *doc = m->doc;
  zuh_id end = doc->nodes[id].subtree_end, a, j;
  for (a = doc->nodes[id].parent;
       a != ZUH_NONE && doc->nodes[a].subtree_end == end;
       a = doc->nodes[a].parent) {
    if (a == m->root || !inline_kind(kind_of(doc, a)))
      return C_WS;
  }
  for (j = end + 1; j < doc->n_nodes && j <= doc->nodes[m->root].subtree_end;
       j++) {
    const zuh_node *n = &doc->nodes[j];
    if (n->type == ZUH_NODE_TEXT) {
      const unsigned char *t = (const unsigned char *) zuh_str(doc, n->value);
      if (*t != '\0')
        return class_at(t);
    } else if (n->type == ZUH_NODE_ELEMENT) {
      int k = kind_of(doc, j);
      if (k == M_SKIP)
        j = n->subtree_end;
      else if (k == M_LINK || k == M_IMG || k == M_CODE)
        return C_PUNCT;
      else if (!inline_kind(k))
        return C_WS;
    }
  }
  return C_WS;
}

/* Close emphasis on leaving it. A closer after punctuation and before a
 * letter ("*a.*b") cannot close; then the opener is removed instead. */
static void
close_emphasis(md *m, const frame *f) {
  size_t olen = f->delim == D_EM ? 1 : 2;
  zuh_buf *o = m->out;
  if (!o->failed && !m->space && tail_class(m) == C_PUNCT &&
      class_after(m, f->id) == C_OTHER && f->open_at + olen <= o->len &&
      o->buf[f->open_at] == '*') {
    memmove(o->buf + f->open_at, o->buf + f->open_at + olen,
            o->len - f->open_at - olen);
    o->len -= olen;
    o->buf[o->len] = '\0';
    m->closer_delim = D_NONE;
    return;
  }
  put_closer(m, f);
  m->closer_end = o->len;
  m->closer_delim = f->delim;
  m->closer_open_at = f->open_at;
}

static void
leave(md *m) {
  frame f;
  if (m->fail || NFRAMES(m) == 0)
    return;
  f = FRAMES(m)[NFRAMES(m) - 1];
  if (f.dstate == S_OPEN) {
    if (f.delim == D_EM || f.delim == D_STRONG)
      close_emphasis(m, &f);
    else
      put_closer(m, &f);
  }
  m->stack.len -= sizeof(frame);
  if (f.flat)
    m->flat--;
  switch (f.kind) {
  case M_BLOCK:
  case M_QUOTE:
    want_break(m, 2);
    break;
  case M_HEADING:
    m->heading--;
    want_break(m, 2);
    break;
  case M_CAPTION:
    if (m->table >= 0 && m->caption > 0)
      m->caption--;
    want_break(m, 2);
    break;
  case M_LIST:
    if (m->flat) {
      m->space = 1;
    } else {
      want_break(m, 1);
      m->soft_list_end = 1;
    }
    break;
  case M_ITEM:
    want_break(m, 1);
    break;
  case M_TABLE:
    if (m->table == NFRAMES(m))
      m->table = f.table_prev;
    want_break(m, 2);
    break;
  case M_ROW:
    if (m->table >= 0 && !m->cell)
      row_end(m);
    else
      want_break(m, 2);
    break;
  case M_CELL:
    if (f.flat) {
      /* Markup opened in the cell from outside the table closes in it. */
      close_open(m);
      m->cell = 0;
      m->space = 0;
      put(m, " |", 2);
      m->cells++;
      m->line_content = 1;
    } else {
      m->space = 1;
    }
    break;
  default:
    break;
  }
}

zuh_status
zuh_markdown(const zuh_doc *doc, zuh_id id, const zuh_md_urls *urls,
             zuh_buf *out) {
  md m;
  const zuh_node *root = &doc->nodes[id];
  int failed;

  memset(&m, 0, sizeof(m));
  m.doc = doc;
  m.root = id;
  m.urls = urls;
  m.out = out;
  m.need_prefix = 1;
  m.table = -1;
  zuh_buf_init(&m.stack, out->alloc, out->userdata);
  zuh_buf_init(&m.tmp, out->alloc, out->userdata);
  m.stack.len = 0;

  if (root->type == ZUH_NODE_TEXT) {
    put_text(&m, zuh_str(doc, root->value));
  } else if ((root->type == ZUH_NODE_ELEMENT ||
              root->type == ZUH_NODE_DOCUMENT) && enter(&m, id)) {
    zuh_id cur = root->first_child;
    while (cur != ZUH_NONE && !m.fail) {
      const zuh_node *n = &doc->nodes[cur];
      if (n->type == ZUH_NODE_TEXT) {
        put_text(&m, zuh_str(doc, n->value));
      } else if (enter(&m, cur)) {
        if (n->first_child != ZUH_NONE) {
          cur = n->first_child;
          continue;
        }
        leave(&m);
      }
      /* Move on: to the next sibling, or up, leaving each ancestor. */
      while (cur != ZUH_NONE && doc->nodes[cur].next_sibling == ZUH_NONE) {
        cur = doc->nodes[cur].parent;
        if (cur == id || cur == ZUH_NONE) {
          cur = ZUH_NONE;
          break;
        }
        leave(&m);
      }
      if (cur != ZUH_NONE)
        cur = doc->nodes[cur].next_sibling;
    }
    leave(&m);
  }
  failed = m.fail || m.stack.failed || m.tmp.failed || out->failed;
  if (out->alloc == NULL) {
    zuh_buf_free(&m.stack);
    zuh_buf_free(&m.tmp);
  }
  return failed ? ZUH_LIMIT_MEMORY : ZUH_OK;
}
