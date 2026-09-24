/* Drives the parse seam -- ledger, abort, depth limit, diagnostics -- with
 * no R in the way, for tools/run-sanitizers. Exits non-zero on any failed
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
  "<a href=\"http://example.org/?q=1&amp;r=2\">link</a><base href=/x/>"
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

static zuh_status
parse(const char *buf, size_t len, const zuh_parse_opts *o,
      zuh_parse_stats *stats, size_t *n_problems) {
  zuh_doc *doc = zuh_doc_new();
  zuh_status st;
  if (doc == NULL)
    exit(2);
  st = zuh_gumbo_parse(buf, len, o, doc, stats);
  if (st != ZUH_OK)
    EXPECT(doc->problems == NULL && doc->n_problems == 0,
           "a failed parse left diagnostics in the document");
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
  printf("    fault injection: %zu allocation sites over %zu documents\n",
         total, (size_t) N_CORPUS);
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

int
main(int argc, char **argv) {
  if (argc > 1 && strcmp(argv[1], "canary-overflow") == 0) {
    volatile char *p = (volatile char *) malloc(8);
    p[8] = 1; /* one past the end */
    free((void *) p);
    return 0;
  }
  if (argc > 1 && strcmp(argv[1], "canary-leak") == 0) {
    volatile void *p = malloc(64);
    p = NULL;
    (void) p;
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
