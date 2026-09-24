/* The version-specific Gumbo adapter. The only project-owned code that
 * includes a Gumbo header is zuh_gumbo.c; everything else talks to Gumbo
 * through this interface. Pure C: no R headers. */
#ifndef ZUH_GUMBO_H
#define ZUH_GUMBO_H

/* The pinned Gumbo release, as recorded in src/vendor/PROVENANCE. */
const char *zuh_gumbo_version(void);

/* The local patch series applied to the vendored tree, in order. Returns
 * the number of patches and points *ids at a static array of identifiers. */
int zuh_gumbo_patches(const char *const **ids);

/* Parse a fixed document and check the tree Gumbo builds. Returns 1 when
 * the vendored library is linked and working. */
int zuh_gumbo_selftest(void);

/* Parse a fixed deeply nested document with and without max_tree_depth.
 * Returns 1 when patch 0001 is in effect: the limited parse stops with
 * GUMBO_STATUS_TREE_TOO_DEEP and the unlimited one does not. */
int zuh_gumbo_depth_selftest(void);

#endif
