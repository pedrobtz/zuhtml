/* Version-specific adapter over the vendored Gumbo. See zuh_gumbo.h.
 *
 * Gumbo memory is never released with gumbo_destroy_output(), which recurses
 * once per nesting level. Every allocation goes through an allocator that
 * records the block, and teardown frees all recorded blocks in one pass.
 * Stage 1 uses a small block list for the self-tests below; the per-parse
 * ledger with a memory budget and abort replaces it at Stage 2. */
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include "gumbo.h"
#include "zuh_gumbo.h"

/* tools/verify-vendor checks this against src/vendor/PROVENANCE. */
#define ZUH_GUMBO_VERSION "0.14.0"

static const char *const zuh_patch_ids[] = {
  "0001-max-tree-depth",
  "0002-no-stdio",
  "0003-modification-notices"
};

const char *
zuh_gumbo_version(void) {
  return ZUH_GUMBO_VERSION;
}

int
zuh_gumbo_patches(const char *const **ids) {
  *ids = zuh_patch_ids;
  return (int) (sizeof(zuh_patch_ids) / sizeof(zuh_patch_ids[0]));
}

/* A doubly linked list of live blocks. The union keeps the payload aligned
 * for any type Gumbo stores in it. */
typedef union zuh_block {
  struct {
    union zuh_block *prev;
    union zuh_block *next;
  } link;
  long double align_ld;
  long long align_ll;
  void *align_p;
} zuh_block;

typedef struct {
  zuh_block *head;
  int failed;
} zuh_blocks;

static void *
blocks_alloc(void *userdata, size_t size) {
  zuh_blocks *bl = (zuh_blocks *) userdata;
  zuh_block *b;
  if (size > (size_t) -1 - sizeof(zuh_block)) {
    bl->failed = 1;
    return NULL;
  }
  b = (zuh_block *) malloc(sizeof(zuh_block) + size);
  if (b == NULL) {
    /* Gumbo does not check allocation results, so a NULL here would be
     * dereferenced. The self-tests allocate a few kilobytes; the Stage 2
     * ledger turns this case into an abort. */
    bl->failed = 1;
    return NULL;
  }
  b->link.prev = NULL;
  b->link.next = bl->head;
  if (bl->head != NULL)
    bl->head->link.prev = b;
  bl->head = b;
  return b + 1;
}

static void
blocks_free(void *userdata, void *ptr) {
  zuh_blocks *bl = (zuh_blocks *) userdata;
  zuh_block *b;
  if (ptr == NULL)
    return;
  b = (zuh_block *) ptr - 1;
  if (b->link.prev != NULL)
    b->link.prev->link.next = b->link.next;
  else
    bl->head = b->link.next;
  if (b->link.next != NULL)
    b->link.next->link.prev = b->link.prev;
  free(b);
}

static void
blocks_release(zuh_blocks *bl) {
  zuh_block *b = bl->head;
  while (b != NULL) {
    zuh_block *next = b->link.next;
    free(b);
    b = next;
  }
  bl->head = NULL;
}

static GumboOutput *
parse_with_blocks(zuh_blocks *bl, const char *buf, size_t len,
                  unsigned int max_depth) {
  GumboOptions opt = kGumboDefaultOptions;
  opt.allocator = blocks_alloc;
  opt.deallocator = blocks_free;
  opt.userdata = bl;
  opt.max_tree_depth = max_depth;
  return gumbo_parse_with_options(&opt, buf, len);
}

int
zuh_gumbo_selftest(void) {
  static const char doc[] = "<!DOCTYPE html><title>t</title><p class=x>hi";
  zuh_blocks bl = {NULL, 0};
  GumboOutput *out = parse_with_blocks(&bl, doc, sizeof(doc) - 1, 0);
  int ok = 0;

  if (!bl.failed && out != NULL && out->status == GUMBO_STATUS_OK &&
      out->root != NULL && out->root->type == GUMBO_NODE_ELEMENT &&
      out->root->v.element.tag == GUMBO_TAG_HTML &&
      out->document->v.document.has_doctype &&
      out->root->v.element.children.length == 2) {
    const GumboNode *body =
        (const GumboNode *) out->root->v.element.children.data[1];
    if (body->type == GUMBO_NODE_ELEMENT &&
        body->v.element.tag == GUMBO_TAG_BODY &&
        body->v.element.children.length == 1) {
      const GumboNode *p = (const GumboNode *) body->v.element.children.data[0];
      const GumboAttribute *cls =
          gumbo_get_attribute(&p->v.element.attributes, "class");
      ok = p->v.element.tag == GUMBO_TAG_P && cls != NULL &&
           strcmp(cls->value, "x") == 0;
    }
  }
  blocks_release(&bl);
  return ok;
}

int
zuh_gumbo_depth_selftest(void) {
  enum { NEST = 64, LIMIT = 16 };
  char buf[NEST * 5 + 1];
  zuh_blocks bl = {NULL, 0};
  GumboOutput *out;
  int limited, unlimited, i;

  for (i = 0; i < NEST; i++)
    memcpy(buf + 5 * i, "<div>", 5);
  buf[NEST * 5] = '\0';

  out = parse_with_blocks(&bl, buf, NEST * 5, LIMIT);
  limited = !bl.failed && out->status == GUMBO_STATUS_TREE_TOO_DEEP;
  blocks_release(&bl);

  bl.failed = 0;
  out = parse_with_blocks(&bl, buf, NEST * 5, 0);
  unlimited = !bl.failed && out->status == GUMBO_STATUS_OK;
  blocks_release(&bl);

  return limited && unlimited;
}
