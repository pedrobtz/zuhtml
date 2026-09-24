/* The CSS selector subset. See zuh_selector.h.
 *
 * Compilation is a small recursive-descent parser over a CSS Syntax subset:
 * identifiers with escapes, strings, hash, delimiters and the an+b
 * microsyntax. The compiled form is flat arrays: simple selectors, compound
 * selectors (runs of simple ones, each carrying the combinator to its
 * left), and complex selectors (runs of compounds). A :not() argument is a
 * compound of its own that no complex selector lists; SS_NOT refers to it.
 *
 * Matching is right to left, after Servo's selectors crate: a failed match
 * reports how far the search may skip, which keeps descendant and sibling
 * combinators from backtracking exponentially. */
#include <stdlib.h>
#include <string.h>

#include "zuh_selector.h"

enum {
  SS_TYPE = 0,
  SS_UNIVERSAL,
  SS_ID,
  SS_CLASS,
  SS_ATTR,
  SS_SCOPE,
  SS_ROOT,
  SS_EMPTY,
  SS_FIRST_CHILD,
  SS_LAST_CHILD,
  SS_ONLY_CHILD,
  SS_NTH_CHILD,
  SS_NTH_OF_TYPE,
  SS_NOT
};

enum { OP_EXISTS = 0, OP_EQ, OP_INCLUDES, OP_DASH, OP_PREFIX, OP_SUFFIX,
       OP_SUBSTR };
enum { FLAG_NONE = 0, FLAG_I, FLAG_S };
enum { COMB_NONE = 0, COMB_DESC, COMB_CHILD, COMB_NEXT, COMB_LATER };

typedef struct {
  uint8_t kind;
  uint8_t op;       /* SS_ATTR */
  uint8_t flag;     /* SS_ATTR */
  uint8_t attr_ns;  /* SS_ATTR: ZUH_ATTR_NS_* */
  uint32_t s1;      /* pool offset: name as written, ID, class, attr name */
  uint32_t s2;      /* pool offset: SS_TYPE lowercased name; SS_ATTR value */
  int32_t a, b;     /* an+b */
  uint32_t sub;     /* SS_NOT: compound index */
} simple;

typedef struct {
  uint32_t first, count; /* simples */
  uint8_t comb;          /* combinator to the compound on the left */
} compound;

typedef struct {
  uint32_t first, count; /* compounds, left to right */
} complex_sel;

struct zuh_selector {
  simple *ss;
  size_t nss, css;
  compound *cp;
  size_t ncp, ccp;
  complex_sel *cx;
  size_t ncx, ccx;
  char *pool;
  size_t npool, cpool;
  int needs_positions;
  int scopes_subject;
};

/* ---- growable arrays ------------------------------------------------- */

static int
grow(void **p, size_t *cap, size_t need, size_t elt) {
  size_t nc;
  void *q;
  if (need <= *cap)
    return 1;
  nc = *cap ? *cap : 8;
  while (nc < need) {
    if (nc > ((size_t) -1 / 2) / elt)
      return 0;
    nc *= 2;
  }
  q = realloc(*p, nc * elt);
  if (q == NULL)
    return 0;
  *p = q;
  *cap = nc;
  return 1;
}

/* ---- the parser -------------------------------------------------------- */

/* The simples of the compound being parsed. Each compound collects its
 * own, and appends them to sel->ss in one run when it is complete, because
 * a :not() inside it completes a compound of its own first. */
typedef struct {
  simple *v;
  size_t n, cap;
} simple_buf;

typedef struct {
  const unsigned char *s;
  size_t len, pos;
  zuh_selector *sel;
  zuh_sel_error *err;
  simple_buf *cur;
} parser;

static int
fail(parser *p, zuh_sel_status st, size_t pos, const char *why) {
  if (p->err->status == ZUH_SEL_OK) {
    p->err->status = st;
    p->err->position = pos;
    p->err->reason = why;
  }
  return 0;
}

static int
at_end(const parser *p) {
  return p->pos >= p->len;
}

static int
peek(const parser *p, size_t k) {
  return p->pos + k < p->len ? p->s[p->pos + k] : -1;
}

static int
is_ws(int c) {
  return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f';
}

static int
skip_ws(parser *p) {
  size_t start = p->pos;
  while (!at_end(p) && is_ws(p->s[p->pos]))
    p->pos++;
  if (peek(p, 0) == '/' && peek(p, 1) == '*')
    return fail(p, ZUH_SEL_UNSUPPORTED, p->pos,
                "comments are not supported in selectors"),
           -1;
  return p->pos > start;
}

static int
is_hex(int c) {
  return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') ||
         (c >= 'A' && c <= 'F');
}

static int
hex_val(int c) {
  return c <= '9' ? c - '0' : (c | 0x20) - 'a' + 10;
}

static int
is_name_start(int c) {
  return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_' ||
         c >= 0x80;
}

static int
is_name(int c) {
  return is_name_start(c) || (c >= '0' && c <= '9') || c == '-';
}

/* A backslash that starts an escape: not followed by a newline. */
static int
valid_escape(const parser *p, size_t k) {
  return peek(p, k) == '\\' && peek(p, k + 1) != '\n' &&
         peek(p, k + 1) != '\r' && peek(p, k + 1) != '\f';
}

