/* HTML serialization of the frozen document, per the WHATWG "serializing
 * HTML fragments" algorithm. Pure C: no R headers. */
#ifndef ZUH_WRITE_H
#define ZUH_WRITE_H

#include <stddef.h>

#include "zuh_document.h"
#include "zuh_status.h"

/* Serialize node `id`: with `outer`, the node itself (its "outerHTML");
 * otherwise its children ("innerHTML"). The document or fragment node has
 * no markup of its own, so both give its children. On ZUH_OK, *out is a
 * malloc'd, NUL-terminated buffer of *len bytes that the caller frees. */
zuh_status zuh_serialize(const zuh_doc *doc, zuh_id id, int outer,
                         char **out, size_t *len);

#endif
