/* A growable byte buffer for the pure-C core. Pure C: no R headers.
 *
 * With an allocator callback, growth allocates a new block through it and
 * never frees the old one: the R glue passes an R_alloc-backed callback,
 * so an R allocation failure while the buffer is live strands no malloc
 * memory. Without one, it uses realloc and zuh_buf_free(). */
#ifndef ZUH_BUF_H
#define ZUH_BUF_H

#include <stddef.h>

typedef void *(*zuh_alloc_fn)(void *userdata, size_t n);

typedef struct {
  char *buf;     /* NUL-terminated after any successful put */
  size_t len;
  size_t cap;
  int failed;    /* an allocation failed; the content is incomplete */
  zuh_alloc_fn alloc;
  void *userdata;
} zuh_buf;

void zuh_buf_init(zuh_buf *b, zuh_alloc_fn alloc, void *userdata);
void zuh_buf_put(zuh_buf *b, const char *s, size_t n);
void zuh_buf_str(zuh_buf *b, const char *s);
/* Frees a realloc-backed buffer; a callback-backed one is its owner's. */
void zuh_buf_free(zuh_buf *b);

#endif