static int
ident_start(const parser *p) {
  int c = peek(p, 0);
  if (c == '-') {
    int d = peek(p, 1);
    return is_name_start(d) || d == '-' || valid_escape(p, 1);
  }
  return is_name_start(c) || valid_escape(p, 0);
}

static int
pool_put(parser *p, const void *b, size_t n) {
  zuh_selector *sel = p->sel;
  if (!grow((void **) &sel->pool, &sel->cpool, sel->npool + n + 1, 1))
    return fail(p, ZUH_SEL_NO_MEMORY, p->pos, "out of memory");
  memcpy(sel->pool + sel->npool, b, n);
  sel->npool += n;
  return 1;
}

/* Copy the pool string at `off` to the end of the pool. The source is
 * addressed only after the pool has grown: growing may move it. */
static int
pool_dup(parser *p, uint32_t off, uint32_t *copy) {
  zuh_selector *sel = p->sel;
  size_t n = strlen(sel->pool + off) + 1;
  if (!grow((void **) &sel->pool, &sel->cpool, sel->npool + n + 1, 1))
    return fail(p, ZUH_SEL_NO_MEMORY, p->pos, "out of memory");
  memcpy(sel->pool + sel->npool, sel->pool + off, n);
  *copy = (uint32_t) sel->npool;
  sel->npool += n;
  return 1;
}

static int
pool_utf8(parser *p, unsigned long cp) {
  unsigned char b[4];
  size_t n;
  if (cp == 0 || cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF))
    cp = 0xFFFD;
  if (cp < 0x80) {
    b[0] = (unsigned char) cp;
    n = 1;
  } else if (cp < 0x800) {
    b[0] = (unsigned char) (0xC0 | (cp >> 6));
    b[1] = (unsigned char) (0x80 | (cp & 0x3F));
    n = 2;
  } else if (cp < 0x10000) {
    b[0] = (unsigned char) (0xE0 | (cp >> 12));
    b[1] = (unsigned char) (0x80 | ((cp >> 6) & 0x3F));
    b[2] = (unsigned char) (0x80 | (cp & 0x3F));
    n = 3;
  } else {
    b[0] = (unsigned char) (0xF0 | (cp >> 18));
    b[1] = (unsigned char) (0x80 | ((cp >> 12) & 0x3F));
    b[2] = (unsigned char) (0x80 | ((cp >> 6) & 0x3F));
    b[3] = (unsigned char) (0x80 | (cp & 0x3F));
    n = 4;
  }
  return pool_put(p, b, n);
}

/* Consume an escape (the backslash is at p->pos) into the pool. */
static int
consume_escape(parser *p) {
  p->pos++; /* the backslash */
  if (at_end(p))
    return pool_utf8(p, 0xFFFD);
  if (is_hex(p->s[p->pos])) {
    unsigned long cp = 0;
    int k;
    for (k = 0; k < 6 && !at_end(p) && is_hex(p->s[p->pos]); k++)
      cp = cp * 16 + (unsigned long) hex_val(p->s[p->pos++]);
    if (peek(p, 0) == '\r' && peek(p, 1) == '\n')
      p->pos += 2;
    else if (!at_end(p) && is_ws(p->s[p->pos]))
      p->pos++;
    return pool_utf8(p, cp);
  }
  return pool_put(p, &p->s[p->pos++], 1);
}

/* Consume an identifier into a new NUL-terminated pool string; its offset
 * goes to *off. The caller has checked ident_start(). */
static int
consume_ident(parser *p, uint32_t *off) {
  size_t start = p->sel->npool;
  if (start > (size_t) UINT32_MAX - 1)
    return fail(p, ZUH_SEL_NO_MEMORY, p->pos, "selector too large");
  while (!at_end(p)) {
    int c = p->s[p->pos];
    if (is_name(c)) {
      if (!pool_put(p, &p->s[p->pos], 1))
        return 0;
      p->pos++;
    } else if (valid_escape(p, 0)) {
      if (!consume_escape(p))
        return 0;
    } else {
      break;
    }
  }
  if (!pool_put(p, "", 1))
    return 0;
  *off = (uint32_t) start;
  return 1;
}

static int
consume_string(parser *p, uint32_t *off) {
  int quote = p->s[p->pos++];
  size_t start = p->sel->npool;
  while (1) {
    int c;
    if (at_end(p))
      break; /* EOF ends a string, as in CSS */
    c = p->s[p->pos];
    if (c == quote) {
      p->pos++;
      break;
    }
    if (c == '\n' || c == '\r' || c == '\f')
      return fail(p, ZUH_SEL_SYNTAX, p->pos, "newline inside a string");
    if (c == '\\') {
      int d = peek(p, 1);
      if (d == -1) {
        p->pos++;
      } else if (d == '\n' || d == '\f') {
        p->pos += 2;
      } else if (d == '\r') {
        p->pos += peek(p, 2) == '\n' ? 3 : 2;
      } else if (!consume_escape(p)) {
        return 0;
      }
      continue;
    }
    if (!pool_put(p, &p->s[p->pos], 1))
      return 0;
    p->pos++;
  }
  if (!pool_put(p, "", 1))
    return 0;
  *off = (uint32_t) start;
  return 1;
}

/* A new simple selector in the current compound. The pointer is valid
 * until the next call. */
