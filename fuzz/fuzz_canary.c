/* A target that must crash: tools/run-fuzz runs it first and fails if the
 * harness does not report the crash, so a green fuzz step always means a
 * crash would have been seen. */
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size);

int
LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  (void) data;
  if (size >= 1) {
    volatile char *p = (volatile char *) malloc(4);
    p[4] = 1; /* heap overflow */
    free((void *) p);
  }
  return 0;
}
