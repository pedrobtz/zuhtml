/* See zuh_buf.h. */
#include <stdlib.h>
#include <string.h>

#include "zuh_buf.h"

void
zuh_buf_init(zuh_buf *b, zuh_alloc_fn alloc, void *userdata) {
  b->buf = NULL;
  b->len = 0;
  b->cap = 0;
  b->failed = 0;
  b->alloc = alloc;
  b->userdata = userdata;
  zuh_buf_put(b, "", 0);
}

void
zuh_buf_put(zuh_buf *b, const char *s, size_t n) {
  if (b->failed)
    return;
  if (n > (size_t) -1 - b->len - 1) {
    b->failed = 1;
    return;
  }
  if (b->buf == NULL || b->len + n + 1 > b->cap) {
    size_t cap = b->cap ? b->cap : 256;
    char *grown;
    while (cap < b->len + n + 1) {
      if (cap > (size_t) -1 / 2) {
        b->failed = 1;
        return;
      }
      cap *= 2;
    }
    if (b->alloc != NULL) {
      grown = (char *) b->alloc(b->userdata, cap);
      if (grown != NULL && b->buf != NULL)
        memcpy(grown, b->buf, b->len);
    } else {
      grown = (char *) realloc(b->buf, cap);
    }
    if (grown == NULL) {
      b->failed = 1;
      return;
    }
    b->buf = grown;
    b->cap = cap;
  }
  if (n > 0)
    memcpy(b->buf + b->len, s, n);
  b->len += n;
  b->buf[b->len] = '\0';
}

void
zuh_buf_str(zuh_buf *b, const char *s) {
  zuh_buf_put(b, s, strlen(s));
}

void
zuh_buf_free(zuh_buf *b) {
  if (b->alloc == NULL)
    free(b->buf);
  b->buf = NULL;
  b->len = b->cap = 0;
}