static simple *
new_simple(parser *p, uint8_t kind) {
  simple_buf *b = p->cur;
  simple *s;
  if (!grow((void **) &b->v, &b->cap, b->n + 1, sizeof(simple))) {
    fail(p, ZUH_SEL_NO_MEMORY, p->pos, "out of memory");
    return NULL;
  }
  s = &b->v[b->n++];
  memset(s, 0, sizeof(*s));
  s->kind = kind;
  return s;
}

static simple *
last_simple(parser *p) {
  return &p->cur->v[p->cur->n - 1];
}

static int
lower_eq(const unsigned char *a, size_t n, const char *b) {
  size_t i;
  for (i = 0; i < n; i++) {
    int c = a[i];
    if (c >= 'A' && c <= 'Z')
      c += 'a' - 'A';
    if (b[i] == '\0' || c != b[i])
      return 0;
  }
  return b[n] == '\0';
}

/* an+b, on the bytes between the parentheses. */
static int
parse_nth(parser *p, size_t s, size_t e, int32_t *a, int32_t *b) {
  const unsigned char *t = p->s;
  size_t i;
  long sign = 1, na = 0, nb = 0;
  int have_digits = 0;
  while (s < e && is_ws(t[s]))
    s++;
  while (e > s && is_ws(t[e - 1]))
    e--;
  if (lower_eq(t + s, e - s, "odd")) {
    *a = 2;
    *b = 1;
    return 1;
  }
  if (lower_eq(t + s, e - s, "even")) {
    *a = 2;
    *b = 0;
    return 1;
  }
  for (i = s; i + 1 < e; i++)
    if ((t[i] == 'o' || t[i] == 'O') && (t[i + 1] == 'f' || t[i + 1] == 'F') &&
        i > s && is_ws(t[i - 1]))
      return fail(p, ZUH_SEL_UNSUPPORTED, i,
                  "the \"of S\" form of :nth-child() is not supported");
  i = s;
  if (i < e && (t[i] == '+' || t[i] == '-')) {
    sign = t[i] == '-' ? -1 : 1;
    i++;
  }
  while (i < e && t[i] >= '0' && t[i] <= '9') {
    if (na > 100000000L)
      return fail(p, ZUH_SEL_SYNTAX, i, "number too large in an+b");
    na = na * 10 + (t[i++] - '0');
    have_digits = 1;
  }
  if (i < e && (t[i] == 'n' || t[i] == 'N')) {
    na = sign * (have_digits ? na : 1);
    i++;
    while (i < e && is_ws(t[i]))
      i++;
    if (i < e) {
      long bs;
      if (t[i] != '+' && t[i] != '-')
        return fail(p, ZUH_SEL_SYNTAX, i, "malformed an+b");
      bs = t[i] == '-' ? -1 : 1;
      i++;
      while (i < e && is_ws(t[i]))
        i++;
      if (i >= e || t[i] < '0' || t[i] > '9')
        return fail(p, ZUH_SEL_SYNTAX, i, "malformed an+b");
      while (i < e && t[i] >= '0' && t[i] <= '9') {
        if (nb > 100000000L)
          return fail(p, ZUH_SEL_SYNTAX, i, "number too large in an+b");
        nb = nb * 10 + (t[i++] - '0');
      }
      nb *= bs;
    }
  } else {
    if (!have_digits)
      return fail(p, ZUH_SEL_SYNTAX, i, "malformed an+b");
    nb = sign * na;
    na = 0;
  }
  if (i != e)
    return fail(p, ZUH_SEL_SYNTAX, i, "malformed an+b");
  *a = (int32_t) na;
  *b = (int32_t) nb;
  return 1;
}

static int parse_compound(parser *p, uint8_t comb, int depth,
                          uint32_t *index);

