/* See zuh_table.h. */
#include <string.h>

#include "zuh_table.h"

static int
html_element_named(const zuh_doc *doc, zuh_id id, const char *name) {
  const zuh_node *n = &doc->nodes[id];
  return n->type == ZUH_NODE_ELEMENT && n->ns == ZUH_NS_HTML &&
         strcmp(zuh_str(doc, n->name), name) == 0;
}

/* HTML "rules for parsing non-negative integers": leading ASCII
 * whitespace, an optional "+", then digits; anything after the digits is
 * ignored. Returns -1 when there are no digits. Saturates at `cap`. */
static long
parse_span(const char *s, long cap) {
  long v = 0;
  int digits = 0;
  while (*s == ' ' || *s == '\t' || *s == '\n' || *s == '\r' || *s == '\f')
    s++;
  if (*s == '+')
    s++;
  while (*s >= '0' && *s <= '9') {
    if (v <= cap)
      v = v * 10 + (*s - '0');
    s++;
    digits = 1;
  }
  if (!digits)
    return -1;
  return v > cap ? cap : v;
}

static long
span_attr(const zuh_doc *doc, zuh_id cell, const char *name, long cap) {
  const zuh_node *n = &doc->nodes[cell];
  uint32_t i;
  for (i = 0; i < n->attr_count; i++) {
    const zuh_attr *a = &doc->attrs[n->attr_start + i];
    if (a->ns == ZUH_ATTR_NS_NONE && strcmp(zuh_str(doc, a->name), name) == 0)
      return parse_span(zuh_str(doc, a->value), cap);
  }
  return -1;
}

typedef struct {
  zuh_id first; /* first <tr> child, or the first direct <tr> of a run */
  zuh_id group; /* the <thead>/<tbody>/<tfoot>, or ZUH_NONE for a run */
  uint8_t kind;
} row_group;

static int
is_cell(const zuh_doc *doc, zuh_id id) {
  return html_element_named(doc, id, "td") || html_element_named(doc, id, "th");
}

/* The rows of a group, in order: the <tr> children of a section, or a run
 * of direct <tr> children of the table. */
static zuh_id
next_row(const zuh_doc *doc, const row_group *g, zuh_id after) {
  zuh_id r = after == ZUH_NONE
                 ? (g->group != ZUH_NONE ? doc->nodes[g->group].first_child
                                         : g->first)
                 : doc->nodes[after].next_sibling;
  for (; r != ZUH_NONE; r = doc->nodes[r].next_sibling) {
    if (html_element_named(doc, r, "tr"))
      return r;
    /* A run of direct rows ends at the first non-row element. */
    if (g->group == ZUH_NONE && doc->nodes[r].type == ZUH_NODE_ELEMENT)
      return ZUH_NONE;
  }
  return ZUH_NONE;
}

