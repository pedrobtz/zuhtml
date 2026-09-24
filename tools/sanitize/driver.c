/* Drives the C core -- ledger, abort, limits, conversion into the frozen
 * document, the tree dump, the serializer, cleaned text and table grids --
 * with no R in the way, for tools/run-sanitizers. Exits non-zero on any failed
 * expectation; ASan, UBSan and (on Linux) LeakSanitizer report the rest.
 *
 *   driver                 the gate
 *   driver canary-overflow a heap overflow ASan must report
 *   driver canary-leak     a leak LeakSanitizer must report */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "zuh_document.h"
#include "zuh_gumbo.h"
#include "zuh_table.h"
#include "zuh_text.h"
#include "zuh_write.h"

static int failures = 0;

#define EXPECT(cond, ...)                                                   \
  do {                                                                      \
    if (!(cond)) {                                                          \
      fprintf(stderr, "FAIL %s:%d: ", __FILE__, __LINE__);                  \
      fprintf(stderr, __VA_ARGS__);                                         \
      fputc('\n', stderr);                                                  \
      failures++;                                                           \
    }                                                                       \
  } while (0)

static const zuh_parse_opts defaults = {
  16u << 20,          /* max_input */
  (size_t) 512 << 20, /* max_memory */
  512,                /* max_depth */
  100,                /* max_errors */
  4000000,            /* max_nodes */
  1,                  /* keep_comments */
  -1,                 /* fragment_tag */
  0,                  /* fragment_ns */
  0                   /* fail_at */
};

/* A small corpus that reaches the parser's main paths: implied elements,
 * the adoption agency, foster parenting, character references, foreign
 * content, templates, comments, doctypes and many tokenizer errors. */
static const char *const corpus[] = {
  "",
  "<p>Hello",
  "<!DOCTYPE html><html><head><title>t</title></head><body><p>x</p></body></html>",
  "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01//EN\"><p>quirks?",
  "<b><i>misnested</b></i><a><p>x</a>y",
  "<table><tr><td>1<td>2</tr>foster<tr><td colspan=2>3</table>",
  "&amp;&lt;&notanentity;&#x41;&#0;&#xD800;&nbsp",
  "<svg><circle r=1/><foreignObject><p>html</p></foreignObject></svg>",
  "<math><mi>x</mi></math>",
  "<template><tr><td>t</td></tr></template><select><option>a<option>b</select>",
  "<!-- c --><!--> <!---> <!-- a -- b --!> <?pi x?>",
  "<p id=a id=b class='c' data-x=\"y\" disabled>attrs",
  "<script>if (a < b) { x = '</scr' + 'ipt>'; }</script><style>p{}</style>",
  "<textarea>\n raw & text</textarea><pre>\n\npre</pre><plaintext><b>",
  "<ul><li>one<li>two<ul><li>nested</ul></ul><dl><dt>t<dd>d</dl>",
  "<frameset><frame></frameset>",
  "</p></br><br/><img src=x /><input type=hidden><",
  "<a href=\"http://example.org/?q=1&amp;r=2\">link</a><base href=/x/>",
  "<table><thead><tr><th rowspan=0>h<th colspan=3>k</thead><tr><td>1<td"
  " rowspan=2 colspan=2>2<tr><td>3<td>4<td>5<tfoot><tr><td colspan=0>f"
  "</tfoot></table>",
  "<table><tr><td>a<td rowspan=2>b<tr><td colspan=2>overlap</table>",
  "<table><tr><td colspan=' +7x'>w<td rowspan=70000>r<tr></table>"
  "<ul><li>a<div><ul><li>b</ul></div>c<li>d</ul>",
  /* Gumbo 0.14.0 freed an option inside <selectedcontent> and read it
   * again (tools/patches/0004-selectedcontent-descendant.patch). */
  "<selectedcontent><option>a<option selected>b",
  "<selectedcontent><div><option>a<option selected>b</div>c",
  "<select><button><selectedcontent></selectedcontent></button>"
  "<option>a<option selected>b<option>c</select>",
  /* ... and dereferenced NULL on a stray </selectedcontent>
   * (tools/patches/0005-selectedcontent-end-tag.patch). */
  "<p>x</selectedcontent>y",
  "</selectedcontent><table><tr><td></selectedcontent>"
};
#define N_CORPUS (sizeof(corpus) / sizeof(corpus[0]))