static int
parse_attribute(parser *p) {
  simple *s;
  uint32_t name;
  const char *nm;
  size_t pos;
  p->pos++; /* [ */
  if (skip_ws(p) < 0)
    return 0;
  if (peek(p, 0) == '|' || peek(p, 0) == '*')
    return fail(p, ZUH_SEL_UNSUPPORTED, p->pos,
                "namespace prefixes are not supported");
  if (!ident_start(p))
    return fail(p, ZUH_SEL_SYNTAX, p->pos, "expected an attribute name");
  if (!consume_ident(p, &name))
    return 0;
  if (peek(p, 0) == '|' && peek(p, 1) != '=')
    return fail(p, ZUH_SEL_UNSUPPORTED, p->pos,
                "namespace prefixes are not supported");
  s = new_simple(p, SS_ATTR);
  if (s == NULL)
    return 0;
  /* "xlink:href" written with an escaped colon names the namespaced
   * attribute, as html_attr() does. */
  nm = p->sel->pool + name;
  s->attr_ns = ZUH_ATTR_NS_NONE;
  if (strncmp(nm, "xlink:", 6) == 0) {
    s->attr_ns = ZUH_ATTR_NS_XLINK;
    name += 6;
  } else if (strncmp(nm, "xml:", 4) == 0) {
    s->attr_ns = ZUH_ATTR_NS_XML;
    name += 4;
  } else if (strncmp(nm, "xmlns:", 6) == 0) {
    s->attr_ns = ZUH_ATTR_NS_XMLNS;
    name += 6;
  }
  s->s1 = name;
  if (skip_ws(p) < 0)
    return 0;
  if (peek(p, 0) == ']') {
    p->pos++;
    s->op = OP_EXISTS;
    return 1;
  }
  pos = p->pos;
  switch (peek(p, 0)) {
  case '=':
    s->op = OP_EQ;
    p->pos++;
    break;
  case '~':
    s->op = OP_INCLUDES;
    break;
  case '|':
    s->op = OP_DASH;
    break;
  case '^':
    s->op = OP_PREFIX;
    break;
  case '$':
    s->op = OP_SUFFIX;
    break;
  case '*':
    s->op = OP_SUBSTR;
    break;
  default:
    return fail(p, ZUH_SEL_SYNTAX, pos, "expected ] or an attribute matcher");
  }
  if (s->op != OP_EQ) {
    if (peek(p, 1) != '=')
      return fail(p, ZUH_SEL_SYNTAX, pos, "expected an attribute matcher");
    p->pos += 2;
  }
  if (skip_ws(p) < 0)
    return 0;
  if (peek(p, 0) == '"' || peek(p, 0) == '\'') {
    uint32_t v;
    if (!consume_string(p, &v))
      return 0;
    s = last_simple(p);
    s->s2 = v;
  } else if (ident_start(p)) {
    uint32_t v;
    if (!consume_ident(p, &v))
      return 0;
    s = last_simple(p);
    s->s2 = v;
  } else {
    return fail(p, ZUH_SEL_SYNTAX, p->pos,
                "expected an attribute value (an identifier or a string)");
  }
  if (skip_ws(p) < 0)
    return 0;
  if (peek(p, 0) != ']') {
    int c = peek(p, 0) | 0x20;
    if ((c == 'i' || c == 's') && (is_ws(peek(p, 1)) || peek(p, 1) == ']')) {
      s->flag = c == 'i' ? FLAG_I : FLAG_S;
      p->pos++;
      if (skip_ws(p) < 0)
        return 0;
    }
  }
  if (peek(p, 0) != ']')
    return fail(p, ZUH_SEL_SYNTAX, p->pos, "expected ]");
  p->pos++;
  return 1;
}

static int
parse_pseudo(parser *p, int depth) {
  size_t start = p->pos;
  const unsigned char *name;
  size_t n;
  simple *s;

  p->pos++; /* : */
  if (peek(p, 0) == ':')
    return fail(p, ZUH_SEL_UNSUPPORTED, start,
                "pseudo-elements are not supported");
  if (!ident_start(p))
    return fail(p, ZUH_SEL_SYNTAX, p->pos, "expected a pseudo-class name");
  name = p->s + p->pos;
  while (!at_end(p) && is_name(p->s[p->pos]))
    p->pos++;
  n = (size_t) (p->s + p->pos - name);
  if (peek(p, 0) == '\\')
    return fail(p, ZUH_SEL_UNSUPPORTED, start,
                "escapes in pseudo-class names are not supported");

  if (peek(p, 0) != '(') {
    static const struct {
      const char *name;
      uint8_t kind;
    } plain[] = {{"scope", SS_SCOPE},           {"root", SS_ROOT},
                 {"empty", SS_EMPTY},           {"first-child", SS_FIRST_CHILD},
                 {"last-child", SS_LAST_CHILD}, {"only-child", SS_ONLY_CHILD}};
    size_t i;
    for (i = 0; i < sizeof(plain) / sizeof(plain[0]); i++) {
      if (lower_eq(name, n, plain[i].name)) {
        s = new_simple(p, plain[i].kind);
        if (s == NULL)
          return 0;
        if (plain[i].kind >= SS_FIRST_CHILD)
          p->sel->needs_positions = 1;
        return 1;
      }
    }
    if (lower_eq(name, n, "before") || lower_eq(name, n, "after") ||
        lower_eq(name, n, "first-line") || lower_eq(name, n, "first-letter"))
      return fail(p, ZUH_SEL_UNSUPPORTED, start,
                  "pseudo-elements are not supported");
    return fail(p, ZUH_SEL_UNSUPPORTED, start,
                "this pseudo-class is not supported");
  }

  p->pos++; /* ( */
  if (lower_eq(name, n, "nth-child") || lower_eq(name, n, "nth-of-type")) {
    size_t s0 = p->pos;
    uint8_t kind = lower_eq(name, n, "nth-child") ? SS_NTH_CHILD
                                                  : SS_NTH_OF_TYPE;
    int32_t a, b;
    while (!at_end(p) && p->s[p->pos] != ')')
      p->pos++;
    if (at_end(p))
      return fail(p, ZUH_SEL_SYNTAX, s0, "expected )");
    if (!parse_nth(p, s0, p->pos, &a, &b))
      return 0;
    p->pos++; /* ) */
    s = new_simple(p, kind);
    if (s == NULL)
      return 0;
    s->a = a;
    s->b = b;
    p->sel->needs_positions = 1;
    return 1;
  }
  if (lower_eq(name, n, "not")) {
    uint32_t sub;
    if (depth >= ZUH_SEL_MAX_NOT_DEPTH)
      return fail(p, ZUH_SEL_TOO_COMPLEX, start, ":not() nested too deeply");
    if (skip_ws(p) < 0)
      return 0;
    if (!parse_compound(p, COMB_NONE, depth + 1, &sub))
      return 0;
    if (skip_ws(p) < 0)
      return 0;
    if (peek(p, 0) == ',')
      return fail(p, ZUH_SEL_UNSUPPORTED, p->pos,
                  "a selector list in :not() is not supported");
    if (peek(p, 0) != ')')
      return fail(p, ZUH_SEL_UNSUPPORTED, p->pos,
                  ":not() takes one compound selector, without combinators");
    p->pos++;
    s = new_simple(p, SS_NOT);
    if (s == NULL)
      return 0;
    s->sub = sub;
    return 1;
  }
  if (lower_eq(name, n, "has"))
    return fail(p, ZUH_SEL_UNSUPPORTED, start, ":has() is not supported");
  return fail(p, ZUH_SEL_UNSUPPORTED, start,
              "this pseudo-class is not supported");
}

