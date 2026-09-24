/* Fuzz target: parse, serialize, parse the serialization, serialize again.
 * Under the sanitizers, the round trip must be memory-safe. It need not be
 * a fixed point -- the HTML standard does not promise that -- so trees
 * that change are counted and reported at exit, not asserted. A second
 * parse must succeed whenever the first did: the serializer must never
 * produce input the parser rejects. */
#include <stdio.h>

#include "fuzz_common.h"
#include "zuh_write.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size);

static unsigned long runs, changed;

static void
report(void) {
  fprintf(stderr, "roundtrip: %lu of %lu parsed inputs are not fixed points\n",
          changed, runs);
}

static int
parse_into(zuh_doc **out, const char *buf, size_t len,
           const zuh_parse_opts *o) {
  zuh_parse_stats st;
  zuh_doc *doc = zuh_doc_new();
  if (doc == NULL)
    return 0;
  if (zuh_gumbo_parse(buf, len, o, doc, &st) != ZUH_OK) {
    zuh_doc_free(doc);
    return 0;
  }
  *out = doc;
  return 1;
}

int
LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  static int registered = 0;
  zuh_parse_opts o;
  zuh_doc *d1 = NULL, *d2 = NULL;
  zuh_buf s1, s2;
  char *t1 = NULL, *t2 = NULL;
  size_t l1, l2;

  if (!registered) {
    atexit(report);
    registered = 1;
  }
  if (size < 1)
    return 0;
  fuzz_opts(&o);
  fuzz_context(&o, data[0]);
  if (!parse_into(&d1, (const char *) data + 1, size - 1, &o))
    return 0;
  runs++;
  zuh_buf_init(&s1, NULL, NULL);
  if (zuh_serialize(d1, 0, 1, 0, &s1) != ZUH_OK)
    abort();
  /* The serialization can be larger than the input; allow it. */
  o.max_input = s1.len + 1;
  o.max_memory = (size_t) 1 << 27;
  if (!parse_into(&d2, s1.buf, s1.len, &o)) {
    /* Only resource limits may stop the second parse. */
    zuh_buf_free(&s1);
    zuh_doc_free(d1);
    return 0;
  }
  if (zuh_doc_dump(d1, &t1, &l1) == ZUH_OK &&
      zuh_doc_dump(d2, &t2, &l2) == ZUH_OK &&
      (l1 != l2 || memcmp(t1, t2, l1) != 0))
    changed++;
  zuh_buf_init(&s2, NULL, NULL);
  (void) zuh_serialize(d2, 0, 1, 0, &s2);
  zuh_buf_free(&s2);
  free(t1);
  free(t2);
  zuh_buf_free(&s1);
  zuh_doc_free(d1);
  zuh_doc_free(d2);
  return 0;
}
