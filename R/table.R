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
#' Cell text follows [html_text_clean()]. All columns are character unless
#' `convert = TRUE`.
#'
#' @section Conversion:
#' With `convert = TRUE`, each column is converted on its own, and only when
#' every non-missing value converts; otherwise it stays character, so
#' conversion never turns a value into `NA`. Values are compared after
#' removing surrounding whitespace.
#' * `TRUE`, `FALSE`, `true`, `false`, `True` and `False` make a logical
#'   column.
#' * Decimal numbers, with an optional sign and exponent, make an integer
#'   column when all are whole and fit, otherwise a double column. `decimal`
#'   is the decimal mark. `thousands`, if given, is a grouping mark allowed
#'   between groups of three digits, as in `1,234,567.5`; a badly grouped
#'   value such as `1,23` keeps the column character.
#' * A value with a leading zero, such as `"0012"`, keeps the column
#'   character: it is an identifier, not a number. `"0"` and `"0.5"` are
#'   numbers.
#' * `Inf`, `NaN`, `NA`, currency symbols and percentages are not numbers;
#'   list such strings in `na`, or convert them yourself. A column with no
#'   non-missing values stays character.
#'
#' @param x For `html_table()`, a nodeset holding exactly one `<table>`
#'   element; for `html_tables()`, a `zuhtml_document` or `zuhtml_nodeset`
#'   to search.
#' @param header How to find header rows; see the Headers section.
#' @param trim Whether to trim each cell's text; see [html_text_clean()].
#' @param na Strings that become `NA` after trimming, such as `c("", "-")`.
#'   By default no text is treated as missing.
#' @param convert If `TRUE`, convert columns that are entirely numbers or
#'   logicals; see the Conversion section.
#' @param decimal The decimal mark for `convert`: a single character.
#' @param thousands The grouping mark for `convert`: a single character
#'   other than `decimal`, or `NULL` for none.
#' @param limits Resource limits from [html_limits()]; `max_table_cells`
#'   bounds the grid, spans included.
#' @param css For `html_tables()`, the selector of tables to read. Only the
#'   outermost matching tables are read; nested ones remain part of their
#'   parents' cells.
#' @param match For `html_tables()`, a regular expression ([grepl()]) that
#'   a table's cleaned text must match for the table to be read, or `NULL`
#'   to read every table.
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
#' html_tables(doc, match = "North")
#'
#' doc <- html_parse(paste0(
#'   "<table><tr><th>Id<th>Amount<th>Paid",
#'   "<tr><td>007<td>1.234,50<td>true<tr><td>012<td>99<td>false</table>"
#' ))
#' str(html_table(html_element(doc, "table"), convert = TRUE,
#'                decimal = ",", thousands = "."))
html_table <- function(x, header = "auto", trim = TRUE, na = character(),
                       convert = FALSE, decimal = ".", thousands = NULL,
                       limits = html_limits()) {
  call <- sys.call()
  t <- zuh_one_element(x, "table", call)
  zuh_check_flag(trim, "trim", call)
  if (!is.character(na) || anyNA(na)) {
    zuh_input_error("na", "`na` must be a character vector without NA.",
                    call = call)
  }
  limits <- zuh_check_limits(limits, call = call)
  zuh_check_convert(convert, decimal, thousands, call)
  n <- zuh_nodes(t)
  g <- zuh_grid(n, limits, call)
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
  if (convert) cols <- lapply(cols, zuh_convert, decimal, thousands)
  names(cols) <- labels
  structure(cols, class = "data.frame", row.names = .set_row_names(nrow(data)))
}

