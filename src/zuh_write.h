/* HTML serialization of the frozen document, per the WHATWG "serializing
 * HTML fragments" algorithm. Pure C: no R headers. */
#ifndef ZUH_WRITE_H
#define ZUH_WRITE_H

#include <stddef.h>

#include "zuh_buf.h"
#include "zuh_document.h"
#include "zuh_status.h"

/* Serialize node `id` into `out`, a buffer from zuh_buf_init(): with
 * `outer`, the node itself (its "outerHTML"); otherwise its children
 * ("innerHTML"). The document or fragment node has no markup of its own, so
 * both give its children. ZUH_LIMIT_MEMORY if the buffer could not grow. */
zuh_status zuh_serialize(const zuh_doc *doc, zuh_id id, int outer,
                         zuh_buf *out);

#endif
