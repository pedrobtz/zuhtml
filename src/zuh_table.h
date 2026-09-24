/* The table grid of design section 9. Pure C: no R headers. */
#ifndef ZUH_TABLE_H
#define ZUH_TABLE_H

#include <stddef.h>
#include <stdint.h>

#include "zuh_buf.h"
#include "zuh_document.h"
#include "zuh_status.h"

enum { ZUH_GROUP_HEAD = 0, ZUH_GROUP_BODY = 1, ZUH_GROUP_FOOT = 2 };

typedef struct {
  uint32_t nrows, ncols;
  zuh_id *row_node;       /* nrows: the <tr> of each logical row */
  uint8_t *row_group;     /* nrows: ZUH_GROUP_* */
  uint8_t *row_all_th;    /* nrows: every cell anchored in the row is <th>,
                             and there is at least one */
  uint32_t ncells;
  zuh_id *cell_node;      /* ncells: the <td> or <th> */
  int32_t *slot;          /* nrows * ncols, row-major: the cell covering the
                             slot, or -1 for a gap */
  /* On ZUH_ERR_TABLE_OVERLAP: the 1-based logical row and 1-based cell
   * within it that overlapped. On ZUH_LIMIT_TABLE: the slot count reached. */
  uint32_t err_row, err_cell;
  double err_slots;
} zuh_table;

/* Build the grid of `table`, an HTML <table> element: rows of its row
 * groups in logical order (every <thead>, then the <tbody>s and runs of
 * direct <tr> children in order, then every <tfoot>); cells placed at the
 * next free column; colspan and rowspan parsed as HTML non-negative
 * integers (missing or invalid 1; colspan 0 is 1, clamped to 1000; rowspan
 * clamped to 65534, 0 meaning to the end of its row group, and clipped to
 * the rows left in the group). Every array is allocated through `alloc`.
 * ZUH_LIMIT_TABLE if the grid would exceed `max_cells` slots, checked
 * before the grid is allocated; ZUH_ERR_TABLE_OVERLAP if a cell's span
 * covers a slot another cell already covers. */
zuh_status zuh_table_grid(const zuh_doc *doc, zuh_id table, double max_cells,
                          zuh_alloc_fn alloc, void *userdata,
                          zuh_table *out);

#endif