# The grid of one table, with its structural errors raised as conditions.
zuh_grid <- function(n, limits, call) {
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
  g
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
html_tables <- function(x, css = "table", match = NULL, ...) {
  call <- sys.call()
  if (!is.null(match) &&
      (!is.character(match) || length(match) != 1L || is.na(match))) {
    zuh_input_error("match", "`match` must be NULL or a single string.",
                    call = call)
  }
  tabs <- zuh_select_including(x, css, call)
  tabs <- tabs[html_name(tabs) %in% "table" &
                 html_namespace(tabs) %in% zuh_xhtml]
  n <- zuh_nodes(tabs)
  outer <- new_nodeset(
    zuh_checked(.Call(C_zuh_outermost, n$doc$ptr, n$ids), n, call = call),
    n$doc
  )
  if (!is.null(match)) outer <- outer[grepl(match, html_text_clean(outer))]
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

#' Cells of an HTML table
#'
#' One row per cell of one `<table>`, with its position in the grid that
#' [html_table()] builds: spans are placed, clipped and checked exactly as
#' there, and rows are numbered in the same logical order, header rows
#' included. Use it when the data frame loses what you need: which cells are
#' headers, how far they span, or the links inside them.
#'
#' @param x A nodeset holding exactly one `<table>` element.
#' @param trim Whether to trim each cell's text; see [html_text_clean()].
#' @param absolute If `TRUE`, links are resolved with [html_url()];
#'   otherwise they are `href` as written, as in [html_links()].
#' @param limits Resource limits from [html_limits()]; `max_table_cells`
#'   bounds the grid, spans included.
#'
#' @return A data frame with one row per `<td>` or `<th>`, in grid order
#'   (by row, then column), and columns:
#'   * `row`, `column`: the integer position of the cell's top-left slot;
#'   * `rowspan`, `colspan`: the integer number of rows and columns it
#'     covers, after `rowspan="0"` is expanded and spans are clipped;
#'   * `section`: `"thead"`, `"tbody"` or `"tfoot"`; rows directly in the
#'     table are `"tbody"`;
#'   * `header`: `TRUE` for a `<th>`;
#'   * `text`: the cell's cleaned text, without nested tables, as in
#'     [html_table()];
#'   * `links`: a list of character vectors, the `href` of each `<a>` and
#'     `<area>` in the cell, outside nested tables.
#' @family extraction
#' @export
#' @examples
#' doc <- html_parse(paste0(
#'   "<table><tr><th rowspan=2>Package<th colspan=2>Links",
#'   "<tr><th>Home<th>Docs",
#'   "<tr><td>zuhtml<td><a href='https://example.org/'>site</a>",
#'   "<td><a href='/ref/'>ref</a> <a href='/news/'>news</a></table>"
#' ), base_url = "https://example.org/pkg/")
#' cells <- html_table_cells(html_element(doc, "table"), absolute = TRUE)
#' cells[, c("row", "column", "rowspan", "colspan", "header", "text")]
#' cells$links[[7]]
html_table_cells <- function(x, trim = TRUE, absolute = FALSE,
                             limits = html_limits()) {
  call <- sys.call()
  t <- zuh_one_element(x, "table", call)
  zuh_check_flag(trim, "trim", call)
  zuh_check_flag(absolute, "absolute", call)
  limits <- zuh_check_limits(limits, call = call)
  n <- zuh_nodes(t)
  g <- zuh_grid(n, limits, call)
  cells <- new_nodeset(g$cell_node, n$doc)
  k <- length(cells)
  nc <- g$ncols
  # Slots are row-major, so a cell's first slot is its top-left corner and
  # its last is its bottom-right one.
  where <- which(g$slot >= 0L)
  owner <- g$slot[where] + 1L
  first <- where[match(seq_len(k), owner)] - 1L
  last <- rev(where)[match(seq_len(k), rev(owner))] - 1L
  row <- first %/% nc + 1L
  column <- first %% nc + 1L

  # Links outside nested tables, grouped by the cell that holds them.
  links <- html_elements(cells, "a[href], area[href]")
  mine <- as.integer(html_closest(links, "table")) == n$ids
  links <- links[mine]
  urls <- if (absolute) html_url(links) else html_attr(links, "href")
  cell_of <- match(as.integer(html_closest(links, "td, th")), g$cell_node)
  by_cell <- split(urls, factor(cell_of, levels = seq_len(k)))

  out <- data.frame(
    row = as.integer(row),
    column = as.integer(column),
    rowspan = as.integer(last %/% nc + 2L - row),
    colspan = as.integer(last %% nc + 2L - column),
    section = c("thead", "tbody", "tfoot")[g$row_group[row] + 1L],
    header = html_name(cells) == "th",
    text = zuh_clean(zuh_nodes(cells), trim = trim, skip_tables = TRUE),
    stringsAsFactors = FALSE
  )
  out$links <- unname(by_cell)
  out
}

zuh_check_convert <- function(convert, decimal, thousands, call) {
  zuh_check_flag(convert, "convert", call)
  mark <- function(v) {
    is.character(v) && length(v) == 1L && !is.na(v) && nchar(v) == 1L &&
      !grepl("[0-9eE+-]", v)
  }
  if (!mark(decimal)) {
    zuh_input_error(
      "decimal",
      "`decimal` must be a single character that is not a digit or sign.",
      call = call
    )
  }
  if (!is.null(thousands) && (!mark(thousands) || thousands == decimal)) {
    zuh_input_error(
      "thousands",
      paste0("`thousands` must be NULL or a single character that is not ",
             "a digit or sign and differs from `decimal`."),
      call = call
    )
  }
}

# A single character as a bracket expression, which matches it literally.
zuh_re_char <- function(ch) {
  if (ch == "^") "\\^" else if (ch == "\\") "\\\\" else paste0("[", ch, "]")
}

zuh_trim_ws <- function(v) trimws(v, whitespace = "[ \t\n\r\f]")

# Convert one character column when every non-missing value converts.
zuh_convert <- function(v, decimal, thousands) {
  y <- zuh_trim_ws(v)
  x <- y[!is.na(y)]
  if (length(x) == 0L) return(v)
  if (all(x %in% c("TRUE", "FALSE", "true", "false", "True", "False"))) {
    return(as.logical(toupper(y)))
  }
  d <- zuh_re_char(decimal)
  int <- if (is.null(thousands)) {
    "[0-9]+"
  } else {
    paste0("([0-9]+|[0-9]{1,3}(", zuh_re_char(thousands), "[0-9]{3})+)")
  }
  num <- paste0("^[+-]?(", int, "(", d, "[0-9]*)?|", d, "[0-9]+)",
                "([eE][+-]?[0-9]+)?$")
  if (!all(grepl(num, x)) || any(grepl("^[+-]?0[0-9]", x))) return(v)
  if (!is.null(thousands)) y <- gsub(thousands, "", y, fixed = TRUE)
  if (decimal != ".") y <- sub(decimal, ".", y, fixed = TRUE)
  out <- as.numeric(y)
  whole <- !grepl("[.eE]", y[!is.na(y)])
  if (all(whole) && all(abs(out[!is.na(out)]) <= .Machine$integer.max)) {
    out <- as.integer(out)
  }
  out
}