static char *
repeat(const char *unit, size_t n, size_t *len) {
  size_t ul = strlen(unit), i;
  char *b = (char *) malloc(n * ul + 1);
  if (b == NULL) {
    fprintf(stderr, "out of memory building a probe input\n");
    exit(2);
  }
  for (i = 0; i < n; i++)
    memcpy(b + i * ul, unit, ul);
  b[n * ul] = '\0';
  *len = n * ul;
  return b;
}

/* Walk every node of a frozen document and check the links agree: each
 * child names its parent, siblings point at each other, IDs are preorder
 * and subtree_end bounds the descendants. Returns the number of nodes
 * reached. */
static size_t
check_links(const zuh_doc *doc) {
  zuh_id id;
  size_t reached = 0;
  for (id = 0; id < doc->n_nodes; id++) {
    const zuh_node *n = &doc->nodes[id];
    zuh_id c, prev = ZUH_NONE, expect = id + 1;
    reached++;
    EXPECT(n->subtree_end >= id && n->subtree_end < doc->n_nodes,
           "node %u: subtree_end %u out of range", id, n->subtree_end);
    for (c = n->first_child; c != ZUH_NONE; c = doc->nodes[c].next_sibling) {
      EXPECT(c == expect, "node %u: child %u is not in preorder", id, c);
      EXPECT(doc->nodes[c].parent == id, "node %u: child %u has parent %u",
             id, c, doc->nodes[c].parent);
      EXPECT(doc->nodes[c].prev_sibling == prev,
             "node %u: child %u has the wrong previous sibling", id, c);
      prev = c;
      expect = doc->nodes[c].subtree_end + 1;
    }
    EXPECT(n->last_child == prev, "node %u: last_child is wrong", id);
    EXPECT(expect - 1 == n->subtree_end || n->first_child == ZUH_NONE,
           "node %u: children do not end at subtree_end", id);
    EXPECT(n->attr_start + n->attr_count <= doc->n_attrs,
           "node %u: attributes out of range", id);
    EXPECT(n->name < doc->pool_len && n->value < doc->pool_len,
           "node %u: string offsets out of range", id);
  }
  return reached;
}

/* An allocator standing in for R_alloc: blocks are recorded and freed
 * together by arena_release(). */
typedef struct {
  void **blocks;
  size_t n, cap;
} arena;

static void *
arena_alloc(void *userdata, size_t size) {
  arena *a = (arena *) userdata;
  void *p;
  if (a->n == a->cap) {
    size_t cap = a->cap ? a->cap * 2 : 64;
    void **grown = (void **) realloc(a->blocks, cap * sizeof(void *));
    if (grown == NULL)
      return NULL;
    a->blocks = grown;
    a->cap = cap;
  }
  p = malloc(size ? size : 1);
  if (p != NULL)
    a->blocks[a->n++] = p;
  return p;
}

static void
arena_release(arena *a) {
  size_t i;
  for (i = 0; i < a->n; i++)
    free(a->blocks[i]);
  free(a->blocks);
  a->blocks = NULL;
  a->n = a->cap = 0;
}

/* An arena whose k-th allocation fails: for injecting failures into the
 * paths that build output through an allocator callback. */
typedef struct {
  arena a;
  size_t calls, fail_at;
} failing_arena;

static void *
failing_alloc(void *userdata, size_t size) {
  failing_arena *f = (failing_arena *) userdata;
  if (++f->calls == f->fail_at)
    return NULL;
  return arena_alloc(&f->a, size);
}

static size_t buffer_sites;

/* Fail every allocation of the serializer, the text cleaner and the table
 * grid in turn: each must report ZUH_LIMIT_MEMORY (and the arena frees
 * everything, so LeakSanitizer sees any stray malloc). */
