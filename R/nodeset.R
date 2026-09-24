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

#' @export
rev.zuhtml_nodeset <- function(x) new_nodeset(rev(unclass(x)), zuh_owner(x))

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

zuh_trunc <- function(s, width) {
  s <- gsub("\n", "\\\\n", s, fixed = TRUE)
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
  len <- length(x)
  cat(sprintf("<zuhtml_nodeset[%d]>\n", len))
  if (len > 0L) {
    show <- seq_len(min(len, n))
    cat(paste0("[", show, "] ", format(x[show])), sep = "\n")
    if (len > n) cat(sprintf("... and %d more\n", len - n))
  }
  invisible(x)
}
