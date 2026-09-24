/* The CSS selector subset of design section 6: compile a selector list,
 * then match elements of a frozen document against it right to left. Pure
 * C: no R headers.
 *
 * Supported, and nothing else: type and universal selectors; #id; .class;
 * [attr], [attr=v], ~= |= ^= $= *= with i and s flags; the descendant,
 * child (>), next-sibling (+) and later-sibling (~) combinators; selector
 * lists; :scope, :root, :empty, :first-child, :last-child, :only-child,
 * :nth-child(an+b), :nth-of-type(an+b), and :not() of one compound
 * selector. Anything else fails to compile with a position and a reason. */
#ifndef ZUH_SELECTOR_H
#define ZUH_SELECTOR_H

#include <stddef.h>
#include <stdint.h>

#include "zuh_document.h"

/* Bounds on a compiled selector, so that matching recursion stays shallow. */
#define ZUH_SEL_MAX_COMPOUNDS 128 /* compound selectors in one complex one */
#define ZUH_SEL_MAX_NOT_DEPTH 32  /* :not() nesting */

typedef struct zuh_selector zuh_selector;

/* Why a selector failed to compile. */
typedef enum {
  ZUH_SEL_OK = 0,
  ZUH_SEL_SYNTAX,       /* malformed */
  ZUH_SEL_UNSUPPORTED,  /* valid CSS outside the supported subset */
  ZUH_SEL_TOO_COMPLEX,  /* over ZUH_SEL_MAX_COMPOUNDS or the :not depth */
  ZUH_SEL_NO_MEMORY
} zuh_sel_status;

typedef struct {
  zuh_sel_status status;
  size_t position;      /* byte offset of the problem in the selector */
  const char *reason;   /* a static English description */
} zuh_sel_error;

/* Compile `len` bytes of UTF-8. On success *out is a malloc'd selector to
 * free with zuh_selector_free(); on failure *out is NULL and *err says
 * why. */
zuh_sel_status zuh_selector_compile(const char *css, size_t len,
                                    zuh_selector **out, zuh_sel_error *err);
void zuh_selector_free(zuh_selector *sel);

/* Does any complex selector have :scope in its subject compound? Then the
 * context element itself is a candidate, not only its descendants. */
int zuh_selector_scopes_subject(const zuh_selector *sel);

/* Does matching need sibling positions (the structural pseudo-classes)? */
int zuh_selector_needs_positions(const zuh_selector *sel);

/* Matching state for one call. `elem_pos` and `elem_count`, when the
 * selector needs positions, are caller-provided arrays of n_nodes entries
 * filled by zuh_selector_positions(). */
typedef struct {
  const zuh_doc *doc;
  const zuh_selector *sel;
  const int32_t *elem_pos;    /* 1-based index among element siblings */
  const int32_t *elem_count;  /* number of element children, by parent */
  uint64_t work;              /* compound matches attempted */
  uint64_t work_limit;        /* 0 for none */
  int exceeded;               /* the work limit was reached */
} zuh_match_ctx;

void zuh_selector_positions(const zuh_doc *doc, int32_t *elem_pos,
                            int32_t *elem_count);

/* Does element `id` match? `scope` is the :scope element, or ZUH_NONE. */
int zuh_selector_matches(zuh_match_ctx *ctx, zuh_id id, zuh_id scope);

#endif
