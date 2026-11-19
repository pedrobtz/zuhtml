#' @export
length.zuhtml_nodeset <- function(x) length(unclass(x))

#' @export
`[.zuhtml_nodeset` <- function(x, i) {
  new_nodeset(unclass(x)[i], zuh_owner(x))
}

#' @export
`[[.zuhtml_nodeset` <- function(x, i) {
  new_nodeset(unclass(x)[[i]], zuh_owner(x))
}

# The IDs a value assigned into nodeset `x` stands for: nodes of the same
# document, or missing nodes. IDs from another document, or bare numbers,
# would be read as nodes of `x`'s document, so they are refused, as c()
# refuses them.
zuh_assign_ids <- function(x, value, call) {
  if (inherits(value, "zuhtml_nodeset")) {
    if (!identical(zuh_owner(value)$ptr, zuh_owner(x)$ptr)) {
      zuh_input_error(
        "value", "Nodes from a different document cannot be assigned.",
        call = call
      )
    }
    return(as.vector(unclass(value), "integer"))
  }
  if (is.atomic(value) && !is.object(value) && all(is.na(value))) {
    return(rep(NA_integer_, length(value)))
  }
  zuh_input_error(
    "value",
    "Only nodes of the same document, or NA, can be assigned into a nodeset.",
    call = call
  )
}

#' @export
`[<-.zuhtml_nodeset` <- function(x, i, value) {
  ids <- unclass(x)
  ids[i] <- zuh_assign_ids(x, value, sys.call())
  new_nodeset(ids, zuh_owner(x))
}

#' @export
`[[<-.zuhtml_nodeset` <- function(x, i, value) {
  call <- sys.call()
  value <- zuh_assign_ids(x, value, call)
  if (length(value) != 1L) {
    zuh_input_error("value", "`[[<-` takes exactly one node.", call = call)
  }
  ids <- unclass(x)
  ids[[i]] <- value
  new_nodeset(ids, zuh_owner(x))
}

#' @export
`length<-.zuhtml_nodeset` <- function(x, value) {
  ids <- unclass(x)
  length(ids) <- value
  new_nodeset(ids, zuh_owner(x))
}

# Node IDs are document-local labels, not numbers: arithmetic on them, or
# comparing them, would silently address or match other nodes. Use
# as.integer() to work with the IDs themselves.
# The exception is `==` and `!=` between nodesets of one document, which
# compare node identity (#151).
#' @export
Ops.zuhtml_nodeset <- function(e1, e2) {
  call <- sys.call()
  if (.Generic %in% c("==", "!=") && !missing(e2) &&
      inherits(e1, "zuhtml_nodeset") && inherits(e2, "zuhtml_nodeset")) {
    if (!identical(zuh_owner(e1)$ptr, zuh_owner(e2)$ptr)) {
      zuh_input_error(
        "e2", "Nodes from different documents cannot be compared.",
        call = call
      )
    }
    a <- as.integer(e1)
    b <- as.integer(e2)
    return(if (.Generic == "==") a == b else a != b)
  }
  zuh_refuse_ids(sprintf("`%s`", .Generic), call)
}

zuh_refuse_ids <- function(what, call) {
  zuh_input_error(
    "x",
    sprintf("%s is not defined for nodesets; use as.integer() for the node IDs.",
            what),
    call = call
  )
}

#' @export
Math.zuhtml_nodeset <- function(x, ...) {
  zuh_refuse_ids(sprintf("`%s()`", .Generic), sys.call())
}

#' @export
Summary.zuhtml_nodeset <- function(..., na.rm = FALSE) {
  zuh_refuse_ids(sprintf("`%s()`", .Generic), sys.call())
}

#' @export
mean.zuhtml_nodeset <- function(x, ...) {
  zuh_refuse_ids("`mean()`", sys.call())
}

#' @exportS3Method stats::median
median.zuhtml_nodeset <- function(x, na.rm = FALSE, ...) {
  zuh_refuse_ids("`median()`", sys.call())
}

#' @export
diff.zuhtml_nodeset <- function(x, ...) {
  zuh_refuse_ids("`diff()`", sys.call())
}

# Sorting and ordering go by ID, which is document order.
#' @export
xtfrm.zuhtml_nodeset <- function(x) as.integer(x)

