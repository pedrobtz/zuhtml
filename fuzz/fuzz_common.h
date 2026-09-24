/* Shared by the parse and round-trip fuzz targets. */
#ifndef ZUH_FUZZ_COMMON_H
#define ZUH_FUZZ_COMMON_H

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "zuh_document.h"
#include "zuh_gumbo.h"

/* Limits small enough that a fuzz input cannot run long, large enough that
 * the interesting paths run. */
static void
fuzz_opts(zuh_parse_opts *o) {
  memset(o, 0, sizeof(*o));
  o->max_input = 1u << 16;
  o->max_memory = 1u << 25;
  o->max_depth = 256;
  o->max_errors = 50;
  o->max_nodes = 50000;
  o->keep_comments = 1;
  o->fragment_tag = -1;
}

/* A fragment context chosen by one input byte, or none. */
static void
fuzz_context(zuh_parse_opts *o, uint8_t b) {
  static const char *const contexts[] = {"div", "tbody", "tr", "select",
                                         "template", "svg", "math", "td",
                                         "textarea", "script", "table"};
  size_t n = sizeof(contexts) / sizeof(contexts[0]);
  if ((b & 1) == 0)
    return;
  b = (uint8_t) (b >> 1);
  o->fragment_tag = zuh_gumbo_tag_lookup(contexts[b % n], 0);
  o->fragment_ns = b % n == 5 ? ZUH_NS_SVG : b % n == 6 ? ZUH_NS_MATHML
                                                        : ZUH_NS_HTML;
}

/* An allocator that frees everything it handed out in one call. */
typedef struct {
  void **blocks;
  size_t n, cap;
} fuzz_arena;

static void *
fuzz_arena_alloc(void *userdata, size_t size) {
  fuzz_arena *a = (fuzz_arena *) userdata;
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
fuzz_arena_release(fuzz_arena *a) {
  size_t i;
  for (i = 0; i < a->n; i++)
    free(a->blocks[i]);
  free(a->blocks);
  a->blocks = NULL;
  a->n = a->cap = 0;
}

#endif
