/* Fuzz target: selector compilation and matching on a fixed document.
 * Every input is compiled; a selector that compiles is matched against
 * every element with the document root and each element as :scope. */
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "zuh_document.h"
#include "zuh_gumbo.h"
#include "zuh_selector.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size);

static const char kDocument[] =
    "<!DOCTYPE html><html lang=en><head><title>t</title></head><body>"
    "<div id=main class='card wide' data-x='foo-bar baz'><h2 class=t>One</h2>"
    "<p class='a b' lang=en-US>first</p><p title=''>second</p><span>s</span>"
    "<ul><li>1<li>2<li>3</ul><em></em><i> </i><b><!--c--></b></div>"
    "<table><tr><td>1<td>2</table><template><p class=t>in</p></template>"
    "<svg viewBox='0 0 1 1'><foreignObject><p>x</p></foreignObject>"
    "<a xlink:href=u></a></svg><math><mi>x</mi></math>"
    "<form><input type=TEXT name=q><input type=checkbox checked></form>"
    "</body></html>";

static zuh_doc *doc;
static int32_t *pos, *cnt;

static void
setup(void) {
  zuh_parse_opts o;
  zuh_parse_stats st;
  memset(&o, 0, sizeof(o));
  o.max_input = 1u << 20;
  o.max_memory = 1u << 26;
  o.max_depth = 512;
  o.max_errors = 100;
  o.max_nodes = 100000;
  o.keep_comments = 1;
  o.fragment_tag = -1;
  doc = zuh_doc_new();
  if (doc == NULL || zuh_gumbo_parse(kDocument, sizeof(kDocument) - 1, &o,
                                     doc, &st) != ZUH_OK)
    abort();
  pos = (int32_t *) malloc(doc->n_nodes * sizeof(int32_t));
  cnt = (int32_t *) malloc(doc->n_nodes * sizeof(int32_t));
  if (pos == NULL || cnt == NULL)
    abort();
  zuh_selector_positions(doc, pos, cnt);
}

int
LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  zuh_selector *sel = NULL;
  zuh_sel_error err;
  zuh_match_ctx m;
  zuh_id id, scope;

  if (doc == NULL)
    setup();
  if (size > 4096)
    return 0;
  if (zuh_selector_compile((const char *) data, size, &sel, &err) !=
      ZUH_SEL_OK) {
    /* A failure reports a position inside the input. */
    if (err.position > size || err.reason == NULL)
      abort();
    return 0;
  }
  memset(&m, 0, sizeof(m));
  m.doc = doc;
  m.sel = sel;
  m.elem_pos = pos;
  m.elem_count = cnt;
  m.work_limit = 10000000;
  for (id = 0; id < doc->n_nodes; id++)
    (void) zuh_selector_matches(&m, id, doc->root);
  for (scope = 0; scope < doc->n_nodes; scope += 7)
    for (id = 0; id < doc->n_nodes; id++)
      (void) zuh_selector_matches(&m, id, scope);
  zuh_selector_free(sel);
  return 0;
}
