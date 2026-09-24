/* HTML to Markdown: html_markdown(). Pure C: no R headers. */
#ifndef ZUH_MARKDOWN_H
#define ZUH_MARKDOWN_H

#include <stddef.h>

#include "zuh_buf.h"
#include "zuh_document.h"
#include "zuh_status.h"

/* Resolved link and image URLs, by node: ids ascending; urls[i] is the URL
 * for ids[i], or NULL to use the attribute as written. */
typedef struct {
  const zuh_id *ids;
  const char *const *urls;
  size_t n;
} zuh_md_urls;

/* Append CommonMark for node `id` to `out`, from one iterative walk:
 * headings, paragraphs, emphasis and strong, inline code, fenced code for
 * <pre>, block quotes, nested lists, links and images (URLs from `urls`
 * when given there), thematic breaks, hard line breaks, and GFM pipe
 * tables for tables without spans or nested tables (others become their
 * rows' text). Text is skipped and collapsed as html_text_clean() does,
 * and so is <head>, <svg> and raw-text content; Markdown-significant
 * characters in text are escaped. `urls` may be NULL. Only an element,
 * document, fragment or text node has Markdown; for other nodes nothing is
 * appended. Scratch memory comes from `out`'s allocator. */
zuh_status zuh_markdown(const zuh_doc *doc, zuh_id id,
                        const zuh_md_urls *urls, zuh_buf *out);

#endif
