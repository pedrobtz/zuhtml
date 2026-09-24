#' Extract HTML tables as data frames
#'
#' `html_table()` reads one `<table>` element into a data frame of
#' character columns. `html_tables()` finds tables and reads each.
#'
#' @section The grid:
#' Rows are read in logical order -- every `<thead>`, then the `<tbody>`
#' sections (and any rows directly in the table), then every `<tfoot>` --
#' and footer rows are ordinary data rows. Rows of nested tables never
#' become rows of the outer table, and a nested table's text is left out of
#' the cell that holds it (it still separates the text around it with a
#' line break).
#'
#' Each cell is placed at the next free column of its row. `colspan` and
#' `rowspan` are read with HTML's rules for non-negative integers: a
#' missing or invalid value is 1, `colspan="0"` is 1, and values are capped
#' at 1000 columns and 65534 rows. `rowspan="0"` extends to the end of the
#' cell's row group, and a larger `rowspan` is cut silently at the end of
#' its group. A spanned value is repeated in every slot it covers. A cell
#' whose span would cover a slot another cell already covers is an error of
#' class `zuhtml_table_structure_error`, never a silent overwrite. Slots no
#' cell covers, in ragged rows, are `NA`; an empty cell is `""`.
#'
#' @section Headers:
#' * `"auto"`: the rows of `<thead>` sections if there are any, otherwise
#'   the leading rows whose cells are all `<th>` (a `<th>` among `<td>`s
#'   does not make a header row);
#' * `TRUE`: the first row; `FALSE`: none;
#' * a vector of row numbers: those rows.
#'
#' Header rows are removed from the data. A column's name joins the
#' non-empty header texts above it with `" / "`, merging repeats that a
#' `colspan` created. Blank names become `V1`, `V2`, ... by column
#' position, and duplicates are made unique with [make.unique()]. Names are
#' not otherwise made syntactic.
#'
#' Cell text follows [html_text_clean()]. All columns are character:
#' convert with [type.convert()] or similar when you know the types, which
#' keeps identifiers with leading zeros intact.
#'
#' @param x For `html_table()`, a nodeset holding exactly one `<table>`
#'   element; for `html_tables()`, a `zuhtml_document` or `zuhtml_nodeset`
#'   to search.
#' @param header How to find header rows; see the Headers section.
#' @param trim Whether to trim each cell's text; see [html_text_clean()].
#' @param na Strings that become `NA` after trimming, such as `c("", "-")`.
#'   By default no text is treated as missing.
#' @param limits Resource limits from [html_limits()]; `max_table_cells`
#'   bounds the grid, spans included.
#' @param css For `html_tables()`, the selector of tables to read. Only the
#'   outermost matching tables are read; nested ones remain part of their
#'   parents' cells.
#' @param ... For `html_tables()`, arguments passed on to `html_table()`.
#'
#' @return `html_table()`: a data frame of character columns. A table with
#'   no rows gives a data frame with no rows and no columns; a table with
#'   only header rows gives no rows and the named columns.
#'   `html_tables()`: a list of such data frames, `list()` when there are
#'   none.
#' @family extraction
#' @export
#' @examples
#' doc <- html_parse(paste0(
#'   "<table><thead><tr><th>Product<th>Price</thead>",
#'   "<tbody><tr><td>0012<td>12.50<tr><td>0034<td>9.00</tbody></table>"
#' ))
#' html_table(html_element(doc, "table"))
#'
#' doc <- html_parse(paste0(
#'   "<table><tr><th rowspan=2>Region<th colspan=2>Sales",
#'   "<tr><th>2025<th>2026<tr><td>North<td>1<td>2</table>"
#' ))
#' html_tables(doc)
html_table <- function(x, header = "auto", trim = TRUE, na = character(),
                       limits = html_limits()) {
  call <- sys.call()
  t <- zuh_one_element(x, "table", call)
  zuh_check_flag(trim, "trim", call)
  if (!is.character(na) || anyNA(na)) {
    zuh_input_error("na", "`na` must be a character vector without NA.",
                    call = call)
  }
  limits <- zuh_check_limits(limits, call = call)
  n <- zuh_nodes(t)
  g <- zuh_checked(
    .Call(C_zuh_table, n$doc$ptr, n$ids, limits$max_table_cells), n,
    call = call
  )
  if (identical(g$error, "overlap")) {
    zuh_abort(
      "table_structure",
      sprintf(paste0("Cell %d of row %d spans a slot another cell already ",
                     "covers."), g$cell, g$row),
      row = g$row, cell = g$cell, call = call
    )
  }
  if (identical(g$error, "limit")) {
    zuh_limit_error(
      "max_table_cells", limits$max_table_cells, g$slots,
      sprintf("The table expands to more than max_table_cells = %.0f slots.",
              limits$max_table_cells),
      call = call
    )
  }
  nr <- g$nrows
  nc <- g$ncols
  if (nr == 0L || nc == 0L) {
    return(data.frame())
  }
  texts <- zuh_clean(zuh_nodes(new_nodeset(g$cell_node, n$doc)),
                     trim = trim, skip_tables = TRUE)
  # Slots are 0-based cell indices, -1 for a gap. A 0 index would drop
  # an element rather than give NA, so gaps become NA first.
  idx <- g$slot + 1L
  idx[idx == 0L] <- NA_integer_
  values <- matrix(texts[idx], nrow = nr, ncol = nc, byrow = TRUE)

  head_rows <- zuh_header_rows(header, g, nr, call)
  labels <- if (length(head_rows)) {
    vapply(seq_len(nc), function(j) {
      parts <- values[head_rows, j]
      parts <- parts[!is.na(parts) & nzchar(trimws(parts))]
      if (length(parts) > 1L) {
        parts <- parts[c(TRUE, parts[-1L] != parts[-length(parts)])]
      }
      paste(parts, collapse = " / ")
    }, character(1))
  } else {
    rep("", nc)
  }
  blank <- !nzchar(labels)
  labels[blank] <- paste0("V", seq_len(nc))[blank]
  labels <- make.unique(labels)

  data <- values[setdiff(seq_len(nr), head_rows), , drop = FALSE]
  if (length(na)) data[data %in% na] <- NA_character_
  cols <- lapply(seq_len(nc), function(j) data[, j])
  names(cols) <- labels
  structure(cols, class = "data.frame", row.names = .set_row_names(nrow(data)))
}