zuh_status
zuh_table_grid(const zuh_doc *doc, zuh_id table, double max_cells,
               zuh_alloc_fn alloc, void *userdata, zuh_table *out) {
  row_group *groups;
  size_t ngroups = 0, g, k;
  uint32_t nrows = 0, ncells = 0, r, width = 0, cap_width;
  zuh_id c;
  uint32_t *busy;      /* per column: first logical row not covered */
  uint32_t *cell_row, *cell_col, *cell_rs, *cell_cs;
  uint32_t cell_i = 0;
  size_t nkids = 0;

  memset(out, 0, sizeof(*out));

  /* Row groups, in logical order: heads, bodies and direct-row runs, feet. */
  for (c = doc->nodes[table].first_child; c != ZUH_NONE;
       c = doc->nodes[c].next_sibling)
    nkids++;
  groups = (row_group *) alloc(userdata, (nkids + 1) * sizeof(row_group));
  if (groups == NULL)
    return ZUH_LIMIT_MEMORY;
  for (k = 0; k < 3; k++) {
    int in_run = 0;
    for (c = doc->nodes[table].first_child; c != ZUH_NONE;
         c = doc->nodes[c].next_sibling) {
      uint8_t kind;
      if (html_element_named(doc, c, "tr")) {
        if (k == ZUH_GROUP_BODY && !in_run) {
          groups[ngroups].first = c;
          groups[ngroups].group = ZUH_NONE;
          groups[ngroups].kind = ZUH_GROUP_BODY;
          ngroups++;
        }
        in_run = 1;
        continue;
      }
      if (doc->nodes[c].type == ZUH_NODE_ELEMENT)
        in_run = 0;
      if (html_element_named(doc, c, "thead"))
        kind = ZUH_GROUP_HEAD;
      else if (html_element_named(doc, c, "tbody"))
        kind = ZUH_GROUP_BODY;
      else if (html_element_named(doc, c, "tfoot"))
        kind = ZUH_GROUP_FOOT;
      else
        continue;
      if (kind != k)
        continue;
      groups[ngroups].first = ZUH_NONE;
      groups[ngroups].group = c;
      groups[ngroups].kind = kind;
      ngroups++;
    }
  }

  /* Count rows and cells. */
  for (g = 0; g < ngroups; g++) {
    zuh_id row;
    for (row = next_row(doc, &groups[g], ZUH_NONE); row != ZUH_NONE;
         row = next_row(doc, &groups[g], row)) {
      nrows++;
      for (c = doc->nodes[row].first_child; c != ZUH_NONE;
           c = doc->nodes[c].next_sibling)
        if (is_cell(doc, c))
          ncells++;
    }
  }
  out->nrows = nrows;
  out->ncells = ncells;
  out->row_node = (zuh_id *) alloc(userdata, (nrows + 1) * sizeof(zuh_id));
  out->row_group = (uint8_t *) alloc(userdata, nrows + 1);
  out->row_all_th = (uint8_t *) alloc(userdata, nrows + 1);
  out->cell_node = (zuh_id *) alloc(userdata, (ncells + 1) * sizeof(zuh_id));
  cell_row = (uint32_t *) alloc(userdata, (ncells + 1) * sizeof(uint32_t));
  cell_col = (uint32_t *) alloc(userdata, (ncells + 1) * sizeof(uint32_t));
  cell_rs = (uint32_t *) alloc(userdata, (ncells + 1) * sizeof(uint32_t));
  cell_cs = (uint32_t *) alloc(userdata, (ncells + 1) * sizeof(uint32_t));
  if (out->row_node == NULL || out->row_group == NULL ||
      out->row_all_th == NULL || out->cell_node == NULL || cell_row == NULL ||
      cell_col == NULL || cell_rs == NULL || cell_cs == NULL)
    return ZUH_LIMIT_MEMORY;

  /* The widest the grid may be and stay within max_cells. */
  {
    double w = nrows > 0 ? max_cells / (double) nrows : max_cells;
    cap_width = w >= 4294967295.0 ? 0xFFFFFFFFu : (uint32_t) w;
  }
  busy = NULL;
  {
    /* busy[] grows with the width; allocate it at the cap, or at the
     * total colspan the cells could need, whichever is smaller. */
    double need = 0;
    uint32_t cap;
    for (g = 0; g < ngroups; g++) {
      zuh_id row;
      for (row = next_row(doc, &groups[g], ZUH_NONE); row != ZUH_NONE;
           row = next_row(doc, &groups[g], row))
        for (c = doc->nodes[row].first_child; c != ZUH_NONE;
             c = doc->nodes[c].next_sibling)
          if (is_cell(doc, c)) {
            long cs = span_attr(doc, c, "colspan", 1000);
            need += cs <= 0 ? 1 : (double) cs;
          }
    }
    cap = need < (double) cap_width ? (uint32_t) need : cap_width;
    busy = (uint32_t *) alloc(userdata, ((size_t) cap + 1) * sizeof(uint32_t));
    if (busy == NULL)
      return ZUH_LIMIT_MEMORY;
    memset(busy, 0, ((size_t) cap + 1) * sizeof(uint32_t));
  }

  /* Place the cells, group by group. A rowspan never leaves its group. */
  r = 0;
  for (g = 0; g < ngroups; g++) {
    uint32_t start = r, end = r, col;
    zuh_id row;
    for (row = next_row(doc, &groups[g], ZUH_NONE); row != ZUH_NONE;
         row = next_row(doc, &groups[g], row))
      end++;
    for (col = 0; col < width; col++)
      busy[col] = start;
    for (row = next_row(doc, &groups[g], ZUH_NONE); row != ZUH_NONE;
         row = next_row(doc, &groups[g], row), r++) {
      uint32_t cur = 0, in_row = 0, th = 0;
      out->row_node[r] = row;
      out->row_group[r] = groups[g].kind;
      for (c = doc->nodes[row].first_child; c != ZUH_NONE;
           c = doc->nodes[c].next_sibling) {
        long cs, rs;
        uint32_t span_r, j;
        if (!is_cell(doc, c))
          continue;
        in_row++;
        if (html_element_named(doc, c, "th"))
          th++;
        while (cur < width && busy[cur] > r)
          cur++;
        cs = span_attr(doc, c, "colspan", 1000);
        if (cs <= 0)
          cs = 1;
        rs = span_attr(doc, c, "rowspan", 65534);
        if (rs < 0)
          rs = 1;
        span_r = rs == 0 ? end - r
                         : ((uint32_t) rs > end - r ? end - r : (uint32_t) rs);
        if ((double) cur + (double) cs > (double) cap_width) {
          out->err_slots = ((double) cur + (double) cs) * (double) nrows;
          return ZUH_LIMIT_TABLE;
        }
        for (j = cur; j < cur + (uint32_t) cs; j++) {
          if (j < width && busy[j] > r) {
            out->err_row = r + 1;
            out->err_cell = in_row;
            return ZUH_ERR_TABLE_OVERLAP;
          }
        }
        for (j = cur; j < cur + (uint32_t) cs; j++)
          busy[j] = r + span_r;
        if (cur + (uint32_t) cs > width)
          width = cur + (uint32_t) cs;
        out->cell_node[cell_i] = c;
        cell_row[cell_i] = r;
        cell_col[cell_i] = cur;
        cell_rs[cell_i] = span_r;
        cell_cs[cell_i] = (uint32_t) cs;
        cell_i++;
        cur += (uint32_t) cs;
      }
      out->row_all_th[r] = in_row > 0 && th == in_row;
    }
  }
  out->ncols = width;

  /* The grid itself, checked against max_cells before it is allocated. */
  if ((double) nrows * (double) width > max_cells) {
    out->err_slots = (double) nrows * (double) width;
    return ZUH_LIMIT_TABLE;
  }
  out->slot = (int32_t *) alloc(
      userdata, ((size_t) nrows * width + 1) * sizeof(int32_t));
  if (out->slot == NULL)
    return ZUH_LIMIT_MEMORY;
  for (k = 0; k < (size_t) nrows * width; k++)
    out->slot[k] = -1;
  for (k = 0; k < cell_i; k++) {
    uint32_t i, j;
    for (i = cell_row[k]; i < cell_row[k] + cell_rs[k]; i++)
      for (j = cell_col[k]; j < cell_col[k] + cell_cs[k]; j++)
        out->slot[(size_t) i * width + j] = (int32_t) k;
  }
  out->ncells = cell_i;
  return ZUH_OK;
}