static void
buffer_fault_injection(const zuh_doc *doc) {
  zuh_id id;
  size_t total = 0;
  for (id = 0; id < doc->n_nodes; id++) {
    const zuh_node *n = &doc->nodes[id];
    int kind;
    for (kind = 0; kind < 3; kind++) {
      size_t k;
      if (kind == 2 && !(n->type == ZUH_NODE_ELEMENT &&
                         strcmp(zuh_str(doc, n->name), "table") == 0))
        continue;
      for (k = 1;; k++) {
        failing_arena f;
        zuh_status st;
        memset(&f, 0, sizeof(f));
        f.fail_at = k;
        if (kind == 2) {
          zuh_table t;
          st = zuh_table_grid(doc, id, 1e6, failing_alloc, &f, &t);
        } else {
          zuh_buf b;
          zuh_clean_opts o = {1, 1, 0, 0};
          zuh_buf_init(&b, failing_alloc, &f);
          st = kind == 0 ? zuh_serialize(doc, id, 1, 0, &b)
                         : zuh_text_clean(doc, id, &o, &b);
        }
        arena_release(&f.a);
        if (f.calls < k) {
          /* No allocation failed: any outcome but a memory error (an
           * overlapping table is one). */
          EXPECT(st != ZUH_LIMIT_MEMORY,
                 "node %u kind %d: out of memory with no failure", id, kind);
          break;
        }
        EXPECT(st == ZUH_LIMIT_MEMORY,
               "node %u kind %d, failing allocation %zu: status %d", id,
               kind, k, (int) st);
        total++;
      }
    }
  }
  buffer_sites += total;
}

/* Cleaned text of every node under each option set, and the grid of every
 * table, under ASan. */
static void
extract_all(const zuh_doc *doc) {
  zuh_id id;
  int k;
  for (id = 0; id < doc->n_nodes; id++) {
    const zuh_node *n = &doc->nodes[id];
    for (k = 0; k < 16; k++) {
      zuh_clean_opts o;
      zuh_buf b;
      o.trim = k & 1;
      o.nbsp = (k >> 1) & 1;
      o.skip_lists = (k >> 2) & 1;
      o.skip_tables = (k >> 3) & 1;
      zuh_buf_init(&b, NULL, NULL);
      EXPECT(zuh_text_clean(doc, id, &o, &b) == ZUH_OK &&
                 strlen(b.buf) == b.len,
             "cleaning node %u failed", id);
      zuh_buf_free(&b);
    }
    if (n->type == ZUH_NODE_ELEMENT && n->ns == ZUH_NS_HTML &&
        strcmp(zuh_str(doc, n->name), "table") == 0) {
      static const double caps[] = {1e6, 4, 0};
      size_t c;
      for (c = 0; c < sizeof(caps) / sizeof(caps[0]); c++) {
        arena a = {NULL, 0, 0};
        zuh_table t;
        zuh_status st = zuh_table_grid(doc, id, caps[c], arena_alloc, &a, &t);
        EXPECT(st == ZUH_OK || st == ZUH_LIMIT_TABLE ||
                   st == ZUH_ERR_TABLE_OVERLAP,
               "table %u: status %d", id, (int) st);
        if (st == ZUH_OK) {
          size_t s2;
          for (s2 = 0; s2 < (size_t) t.nrows * t.ncols; s2++)
            EXPECT(t.slot[s2] >= -1 && t.slot[s2] < (int32_t) t.ncells,
                   "table %u: slot out of range", id);
        }
        arena_release(&a);
      }
    }
  }
}

/* Serialize every node, outer and inner, and parse the document's
 * serialization again: the serializer and a second parse under ASan. Only
 * for small documents, and not recursively. */
static int reparsing = 0;

static zuh_status parse(const char *buf, size_t len, const zuh_parse_opts *o,
                        zuh_parse_stats *stats, size_t *n_problems);

static void
serialize_all(const zuh_doc *doc, const zuh_parse_opts *o) {
  zuh_id id;
  if (doc->n_nodes > 2000 || reparsing)
    return;
  for (id = 0; id < doc->n_nodes; id++) {
    int outer;
    for (outer = 0; outer < 4; outer++) {
      zuh_buf b;
      zuh_buf_init(&b, NULL, NULL);
      EXPECT(zuh_serialize(doc, id, outer & 1, outer >> 1, &b) == ZUH_OK &&
                 b.buf != NULL &&
                 strlen(b.buf) == b.len,
             "serializing node %u failed", id);
      zuh_buf_free(&b);
    }
  }
  {
    zuh_buf b;
    zuh_buf_init(&b, NULL, NULL);
    if (zuh_serialize(doc, 0, 1, 0, &b) == ZUH_OK) {
      zuh_parse_opts again = *o;
      zuh_parse_stats stats;
      again.fail_at = 0;
      reparsing = 1;
      EXPECT(parse(b.buf, b.len, &again, &stats, NULL) == ZUH_OK,
             "the serialization did not parse again");
      reparsing = 0;
    }
    zuh_buf_free(&b);
  }
}