/* One compound selector: an optional type or universal selector, then any
 * number of #id, .class, [attr] and :pseudo. Appended to sel->cp; its
 * index goes to *index. */
static int
parse_compound(parser *p, uint8_t comb, int depth, uint32_t *index) {
  zuh_selector *sel = p->sel;
  size_t start_pos = p->pos;
  simple_buf buf = {NULL, 0, 0};
  simple_buf *outer = p->cur;
  compound *c;
  int ok = 0;

  p->cur = &buf;
  if (peek(p, 0) == '*') {
    p->pos++;
    if (peek(p, 0) == '|') {
      fail(p, ZUH_SEL_UNSUPPORTED, p->pos - 1,
           "namespace prefixes are not supported");
      goto done;
    }
    if (new_simple(p, SS_UNIVERSAL) == NULL)
      goto done;
  } else if (peek(p, 0) == '|') {
    fail(p, ZUH_SEL_UNSUPPORTED, p->pos,
         "namespace prefixes are not supported");
    goto done;
  } else if (ident_start(p)) {
    uint32_t nm, lower;
    char *q;
    simple *s;
    if (!consume_ident(p, &nm))
      goto done;
    if (peek(p, 0) == '|') {
      fail(p, ZUH_SEL_UNSUPPORTED, start_pos,
           "namespace prefixes are not supported");
      goto done;
    }
    if (!pool_dup(p, nm, &lower))
      goto done;
    for (q = sel->pool + lower; *q; q++)
      if (*q >= 'A' && *q <= 'Z')
        *q = (char) (*q - 'A' + 'a');
    s = new_simple(p, SS_TYPE);
    if (s == NULL)
      goto done;
    s->s1 = nm;
    s->s2 = lower;
  }

  while (!at_end(p)) {
    int c0 = p->s[p->pos];
    if (c0 == '#' || c0 == '.') {
      uint32_t v;
      simple *s;
      p->pos++;
      if (!ident_start(p)) {
        fail(p, ZUH_SEL_SYNTAX, p->pos,
             c0 == '#' ? "expected an ID after #" : "expected a class after .");
        goto done;
      }
      if (!consume_ident(p, &v))
        goto done;
      s = new_simple(p, c0 == '#' ? SS_ID : SS_CLASS);
      if (s == NULL)
        goto done;
      s->s1 = v;
    } else if (c0 == '[') {
      if (!parse_attribute(p))
        goto done;
    } else if (c0 == ':') {
      if (!parse_pseudo(p, depth))
        goto done;
    } else {
      break;
    }
  }
  if (buf.n == 0) {
    fail(p, ZUH_SEL_SYNTAX, p->pos,
         at_end(p) ? "expected a selector" : "unexpected character");
    goto done;
  }

  if (!grow((void **) &sel->ss, &sel->css, sel->nss + buf.n,
            sizeof(simple)) ||
      !grow((void **) &sel->cp, &sel->ccp, sel->ncp + 1, sizeof(compound))) {
    fail(p, ZUH_SEL_NO_MEMORY, p->pos, "out of memory");
    goto done;
  }
  memcpy(&sel->ss[sel->nss], buf.v, buf.n * sizeof(simple));
  c = &sel->cp[sel->ncp];
  c->first = (uint32_t) sel->nss;
  c->count = (uint32_t) buf.n;
  c->comb = comb;
  sel->nss += buf.n;
  *index = (uint32_t) sel->ncp++;
  ok = 1;

done:
  free(buf.v);
  p->cur = outer;
  return ok;
}

