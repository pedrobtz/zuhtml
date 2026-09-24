/* The per-parse allocation ledger. See zuh_memory.h. */
#include <stdint.h>
#include <stdlib.h>

#include "zuh_memory.h"

/* Precedes every payload. The union keeps the payload aligned for any type
 * Gumbo stores in it. `index` is the block's slot in lg->blocks, which is
 * what makes a free O(1). */
typedef union zuh_header {
  struct {
    size_t size;
    size_t index;
  } h;
  long double align_ld;
  long long align_ll;
  void *align_p;
} zuh_header;

zuh_ledger *
zuh_ledger_new(size_t max_bytes, size_t fail_at) {
  zuh_ledger *lg = (zuh_ledger *) calloc(1, sizeof(zuh_ledger));
  if (lg == NULL)
    return NULL;
  lg->abort_to = NULL;
  lg->status = ZUH_OK;
  lg->blocks = NULL;
  lg->max_bytes = max_bytes;
  lg->fail_at = fail_at;
  return lg;
}

static void
ledger_abort(zuh_ledger *lg, zuh_status why) {
  lg->status = why;
  /* Only ever called with the region armed: zuh_gumbo_parse() arms it
   * before Gumbo can allocate and disarms it after Gumbo returns. */
  longjmp(*lg->abort_to, 1);
}

void *
zuh_ledger_alloc(void *userdata, size_t size) {
  zuh_ledger *lg = (zuh_ledger *) userdata;
  zuh_header *hdr;
  size_t total;

  lg->n_allocs++;
  if (lg->fail_at != 0 && lg->n_allocs == lg->fail_at)
    ledger_abort(lg, ZUH_LIMIT_MEMORY);

  /* Checked arithmetic: header plus payload, then against the budget. */
  if (size > SIZE_MAX - sizeof(zuh_header))
    ledger_abort(lg, ZUH_LIMIT_MEMORY);
  total = sizeof(zuh_header) + size;
  if (total > lg->max_bytes || lg->live_bytes > lg->max_bytes - total)
    ledger_abort(lg, ZUH_LIMIT_MEMORY);

  /* Grow the block array before allocating the block, so that a failure
   * here leaves nothing unrecorded. */
  if (lg->count == lg->capacity) {
    size_t cap = lg->capacity ? lg->capacity * 2 : 256;
    void **grown;
    if (cap < lg->capacity || cap > SIZE_MAX / sizeof(void *))
      ledger_abort(lg, ZUH_LIMIT_MEMORY);
    grown = (void **) realloc(lg->blocks, cap * sizeof(void *));
    if (grown == NULL)
      ledger_abort(lg, ZUH_LIMIT_MEMORY);
    lg->blocks = grown;
    lg->capacity = cap;
  }

  hdr = (zuh_header *) malloc(total);
  if (hdr == NULL)
    ledger_abort(lg, ZUH_LIMIT_MEMORY);
  hdr->h.size = size;
  hdr->h.index = lg->count;
  lg->blocks[lg->count++] = hdr;
  lg->live_bytes += total;
  if (lg->live_bytes > lg->peak_bytes)
    lg->peak_bytes = lg->live_bytes;
  return hdr + 1;
}

void
zuh_ledger_free(void *userdata, void *ptr) {
  zuh_ledger *lg = (zuh_ledger *) userdata;
  zuh_header *hdr;
  size_t i;

  if (ptr == NULL)
    return;
  hdr = (zuh_header *) ptr - 1;
  i = hdr->h.index;
  /* A double free or a foreign pointer. Leave the block alone -- bulk free
   * releases whatever the ledger does hold -- and report it. */
  if (i >= lg->count || lg->blocks[i] != (void *) hdr) {
    lg->corrupt = 1;
    return;
  }
  lg->live_bytes -= sizeof(zuh_header) + hdr->h.size;
  lg->count--;
  if (i != lg->count) {
    zuh_header *last = (zuh_header *) lg->blocks[lg->count];
    lg->blocks[i] = last;
    last->h.index = i;
  }
  free(hdr);
}

void
zuh_ledger_free_all(zuh_ledger *lg) {
  size_t i;
  if (lg == NULL)
    return;
  for (i = 0; i < lg->count; i++)
    free(lg->blocks[i]);
  free(lg->blocks);
  free(lg);
}
