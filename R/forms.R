#' Forms and their controls
#'
#' Describes each `<form>` below the given nodes (and the nodes themselves)
#' and the controls it owns, for inspection. Nothing is submitted, fetched
#' or built into a request.
#'
#' A control belongs to a form as the HTML standard's form owner says:
#' the form named by its `form` attribute (the element with that ID, if it
#' is a `<form>`; no form otherwise), else its nearest ancestor `<form>`.
#' Old pages often write `<table><form><tr><td><input ...>`, where the
#' parser closes the form at once but browsers still associate the
#' following controls with it; such a form, left empty inside a table,
#' owns the controls without another owner that follow it in that table,
#' up to the next form.
#'
#' Controls are `<input>`, `<select>`, `<textarea>` and `<button>`
#' elements, in document order. Values follow the DOM:
#' * `type` is an input's `type` (lowercased; `"text"` when missing or
#'   unknown), `"select-one"` or `"select-multiple"`, `"textarea"`, or a
#'   button's `type` (`"submit"` by default);
#' * `value` is the `value` attribute (`"on"` for a checkbox or radio
#'   button without one, else `""`); a textarea's text; or a select's
#'   first selected option's value, where a single select with no option
#'   marked selected selects its first enabled option;
#' * `disabled` is `TRUE` for a control with a `disabled` attribute or
#'   inside a disabled `<fieldset>` (except in its first `<legend>`).
#'
#' @param x A `zuhtml_document` or `zuhtml_nodeset`.
#'
#' @return A list with one element per form, in document order, each a
#'   list of:
#'   * `action`: the `action` attribute resolved as [html_url()] resolves
#'     URLs; without one, the document's base URL, as browsers submit to
#'     the page itself; `NA` when neither resolves;
#'   * `method`: `"get"`, `"post"` or `"dialog"` (`"get"` when missing or
#'     invalid);
#'   * `enctype`: `"application/x-www-form-urlencoded"` (the default),
#'     `"multipart/form-data"` or `"text/plain"`;
#'   * `id`, `name`: the attributes, or `NA`;
#'   * `fields`: a data frame with one row per control and columns `name`
#'     (`NA` when absent; repeated names are kept), `type`, `value`,
#'     `checked` (`TRUE`/`FALSE` for checkboxes and radio buttons, `NA`
#'     otherwise), `disabled`, and `options`, a list-column holding for
#'     each select a data frame of its options (`value`, `label`,
#'     `selected`, `disabled`) and `NULL` for other controls.
#' @family extraction
#' @export
#' @examples
#' doc <- html_parse(paste0(
#'   "<form action='/search' method=POST>",
#'   "<input name=q value='zuhtml'>",
#'   "<select name=sort><option>relevance<option selected>date</select>",
#'   "<label><input type=checkbox name=exact checked> Exact</label>",
#'   "<button>Search</button></form>",
#'   "<input form=search-options name=page value=2>",
#'   "<form id=search-options></form>"
#' ), base_url = "https://example.org/")
#' forms <- html_forms(doc)
#' forms[[1]][c("action", "method")]
#' forms[[1]]$fields[, c("name", "type", "value", "checked")]
#' forms[[1]]$fields$options[[2]]
#' forms[[2]]$fields$name
html_forms <- function(x) {
  call <- sys.call()
  forms <- zuh_select_including(x, "form", call)
  doc <- zuh_owner(forms)
  if (length(forms) == 0L) return(list())
  base <- zuh_doc_base(doc)
  ctrls <- html_elements(doc, "input, select, textarea, button")
  owner <- zuh_form_owner(ctrls, doc)
  lapply(seq_along(forms), function(i) {
    f <- forms[i]
    mine <- ctrls[owner %in% as.integer(f)]
    method <- tolower(html_attr(f, "method", default = "get"))
    if (!method %in% c("get", "post", "dialog")) method <- "get"
    enctype <- tolower(html_attr(f, "enctype", default = ""))
    if (!enctype %in% c("multipart/form-data", "text/plain")) {
      enctype <- "application/x-www-form-urlencoded"
    }
    list(
      action = zuh_resolve(html_attr(f, "action", default = ""), base),
      method = method,
      enctype = enctype,
      id = html_attr(f, "id"),
      name = html_attr(f, "name"),
      fields = zuh_fields(mine)
    )
  })
}