static int
parse_complex(parser *p) {
  zuh_selector *sel = p->sel;
  complex_sel *cx;
  uint32_t idx, first = 0, count = 0;
  uint8_t comb = COMB_NONE;
  /* Compounds of one complex selector must be contiguous, but :not()
   * arguments are compounds too; collect the indices, then copy. */
  uint32_t *list = NULL;
  size_t cap = 0;

  for (;;) {
    int ws;
    if (!parse_compound(p, comb, 0, &idx))
      goto fail;
    if (!grow((void **) &list, &cap, count + 1, sizeof(uint32_t))) {
      fail(p, ZUH_SEL_NO_MEMORY, p->pos, "out of memory");
      goto fail;
    }
    list[count++] = idx;
    if (count > ZUH_SEL_MAX_COMPOUNDS) {
      fail(p, ZUH_SEL_TOO_COMPLEX, p->pos, "too many combinators");
      goto fail;
    }
    ws = skip_ws(p);
    if (ws < 0)
      goto fail;
    if (at_end(p) || peek(p, 0) == ',')
      break;
    switch (peek(p, 0)) {
    case '>':
      comb = COMB_CHILD;
      p->pos++;
      break;
    case '+':
      comb = COMB_NEXT;
      p->pos++;
      break;
    case '~':
      comb = COMB_LATER;
      p->pos++;
      break;
    default:
      if (!ws) {
        fail(p, ZUH_SEL_SYNTAX, p->pos, "unexpected character");
        goto fail;
      }
      comb = COMB_DESC;
    }
    if (comb != COMB_DESC && skip_ws(p) < 0)
      goto fail;
    if (at_end(p) || peek(p, 0) == ',') {
      fail(p, ZUH_SEL_SYNTAX, p->pos, "expected a selector after a combinator");
      goto fail;
    }
  }

  /* Append copies of the listed compounds contiguously. */
  if (!grow((void **) &sel->cp, &sel->ccp, sel->ncp + count,
            sizeof(compound))) {
    fail(p, ZUH_SEL_NO_MEMORY, p->pos, "out of memory");
    goto fail;
  }
  first = (uint32_t) sel->ncp;
  {
    uint32_t i;
    for (i = 0; i < count; i++)
      sel->cp[sel->ncp++] = sel->cp[list[i]];
  }
  free(list);
  if (!grow((void **) &sel->cx, &sel->ccx, sel->ncx + 1, sizeof(complex_sel)))
    return fail(p, ZUH_SEL_NO_MEMORY, p->pos, "out of memory");
  cx = &sel->cx[sel->ncx++];
  cx->first = first;
  cx->count = count;
  {
    const compound *subj = &sel->cp[first + count - 1];
    uint32_t i;
    for (i = 0; i < subj->count; i++)
      if (sel->ss[subj->first + i].kind == SS_SCOPE)
        sel->scopes_subject = 1;
  }
  return 1;

fail:
  free(list);
  return 0;
}

zuh_sel_status
zuh_selector_compile(const char *css, size_t len, zuh_selector **out,
                     zuh_sel_error *err) {
  parser p;
  zuh_selector *sel;

  *out = NULL;
  err->status = ZUH_SEL_OK;
  err->position = 0;
  err->reason = NULL;
  sel = (zuh_selector *) calloc(1, sizeof(zuh_selector));
  if (sel == NULL) {
    err->status = ZUH_SEL_NO_MEMORY;
    err->reason = "out of memory";
    return err->status;
  }
  p.s = (const unsigned char *) css;
  p.len = len;
  p.pos = 0;
  p.sel = sel;
  p.err = err;
  p.cur = NULL;

  /* Offset 0 of the pool is "". */
  if (!pool_put(&p, "", 1))
    goto fail;
  if (skip_ws(&p) < 0)
    goto fail;
  if (at_end(&p)) {
    fail(&p, ZUH_SEL_SYNTAX, 0, "the selector is empty");
    goto fail;
  }
  for (;;) {
    if (!parse_complex(&p))
      goto fail;
    if (at_end(&p))
      break;
    /* parse_complex stops only at the end or a comma */
    p.pos++;
    if (skip_ws(&p) < 0)
      goto fail;
    if (at_end(&p)) {
      fail(&p, ZUH_SEL_SYNTAX, p.pos, "expected a selector after ,");
      goto fail;
    }
  }
  *out = sel;
  return ZUH_SEL_OK;

fail:
  zuh_selector_free(sel);
  return err->status;
}

void
zuh_selector_free(zuh_selector *sel) {
  if (sel == NULL)
    return;
  free(sel->ss);
  free(sel->cp);
  free(sel->cx);
  free(sel->pool);
  free(sel);
}

int
zuh_selector_scopes_subject(const zuh_selector *sel) {
  return sel->scopes_subject;
}

int
zuh_selector_needs_positions(const zuh_selector *sel) {
  return sel->needs_positions;
}

/* ---- matching ---------------------------------------------------------- */

void
zuh_selector_positions(const zuh_doc *doc, int32_t *elem_pos,
                       int32_t *elem_count) {
  zuh_id id;
  for (id = 0; id < doc->n_nodes; id++) {
    elem_pos[id] = 0;
    elem_count[id] = 0;
  }
  for (id = 0; id < doc->n_nodes; id++) {
    zuh_id c;
    int32_t k = 0;
    for (c = doc->nodes[id].first_child; c != ZUH_NONE;
         c = doc->nodes[c].next_sibling)
      if (doc->nodes[c].type == ZUH_NODE_ELEMENT)
        elem_pos[c] = ++k;
    elem_count[id] = k;
  }
}

static int
ascii_ieq(const char *a, const char *b) {
  for (; *a && *b; a++, b++) {
    char x = *a, y = *b;
    if (x >= 'A' && x <= 'Z')
      x = (char) (x - 'A' + 'a');
    if (y >= 'A' && y <= 'Z')
      y = (char) (y - 'A' + 'a');
    if (x != y)
      return 0;
  }
  return *a == *b;
}

static int
eq_n(const char *a, const char *b, size_t n, int ci) {
  size_t i;
  if (!ci)
    return memcmp(a, b, n) == 0;
  for (i = 0; i < n; i++) {
    char x = a[i], y = b[i];
    if (x >= 'A' && x <= 'Z')
      x = (char) (x - 'A' + 'a');
    if (y >= 'A' && y <= 'Z')
      y = (char) (y - 'A' + 'a');
    if (x != y)
      return 0;
  }
  return 1;
}

/* Attributes whose values HTML documents match ASCII-case-insensitively
 * in selectors (HTML standard, "case-sensitivity of selectors"). Sorted. */
