/* Status codes the pure-C core returns. src/r_api.c maps each to a classed
 * R condition by enumerator, never by message text. Pure C: no R headers. */
#ifndef ZUH_STATUS_H
#define ZUH_STATUS_H

typedef enum {
  ZUH_OK = 0,
  ZUH_LIMIT_INPUT,   /* input longer than max_input */
  ZUH_LIMIT_MEMORY,  /* budget exceeded, allocation failed, or injected */
  ZUH_LIMIT_DEPTH,   /* open-element stack deeper than max_depth */
  ZUH_LIMIT_NODES,   /* more than max_nodes in the tree */
  ZUH_ERR_INTERNAL   /* an invariant failed, e.g. a free the ledger
                        does not recognise */
} zuh_status;

#endif