# match(), %in%, setdiff() and the other set operations compare nodes: a
# node of one document is never found among another document's nodes,
# whatever its ID or markup. Missing nodes stay NA.
#' @export
mtfrm.zuhtml_nodeset <- function(x) {
  ids <- as.integer(x)
  out <- paste0(format(zuh_owner(x)$ptr), "#", ids)
  out[is.na(ids)] <- NA_character_
  out
}

#' @export
rev.zuhtml_nodeset <-function(x) new_nodeset(rev(unclass(x)), zuh_owner(x))

#' @export
rep.zuhtml_nodeset <- function(x, ...) {
  new_nodeset(rep(unclass(x), ...), zuh_owner(x))
}

#' @export
unique.zuhtml_nodeset <- function(x, incomparables = FALSE, ...) {
  new_nodeset(unique(unclass(x), incomparables = incomparables, ...),
              zuh_owner(x))
}

#' @export
c.zuhtml_nodeset <- function(...) {
  parts <- list(...)
  ok <- vapply(parts, inherits, logical(1), "zuhtml_nodeset")
  if (!all(ok)) {
    zuh_input_error("...", "Only zuhtml_nodesets can be combined.")
  }
  docs <- lapply(parts, zuh_owner)
  same <- vapply(docs, function(d) identical(d$ptr, docs[[1L]]$ptr),
                 logical(1))
  if (!all(same)) {
    zuh_input_error("...",
                    "Nodes from different documents cannot be combined.")
  }
  new_nodeset(unlist(lapply(parts, unclass)), docs[[1L]])
}

#' @export
as.integer.zuhtml_nodeset <- function(x, ...) as.vector(unclass(x), "integer")

# One single-node nodeset per node, so that lapply(), sapply() and Map()
# over a nodeset hand each function a node rather than a bare integer.
#' @export
as.list.zuhtml_nodeset <- function(x, ...) {
  doc <- zuh_owner(x)
  lapply(unclass(x), new_nodeset, doc = doc)
}

zuh_trunc <- function(s, width) {
  # fixed = TRUE takes the replacement literally: one backslash, then n.
  s <- gsub("\n", "\\n", s, fixed = TRUE)
  long <- !is.na(s) & nchar(s) > width
  s[long] <- paste0(substr(s[long], 1L, width - 3L), "...")
  s
}

#' @export
format.zuhtml_nodeset <- function(x, width = 60L, ...) {
  if (length(x) == 0L) return(character())
  type <- html_type(x)
  name <- html_name(x)
  out <- rep("<missing>", length(x))
  el <- which(type %in% "element")
  if (length(el)) {
    attrs <- html_attrs(x[el])
    out[el] <- vapply(seq_along(el), function(k) {
      a <- attrs[[k]]
      s <- if (length(a)) {
        paste0(" ", names(a), "=\"", a, "\"", collapse = "")
      } else ""
      zuh_trunc(paste0("<", name[el[k]], s, ">"), width)
    }, character(1))
  }
  other <- which(!is.na(type) & type != "element")
  if (length(other)) {
    txt <- html_text(x[other])
    out[other] <- vapply(seq_along(other), function(k) {
      t <- type[other[k]]
      switch(
        t,
        document = "<document>",
        fragment = "<fragment>",
        doctype = paste0("<!DOCTYPE ", name[other[k]], ">"),
        text = paste0("\"", zuh_trunc(txt[k], width - 2L), "\""),
        comment = zuh_trunc(paste0("<!--", txt[k], "-->"), width),
        processing_instruction = zuh_trunc(paste0("<?", txt[k], ">"), width),
        paste0("<", t, ">")
      )
    }, character(1))
  }
  out
}

#' @export
print.zuhtml_nodeset <- function(x, n = 10L, ...) {
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || n < 0 ||
      (is.finite(n) && n != trunc(n))) {
    zuh_input_error("n", "`n` must be a single non-negative whole number.",
                    call = sys.call())
  }
  len <- length(x)
  cat(sprintf("<zuhtml_nodeset[%d]>\n", len))
  show <- seq_len(min(len, n))
  if (length(show)) {
    cat(paste0("[", show, "] ", format(x[show])), sep = "\n")
  }
  if (len > n) cat(sprintf("... and %.0f more\n", len - n))
  invisible(x)
}