static const char *const ci_attrs[] = {
  "accept", "accept-charset", "align", "alink", "axis", "bgcolor",
  "charset", "checked", "clear", "codetype", "color", "compact", "declare",
  "defer", "dir", "direction", "disabled", "enctype", "face", "frame",
  "hreflang", "http-equiv", "lang", "language", "link", "media", "method",
  "multiple", "nohref", "noresize", "noshade", "nowrap", "readonly", "rel",
  "rev", "rules", "scope", "scrolling", "selected", "shape", "target",
  "text", "type", "valign", "valuetype", "vlink"};

static int
cmp_str(const void *a, const void *b) {
  return strcmp((const char *) a, *(const char *const *) b);
}

static int
value_ci_by_default(const char *name) {
  return bsearch(name, ci_attrs, sizeof(ci_attrs) / sizeof(ci_attrs[0]),
                 sizeof(ci_attrs[0]), cmp_str) != NULL;
}

static const zuh_attr *
find_attr(const zuh_doc *doc, const zuh_node *n, const char *name,
          uint8_t ns) {
  uint32_t i;
  for (i = 0; i < n->attr_count; i++) {
    const zuh_attr *a = &doc->attrs[n->attr_start + i];
    const char *have = zuh_str(doc, a->name);
    if (a->ns != ns)
      continue;
    if (n->ns == ZUH_NS_HTML ? ascii_ieq(have, name) : strcmp(have, name) == 0)
      return a;
  }
  return NULL;
}

