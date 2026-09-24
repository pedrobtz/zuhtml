/* Fuzz target: the whole C pipeline on one input. The first byte picks a
 * fragment context (or a document); the rest is parsed under small limits
 * through the allocation ledger and converted. On success every node is
 * rendered, serialized and cleaned, every table's grid is built, and a
 * few selectors are matched. */
#include "fuzz_common.h"
#include "zuh_markdown.h"
#include "zuh_selector.h"
#include "zuh_table.h"
#include "zuh_text.h"
#include "zuh_write.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size);

static const char *const kSelectors[] = {
  "*", "div p", "td:nth-child(2n+1)", "a[href^=http]", ":not(p) > span",
  "li:first-child ~ li", ":empty", "[class~=x]"};

int
LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  zuh_parse_opts o;
  zuh_parse_stats st;
  zuh_doc *doc;
  zuh_id id;
  size_t k;

  if (size < 1)
    return 0;
  fuzz_opts(&o);
  fuzz_context(&o, data[0]);
  doc = zuh_doc_new();
  if (doc == NULL)
    return 0;
  if (zuh_gumbo_parse((const char *) data + 1, size - 1, &o, doc, &st) !=
      ZUH_OK) {
    zuh_doc_free(doc);
    return 0;
  }
  {
    char *dump;
    size_t len;
    if (zuh_doc_dump(doc, &dump, &len) == ZUH_OK)
      free(dump);
  }
  for (id = 0; id < doc->n_nodes; id++) {
    zuh_clean_opts co = {1, 1, (int) (id & 1), (int) ((id >> 1) & 1)};
    zuh_buf b;
    zuh_buf_init(&b, NULL, NULL);
    (void) zuh_serialize(doc, id, (int) (id & 1), (int) ((id >> 1) & 1), &b);
    zuh_buf_free(&b);
    zuh_buf_init(&b, NULL, NULL);
    (void) zuh_text_clean(doc, id, &co, &b);
    zuh_buf_free(&b);
    zuh_buf_init(&b, NULL, NULL);
    (void) zuh_markdown(doc, id, NULL, &b);
    zuh_buf_free(&b);
    if (doc->nodes[id].type == ZUH_NODE_ELEMENT &&
        strcmp(zuh_str(doc, doc->nodes[id].name), "table") == 0) {
      fuzz_arena a = {NULL, 0, 0};
      zuh_table t;
      (void) zuh_table_grid(doc, id, 100000, fuzz_arena_alloc, &a, &t);
      fuzz_arena_release(&a);
    }
  }
  {
    int32_t *pos = (int32_t *) malloc((doc->n_nodes + 1) * sizeof(int32_t));
    int32_t *cnt = (int32_t *) malloc((doc->n_nodes + 1) * sizeof(int32_t));
    if (pos != NULL && cnt != NULL) {
      zuh_selector_positions(doc, pos, cnt);
      for (k = 0; k < sizeof(kSelectors) / sizeof(kSelectors[0]); k++) {
        zuh_selector *sel;
        zuh_sel_error err;
        zuh_match_ctx m;
        if (zuh_selector_compile(kSelectors[k], strlen(kSelectors[k]), &sel,
                                 &err) != ZUH_SEL_OK)
          abort();
        memset(&m, 0, sizeof(m));
        m.doc = doc;
        m.sel = sel;
        m.elem_pos = pos;
        m.elem_count = cnt;
        m.work_limit = 1000000;
        for (id = 0; id < doc->n_nodes; id++)
          (void) zuh_selector_matches(&m, id, doc->root);
        zuh_selector_free(sel);
      }
    }
    free(pos);
    free(cnt);
  }
  zuh_doc_free(doc);
  return 0;
}