# The node ID of each control's form owner, or NA.
zuh_form_owner <- function(ctrls, doc) {
  n <- length(ctrls)
  owner <- rep(NA_integer_, n)
  if (n == 0L) return(owner)
  ref <- html_attr(ctrls, "form")
  anc <- as.integer(html_closest(html_parent(ctrls), "form"))
  for (i in seq_len(n)) {
    if (is.na(ref[i])) {
      owner[i] <- anc[i]
    } else if (nzchar(ref[i])) {
      target <- html_element(doc, paste0("[id=\"", zuh_css_string(ref[i]),
                                         "\"]"))
      if (!is.na(unclass(target)) && html_name(target) == "form" &&
          html_namespace(target) == zuh_xhtml) {
        owner[i] <- as.integer(target)
      }
    }
  }
  # Forms the parser closed at once inside a table own the unowned controls
  # that follow them in that table, up to the next form.
  forms <- html_elements(doc, "form")
  empty <- forms[html_name(html_parent(forms)) %in%
                   c("table", "tbody", "thead", "tfoot", "tr") &
                   lengths(lapply(seq_along(forms), function(i) {
                     html_children(forms[i], elements_only = FALSE)
                   })) == 0L]
  if (length(empty)) {
    fid <- as.integer(forms)
    cid <- as.integer(ctrls)
    for (k in seq_along(empty)) {
      e <- as.integer(empty[k])
      table <- html_closest(empty[k], "table")
      later <- fid[fid > e]
      stop_at <- if (length(later)) min(later) else Inf
      inside <- as.integer(html_closest(ctrls, "table")) ==
        as.integer(table)
      take <- is.na(owner) & is.na(ref) & cid > e & cid < stop_at &
        !is.na(inside) & inside
      owner[take] <- e
    }
  }
  owner
}

zuh_input_types <- c(
  "hidden", "text", "search", "tel", "url", "email", "password", "date",
  "month", "week", "time", "datetime-local", "number", "range", "color",
  "checkbox", "radio", "file", "submit", "image", "reset", "button"
)

zuh_fields <- function(ctrls) {
  n <- length(ctrls)
  tag <- html_name(ctrls)
  type <- character(n)
  value <- character(n)
  checked <- rep(NA, n)
  options <- vector("list", n)
  for (i in seq_len(n)) {
    c1 <- ctrls[i]
    switch(
      tag[i],
      input = {
        t <- tolower(html_attr(c1, "type", default = "text"))
        if (!t %in% zuh_input_types) t <- "text"
        type[i] <- t
        checkable <- t %in% c("checkbox", "radio")
        value[i] <- html_attr(c1, "value",
                              default = if (checkable) "on" else "")
        if (checkable) checked[i] <- !is.na(html_attr(c1, "checked"))
      },
      button = {
        t <- tolower(html_attr(c1, "type", default = "submit"))
        if (!t %in% c("submit", "reset", "button")) t <- "submit"
        type[i] <- t
        value[i] <- html_attr(c1, "value", default = "")
      },
      textarea = {
        type[i] <- "textarea"
        value[i] <- html_text(c1)
      },
      select = {
        multiple <- !is.na(html_attr(c1, "multiple"))
        type[i] <- if (multiple) "select-multiple" else "select-one"
        opts <- zuh_options(c1, multiple)
        options[i] <- list(opts)
        sel <- which(opts$selected)
        value[i] <- if (length(sel)) opts$value[sel[1L]] else ""
      }
    )
  }
  out <- data.frame(
    name = html_attr(ctrls, "name"),
    type = type,
    value = value,
    checked = checked,
    disabled = zuh_disabled(ctrls),
    stringsAsFactors = FALSE
  )
  out$options <- options
  out
}

# The options of one select, with the DOM's selectedness: a select-one
# with none marked selected selects its first enabled option, and one with
# several keeps the last.
zuh_options <- function(select, multiple) {
  o <- html_elements(select, "option")
  label <- html_attr(o, "label")
  text <- gsub("[ \t\n\r\f]+", " ",
               trimws(html_text(o), whitespace = "[ \t\n\r\f]"))
  value <- html_attr(o, "value")
  value[is.na(value)] <- text[is.na(value)]
  label[is.na(label) | !nzchar(label)] <- text[is.na(label) | !nzchar(label)]
  disabled <- !is.na(html_attr(o, "disabled")) |
    !is.na(as.integer(html_closest(html_parent(o), "optgroup[disabled]")))
  selected <- !is.na(html_attr(o, "selected"))
  if (!multiple) {
    if (sum(selected) > 1L) {
      selected <- seq_along(selected) == max(which(selected))
    } else if (!any(selected) && any(!disabled)) {
      selected <- seq_along(selected) == which(!disabled)[1L]
    }
  }
  data.frame(value = value, label = label, selected = selected,
             disabled = disabled, stringsAsFactors = FALSE)
}

# Disabled by attribute, or by a disabled fieldset ancestor unless inside
# that fieldset's first legend.
zuh_disabled <- function(ctrls) {
  vapply(seq_along(ctrls), function(i) {
    c1 <- ctrls[i]
    if (!is.na(html_attr(c1, "disabled"))) return(TRUE)
    anc <- html_ancestors(c1)
    fs <- anc[html_name(anc) == "fieldset" &
                !is.na(html_attr(anc, "disabled"))]
    for (k in seq_along(fs)) {
      legend <- html_element(fs[k], ":scope > legend")
      inside <- !is.na(unclass(legend)) &&
        as.integer(legend) %in% as.integer(anc)
      if (!inside) return(TRUE)
    }
    FALSE
  }, NA)
}