static int
has_token(const char *list, const char *tok, int ci) {
  size_t tl = strlen(tok);
  const char *p = list;
  if (tl == 0)
    return 0;
  for (;;) {
    const char *e;
    while (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r' || *p == '\f')
      p++;
    if (*p == '\0')
      return 0;
    e = p;
    while (*e && *e != ' ' && *e != '\t' && *e != '\n' && *e != '\r' &&
           *e != '\f')
      e++;
    if ((size_t) (e - p) == tl && eq_n(p, tok, tl, ci))
      return 1;
    p = e;
  }
}

static int
match_attr(const zuh_doc *doc, const zuh_node *n, const zuh_selector *sel,
           const simple *s) {
  const char *name = sel->pool + s->s1;
  const zuh_attr *a = find_attr(doc, n, name, s->attr_ns);
  const char *have, *want;
  size_t hl, wl;
  int ci;
  if (a == NULL)
    return 0;
  if (s->op == OP_EXISTS)
    return 1;
  have = zuh_str(doc, a->value);
  want = sel->pool + s->s2;
  hl = strlen(have);
  wl = strlen(want);
  ci = s->flag == FLAG_I ||
       (s->flag == FLAG_NONE && n->ns == ZUH_NS_HTML &&
        s->attr_ns == ZUH_ATTR_NS_NONE &&
        value_ci_by_default(zuh_str(doc, a->name)));
  switch (s->op) {
  case OP_EQ:
    return hl == wl && eq_n(have, want, wl, ci);
  case OP_INCLUDES: {
    const char *q;
    for (q = want; *q; q++)
      if (*q == ' ' || *q == '\t' || *q == '\n' || *q == '\r' || *q == '\f')
        return 0;
    return has_token(have, want, ci);
  }
  case OP_DASH:
    return (hl == wl && eq_n(have, want, wl, ci)) ||
           (hl > wl && have[wl] == '-' && eq_n(have, want, wl, ci));
  case OP_PREFIX:
    return wl > 0 && hl >= wl && eq_n(have, want, wl, ci);
  case OP_SUFFIX:
    return wl > 0 && hl >= wl && eq_n(have + hl - wl, want, wl, ci);
  case OP_SUBSTR: {
    size_t i;
    if (wl == 0 || hl < wl)
      return 0;
    for (i = 0; i + wl <= hl; i++)
      if (eq_n(have + i, want, wl, ci))
        return 1;
    return 0;
  }
  default:
    return 0;
  }
}

static int
nth_matches(int32_t a, int32_t b, int32_t i) {
  long d = (long) i - b;
  if (a == 0)
    return d == 0;
  if (d % a != 0)
    return 0;
  return d / a >= 0;
}

static int match_compound(zuh_match_ctx *ctx, uint32_t ci, zuh_id id,
                          zuh_id scope);

static int
match_simple(zuh_match_ctx *ctx, const simple *s, zuh_id id, zuh_id scope) {
  const zuh_doc *doc = ctx->doc;
  const zuh_selector *sel = ctx->sel;
  const zuh_node *n = &doc->nodes[id];
  switch (s->kind) {
  case SS_UNIVERSAL:
    return 1;
  case SS_TYPE:
    return n->ns == ZUH_NS_HTML
               ? strcmp(zuh_str(doc, n->name), sel->pool + s->s2) == 0
               : strcmp(zuh_str(doc, n->name), sel->pool + s->s1) == 0;
  case SS_ID: {
    const zuh_attr *a = find_attr(doc, n, "id", ZUH_ATTR_NS_NONE);
    return a != NULL && sel->pool[s->s1] != '\0' &&
           strcmp(zuh_str(doc, a->value), sel->pool + s->s1) == 0;
  }
  case SS_CLASS: {
    const zuh_attr *a = find_attr(doc, n, "class", ZUH_ATTR_NS_NONE);
    return a != NULL && has_token(zuh_str(doc, a->value), sel->pool + s->s1, 0);
  }
  case SS_ATTR:
    return match_attr(doc, n, sel, s);
  case SS_SCOPE:
    return id == scope;
  case SS_ROOT:
    return n->parent == 0 && !doc->is_fragment;
  case SS_EMPTY: {
    zuh_id c;
    for (c = n->first_child; c != ZUH_NONE; c = doc->nodes[c].next_sibling)
      if (doc->nodes[c].type == ZUH_NODE_ELEMENT ||
          doc->nodes[c].type == ZUH_NODE_TEXT)
        return 0;
    return 1;
  }
  case SS_FIRST_CHILD:
    return ctx->elem_pos[id] == 1;
  case SS_LAST_CHILD:
    return n->parent != ZUH_NONE &&
           ctx->elem_pos[id] == ctx->elem_count[n->parent];
  case SS_ONLY_CHILD:
    return n->parent != ZUH_NONE && ctx->elem_count[n->parent] == 1;
  case SS_NTH_CHILD:
    return nth_matches(s->a, s->b, ctx->elem_pos[id]);
  case SS_NTH_OF_TYPE: {
    int32_t k = 1;
    zuh_id c;
    for (c = n->prev_sibling; c != ZUH_NONE; c = doc->nodes[c].prev_sibling) {
      const zuh_node *m = &doc->nodes[c];
      ctx->work++;
      if (m->type == ZUH_NODE_ELEMENT && m->ns == n->ns &&
          (m->name == n->name ||
           strcmp(zuh_str(doc, m->name), zuh_str(doc, n->name)) == 0))
        k++;
    }
    return nth_matches(s->a, s->b, k);
  }
  case SS_NOT:
    return !match_compound(ctx, s->sub, id, scope);
  default:
    return 0;
  }
}

static int
match_compound(zuh_match_ctx *ctx, uint32_t ci, zuh_id id, zuh_id scope) {
  const compound *c = &ctx->sel->cp[ci];
  uint32_t i;
  if (ctx->doc->nodes[id].type != ZUH_NODE_ELEMENT)
    return 0;
  ctx->work++;
  if (ctx->work_limit != 0 && ctx->work > ctx->work_limit) {
    ctx->exceeded = 1;
    return 0;
  }
  for (i = 0; i < c->count; i++)
    if (!match_simple(ctx, &ctx->sel->ss[c->first + i], id, scope))
      return 0;
  return 1;
}

typedef enum {
  MATCHED,
  NOT_MATCHED_RESTART_FROM_LATER_SIBLING,
  NOT_MATCHED_RESTART_FROM_DESCENDANT,
  NOT_MATCHED_GLOBALLY
} match_result;

static zuh_id
element_parent(const zuh_doc *doc, zuh_id id) {
  zuh_id p = doc->nodes[id].parent;
  return p != ZUH_NONE && doc->nodes[p].type == ZUH_NODE_ELEMENT ? p
                                                                 : ZUH_NONE;
}

static zuh_id
prev_element(const zuh_doc *doc, zuh_id id) {
  zuh_id s = doc->nodes[id].prev_sibling;
  while (s != ZUH_NONE && doc->nodes[s].type != ZUH_NODE_ELEMENT)
    s = doc->nodes[s].prev_sibling;
  return s;
}

/* Match compounds [first, first + i] of a complex selector, the i-th
 * against `id`, right to left. */
static match_result
match_complex(zuh_match_ctx *ctx, uint32_t first, uint32_t i, zuh_id id,
              zuh_id scope) {
  const zuh_doc *doc = ctx->doc;
  const compound *c = &ctx->sel->cp[first + i];
  match_result not_found;
  zuh_id next;
  if (!match_compound(ctx, first + i, id, scope))
    return ctx->exceeded ? NOT_MATCHED_GLOBALLY
                         : NOT_MATCHED_RESTART_FROM_LATER_SIBLING;
  if (i == 0)
    return MATCHED;
  not_found = (c->comb == COMB_NEXT || c->comb == COMB_LATER)
                  ? NOT_MATCHED_RESTART_FROM_DESCENDANT
                  : NOT_MATCHED_GLOBALLY;
  next = (c->comb == COMB_NEXT || c->comb == COMB_LATER)
             ? prev_element(doc, id)
             : element_parent(doc, id);
  for (;;) {
    match_result r;
    if (next == ZUH_NONE)
      return not_found;
    r = match_complex(ctx, first, i - 1, next, scope);
    if (r == MATCHED || r == NOT_MATCHED_GLOBALLY || c->comb == COMB_NEXT)
      return r;
    if (c->comb == COMB_CHILD)
      return NOT_MATCHED_RESTART_FROM_DESCENDANT;
    if (r == NOT_MATCHED_RESTART_FROM_DESCENDANT && c->comb == COMB_LATER)
      return r;
    next = c->comb == COMB_LATER ? prev_element(doc, next)
                                 : element_parent(doc, next);
  }
}

int
zuh_selector_matches(zuh_match_ctx *ctx, zuh_id id, zuh_id scope) {
  size_t k;
  if (ctx->doc->nodes[id].type != ZUH_NODE_ELEMENT)
    return 0;
  for (k = 0; k < ctx->sel->ncx; k++) {
    const complex_sel *cx = &ctx->sel->cx[k];
    if (match_complex(ctx, cx->first, cx->count - 1, id, scope) == MATCHED)
      return 1;
    if (ctx->exceeded)
      return 0;
  }
  return 0;
}