zuh_header_rows <- function(header, g, nr, call) {
  if (identical(header, "auto")) {
    head <- which(g$row_group == 0L)
    if (length(head)) return(head)
    first_data <- which(!g$row_all_th)[1L]
    return(seq_len(if (is.na(first_data)) nr else first_data - 1L))
  }
  if (isTRUE(header)) return(1L)
  if (isFALSE(header)) return(integer())
  ok <- is.numeric(header) && length(header) > 0L && !anyNA(header) &&
    all(header == trunc(header)) && all(header >= 1) &&
    !is.unsorted(header, strictly = TRUE)
  if (!ok) {
    zuh_input_error(
      "header",
      paste0("`header` must be \"auto\", TRUE, FALSE, or increasing row ",
             "numbers."),
      call = call
    )
  }
  if (any(header > nr)) {
    zuh_input_error(
      "header", sprintf("The table has only %d rows.", nr), call = call
    )
  }
  as.integer(header)
}

#' @rdname html_table
#' @export
html_tables <- function(x, css = "table", ...) {
  call <- sys.call()
  tabs <- zuh_select_including(x, css, call)
  tabs <- tabs[html_name(tabs) %in% "table" &
                 html_namespace(tabs) %in% zuh_xhtml]
  n <- zuh_nodes(tabs)
  outer <- new_nodeset(
    zuh_checked(.Call(C_zuh_outermost, n$doc$ptr, n$ids), n, call = call),
    n$doc
  )
  lapply(seq_along(outer), function(i) html_table(outer[i], ...))
}

# The elements of x matching css, including the nodes of x themselves,
# without duplicates, in document order.
zuh_select_including <- function(x, css, call) {
  found <- html_elements(x, css)
  if (!inherits(x, "zuhtml_nodeset")) return(found)
  self <- html_filter(x, css)
  new_nodeset(sort(unique(c(unclass(self), unclass(found)))),
              zuh_owner(found))
}