static zuh_status
parse(const char *buf, size_t len, const zuh_parse_opts *o,
      zuh_parse_stats *stats, size_t *n_problems) {
  zuh_doc *doc = zuh_doc_new();
  zuh_status st;
  if (doc == NULL)
    exit(2);
  st = zuh_gumbo_parse(buf, len, o, doc, stats);
  if (st != ZUH_OK) {
    EXPECT(doc->problems == NULL && doc->n_problems == 0 &&
               doc->nodes == NULL && doc->n_nodes == 0,
           "a failed parse left data in the document");
  } else {
    char *dump;
    size_t dlen;
    EXPECT(check_links(doc) == doc->n_nodes, "not every node was reached");
    EXPECT(zuh_doc_dump(doc, &dump, &dlen) == ZUH_OK && dump != NULL &&
               strlen(dump) == dlen,
           "the tree dump failed");
    free(dump);
    serialize_all(doc, o);
    if (!reparsing && doc->n_nodes <= 2000) {
      extract_all(doc);
      if (o->fail_at == 0)
        buffer_fault_injection(doc);
    }
  }
  if (n_problems != NULL)
    *n_problems = doc->n_problems;
  zuh_doc_free(doc);
  return st;
}

/* Fail every allocation index in turn. Each run must abort with
 * ZUH_LIMIT_MEMORY and free everything; LeakSanitizer checks the latter at
 * exit. */
static void
fault_injection(void) {
  size_t i, total = 0;
  for (i = 0; i < N_CORPUS; i++) {
    const char *s = corpus[i];
    zuh_parse_opts o = defaults;
    zuh_parse_stats stats;
    size_t k, n;
    zuh_status st = parse(s, strlen(s), &o, &stats, NULL);
    EXPECT(st == ZUH_OK, "corpus[%zu] did not parse (status %d)", i, (int) st);
    n = stats.n_allocs;
    for (k = 1; k <= n; k++) {
      o.fail_at = k;
      st = parse(s, strlen(s), &o, &stats, NULL);
      EXPECT(st == ZUH_LIMIT_MEMORY,
             "corpus[%zu], failing allocation %zu of %zu: status %d", i, k, n,
             (int) st);
    }
    total += n;
  }
  /* The same, parsing each document as a fragment in a table context and
   * in a foreign one. */
  for (i = 0; i < N_CORPUS; i++) {
    static const char *const contexts[] = {"tbody", "svg"};
    size_t c;
    for (c = 0; c < 2; c++) {
      const char *s = corpus[i];
      zuh_parse_opts o = defaults;
      zuh_parse_stats stats;
      size_t k, n;
      zuh_status st;
      o.fragment_tag = zuh_gumbo_tag_lookup(contexts[c], 0);
      o.fragment_ns = c == 1 ? ZUH_NS_SVG : ZUH_NS_HTML;
      EXPECT(o.fragment_tag >= 0, "no tag for context %s", contexts[c]);
      st = parse(s, strlen(s), &o, &stats, NULL);
      EXPECT(st == ZUH_OK, "corpus[%zu] as a %s fragment: status %d", i,
             contexts[c], (int) st);
      n = stats.n_allocs;
      for (k = 1; k <= n; k++) {
        o.fail_at = k;
        st = parse(s, strlen(s), &o, &stats, NULL);
        EXPECT(st == ZUH_LIMIT_MEMORY,
               "corpus[%zu] as a %s fragment, failing allocation %zu: %d", i,
               contexts[c], k, (int) st);
      }
      total += n;
    }
  }
  printf("    fault injection: %zu allocation sites over %zu documents, "
         "each also as two fragments; %zu in output buffers\n",
         total, (size_t) N_CORPUS, buffer_sites);
}

static double
seconds(clock_t t0) {
  return (double) (clock() - t0) / CLOCKS_PER_SEC;
}

