/* The per-parse allocation ledger. Pure C: no R headers.
 *
 * Every Gumbo allocation goes through zuh_ledger_alloc(). The ledger records
 * each block, enforces a byte budget, and on any failure long-jumps to the
 * jmp_buf the caller armed, so that Gumbo -- which does not check allocation
 * results -- never sees NULL. zuh_ledger_free_all() releases every recorded
 * block in one non-recursive pass; it is the only teardown path, on success
 * and on failure alike. See .agents/design.md section 12. */
#ifndef ZUH_MEMORY_H
#define ZUH_MEMORY_H

#include <setjmp.h>
#include <stddef.h>

#include "zuh_status.h"

typedef struct zuh_ledger {
  /* Armed by the caller around the abortable region; zuh_ledger_alloc()
   * long-jumps here with the status as the value. NULL outside it. */
  jmp_buf *abort_to;
  zuh_status status;     /* why the last abort happened */

  void **blocks;         /* live block headers, in no particular order */
  size_t count;
  size_t capacity;

  size_t live_bytes;     /* payload plus header bytes of live blocks */
  size_t peak_bytes;
  size_t max_bytes;      /* budget; exceeding it aborts */

  size_t n_allocs;       /* allocations requested so far */
  size_t fail_at;        /* fault injection: abort at this allocation
                            (1-based); 0 never */
  int corrupt;           /* a free named a block the ledger does not hold */
} zuh_ledger;

/* A heap-allocated ledger, so that nothing it holds is an automatic object
 * modified between setjmp() and longjmp(). NULL if malloc fails. */
zuh_ledger *zuh_ledger_new(size_t max_bytes, size_t fail_at);

/* GumboAllocatorFunction / GumboDeallocatorFunction; userdata is the
 * ledger. zuh_ledger_alloc() never returns NULL: it aborts instead. */
void *zuh_ledger_alloc(void *userdata, size_t size);
void zuh_ledger_free(void *userdata, void *ptr);

/* Free every live block, the block array and the ledger itself. */
void zuh_ledger_free_all(zuh_ledger *lg);

#endif