static void
limits(void) {
  zuh_parse_opts o = defaults;
  zuh_parse_stats stats;
  size_t len, np;
  char *buf;
  clock_t t0;
  zuh_status st;

  /* Quadratic in depth without the patch: 16 s for this input. */
  buf = repeat("<div>", 100000, &len);
  t0 = clock();
  st = parse(buf, len, &o, &stats, NULL);
  EXPECT(st == ZUH_LIMIT_DEPTH, "deep 100000: status %d", (int) st);
  printf("    deep 100000 -> limit_depth in %.3f s\n", seconds(t0));
  free(buf);

  /* The adoption agency on an ever-growing stack. */
  buf = repeat("<a><b>", 20000, &len);
  t0 = clock();
  st = parse(buf, len, &o, &stats, NULL);
  EXPECT(st == ZUH_LIMIT_DEPTH, "aaa 20000: status %d", (int) st);
  printf("    aaa 20000 -> limit_depth in %.3f s\n", seconds(t0));
  free(buf);

  buf = repeat("<p>x</p>", 1000, &len);
  o = defaults;
  o.max_input = len - 1;
  st = parse(buf, len, &o, &stats, NULL);
  EXPECT(st == ZUH_LIMIT_INPUT && stats.observed == len,
         "max_input: status %d", (int) st);

  o = defaults;
  o.max_memory = 4096;
  st = parse(buf, len, &o, &stats, NULL);
  EXPECT(st == ZUH_LIMIT_MEMORY, "max_memory: status %d", (int) st);

  /* 1000 paragraphs of an element and a text node each, plus html, head,
   * body and the document: 2004 nodes. */
  o = defaults;
  o.max_nodes = 2003;
  st = parse(buf, len, &o, &stats, NULL);
  EXPECT(st == ZUH_LIMIT_NODES && stats.observed == 2004,
         "max_nodes: status %d, observed %zu", (int) st, stats.observed);
  o.max_nodes = 2004;
  st = parse(buf, len, &o, &stats, NULL);
  EXPECT(st == ZUH_OK, "max_nodes at the count: status %d", (int) st);
  free(buf);

  /* Diagnostics are truncated at max_errors, and parsing continues. */
  buf = repeat("</x>", 50, &len);
  o = defaults;
  o.max_errors = 10;
  st = parse(buf, len, &o, &stats, &np);
  EXPECT(st == ZUH_OK && np == 10, "max_errors: status %d, kept %zu",
         (int) st, np);
  o.max_errors = 0;
  st = parse(buf, len, &o, &stats, &np);
  EXPECT(st == ZUH_OK && np == 0, "max_errors 0: status %d, kept %zu",
         (int) st, np);
  free(buf);
}

/* 16 MiB of sawtooth nesting under the default caps. */
static void
sawtooth(void) {
  zuh_parse_opts o = defaults;
  zuh_parse_stats stats;
  size_t l1, l2, len, n;
  char *open = repeat("<div>", 500, &l1);
  char *close = repeat("</div>", 500, &l2);
  char *tooth = (char *) malloc(l1 + l2 + 1);
  char *buf;
  clock_t t0;
  zuh_status st;

  memcpy(tooth, open, l1);
  memcpy(tooth + l1, close, l2);
  tooth[l1 + l2] = '\0';
  n = (16u << 20) / (l1 + l2);
  buf = repeat(tooth, n, &len);
  t0 = clock();
  st = parse(buf, len, &o, &stats, NULL);
  EXPECT(st == ZUH_OK, "sawtooth: status %d", (int) st);
  printf("    sawtooth %zu bytes -> ok in %.3f s, peak %zu bytes\n", len,
         seconds(t0), stats.peak_bytes);
  free(open);
  free(close);
  free(tooth);
  free(buf);
}

/* The leak canary allocates in a frame that has returned, then overwrites
 * the stack, so that no stale copy of the pointer is left for
 * LeakSanitizer's conservative scan to find. A pointer kept in main's own
 * frame or registers can survive -O1 and make the leak look reachable. */
static void *volatile leak_sink;

__attribute__((noinline)) static void
leak_one(void) {
  leak_sink = malloc(64);
  leak_sink = NULL;
}

__attribute__((noinline)) static void
scrub_stack(void) {
  volatile char pad[4096];
  size_t i;
  for (i = 0; i < sizeof(pad); i++)
    pad[i] = 0;
}

int
main(int argc, char **argv) {
  if (argc > 1 && strcmp(argv[1], "canary-overflow") == 0) {
    volatile char *p = (volatile char *) malloc(8);
    p[8] = 1; /* one past the end */
    free((void *) p);
    return 0;
  }
  if (argc > 1 && strcmp(argv[1], "canary-leak") == 0) {
    int i;
    for (i = 0; i < 16; i++)
      leak_one();
    scrub_stack();
    return 0;
  }

  EXPECT(zuh_gumbo_selftest(), "parser self-test failed");
  EXPECT(zuh_gumbo_depth_selftest(), "depth self-test failed");
  fault_injection();
  limits();
  sawtooth();

  if (failures) {
    fprintf(stderr, "%d expectation(s) failed\n", failures);
    return 1;
  }
  return 0;
}
