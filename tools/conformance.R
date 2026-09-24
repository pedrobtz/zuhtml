# Run the html5lib tree-construction fixtures in tools/conformance/ against
# zuhtml and compare its tree, rendered in the fixture format, with each
# case's #document. Run by tools/run-conformance from the package root.
#
# Cases are read as upstream Gumbo's own harness reads them
# (tests/tree_construction.cc in the pinned archive): #script-on cases are
# skipped, since Gumbo parses with scripting disabled; everything else runs,
# fragment cases included ("fragment" in the tally counts those, which are
# also counted as passed, failed or rejected).
# A case whose input zuhtml's input contract rejects (a NUL character,
# invalid UTF-8) is counted as rejected, not failed.
#
# Exit status: 0 when every case either passes or is listed with a reason in
# tools/conformance/deviations.txt, and every listed deviation still
# deviates; 1 otherwise.

args <- commandArgs(trailingOnly = TRUE)
verbose <- "--verbose" %in% args
# --canary appends a stray space to every rendered tree: the gate must then
# fail every case, or it cannot see anything.
canary <- "--canary" %in% args

suppressMessages(pkgload::load_all(".", quiet = TRUE, export_all = TRUE))

read_dat <- function(path) {
  bytes <- readBin(path, "raw", file.size(path))
  nl <- which(bytes == as.raw(10L))
  starts <- c(1L, nl + 1L)
  ends <- c(nl - 1L, length(bytes))
  lines <- Map(function(s, e) if (e >= s) bytes[s:e] else raw(), starts, ends)
  text <- vapply(lines, function(l) {
    if (any(l == as.raw(0L))) "\001NUL" else rawToChar(l)
  }, character(1))

  cases <- list()
  cur <- NULL
  section <- ""
  flush <- function() {
    if (is.null(cur)) return()
    input <- cur$input
    if (length(input) > 0L) input <- input[-length(input)]  # final \n
    exp <- sub("\n+$", "", paste0(cur$expected, collapse = ""))
    cur$input <- input
    cur$expected <- if (nzchar(exp)) paste0(exp, "\n") else ""
    cases[[length(cases) + 1L]] <<- cur
  }
  for (i in seq_along(lines)) {
    t <- text[[i]]
    if (identical(t, "#data")) {
      flush()
      cur <- list(file = basename(path), index = length(cases) + 1L, line = i,
                  input = raw(), expected = character(), fragment = "",
                  script_on = FALSE)
      section <- "data"
    } else if (identical(t, "#document")) {
      section <- "document"
    } else if (identical(t, "#document-fragment")) {
      section <- "fragment"
    } else if (identical(t, "#script-on")) {
      section <- "other"
      cur$script_on <- TRUE
    } else if (t %in% c("#errors", "#new-errors", "#script-off")) {
      section <- "other"
    } else if (section == "data") {
      cur$input <- c(cur$input, lines[[i]], as.raw(10L))
    } else if (section == "document") {
      cur$expected <- c(cur$expected, t, "\n")
    } else if (section == "fragment") {
      cur$fragment <- t
      section <- "other"
    }
  }
  flush()
  cases
}

# Parse a case as upstream's harness does: a fragment context is
# "[svg |math ]<name>", looked up in Gumbo's tag table, unknown names
# included.
dump_tree <- function(input, fragment = "") {
  ctx <- NULL
  if (nzchar(fragment)) {
    parts <- strsplit(fragment, " ", fixed = TRUE)[[1L]]
    ns <- if (length(parts) == 2L) {
      if (parts[[1L]] == "svg") 1L else 2L
    } else 0L
    ctx <- zuh_fragment_context(parts[[length(parts)]], NULL, ns,
                                allow_unknown = TRUE)
  }
  doc <- tryCatch(
    zuh_parse(input, NULL, NULL, TRUE, html_limits(), fragment = ctx,
              call = NULL),
    zuhtml_input_error = function(e) "rejected",
    zuhtml_encoding_error = function(e) "rejected"
  )
  if (identical(doc, "rejected")) return(NULL)
  out <- .Call(C_zuh_doc_dump, doc$ptr)
  if (canary) out <- paste0(out, " ")
  out
}

dev_path <- "tools/conformance/deviations.txt"
deviations <- if (file.exists(dev_path)) {
  d <- grep("^[^#[:space:]]", readLines(dev_path), value = TRUE)
  sub("[[:space:]].*$", "", d)
} else {
  character()
}

files <- sort(list.files("tools/conformance/tree-construction",
                         pattern = "\\.dat$", full.names = TRUE))
tally <- c(passed = 0L, failed = 0L, deviating = 0L, rejected = 0L,
           script_on = 0L, fragment = 0L)
unexpected <- character()
seen_dev <- character()
for (f in files) {
  for (c in read_dat(f)) {
    id <- sprintf("%s:%d", c$file, c$index)
    if (c$script_on) { tally[["script_on"]] <- tally[["script_on"]] + 1L; next }
    if (nzchar(c$fragment)) tally[["fragment"]] <- tally[["fragment"]] + 1L
    got <- dump_tree(c$input, c$fragment)
    if (is.null(got)) { tally[["rejected"]] <- tally[["rejected"]] + 1L; next }
    ok <- identical(got, c$expected)
    listed <- id %in% deviations
    if (listed) seen_dev <- c(seen_dev, id)
    if (ok && !listed) {
      tally[["passed"]] <- tally[["passed"]] + 1L
    } else if (!ok && listed) {
      tally[["deviating"]] <- tally[["deviating"]] + 1L
    } else if (ok && listed) {
      unexpected <- c(unexpected, sprintf("%s now passes; remove it from %s", id, dev_path))
    } else {
      tally[["failed"]] <- tally[["failed"]] + 1L
      unexpected <- c(unexpected, sprintf("%s (#data at line %d) fails", id, c$line))
      if (verbose) {
        cat("\n==", id, "\nINPUT:\n", rawToChar(c$input[c$input != as.raw(0L)]),
            "\nGOT:\n", got, "EXPECTED:\n", c$expected, sep = "")
      }
    }
  }
}

stale <- setdiff(deviations, seen_dev)
if (length(stale)) {
  unexpected <- c(unexpected, sprintf("%s is listed but was not run", stale))
}

cat(sprintf("%-10s %d\n", names(tally), tally), sep = "")
if (canary) {
  if (tally[["passed"]] == 0L && tally[["failed"]] > 0L) {
    cat("canary OK: every case failed with a corrupted rendering\n")
    quit(status = 0L)
  }
  cat("CANARY FAILED: corrupted renderings still passed\n")
  quit(status = 1L)
}
if (length(unexpected)) {
  cat("\n", paste0(unexpected, "\n"), sep = "")
  quit(status = 1L)
}
cat("conformance: every case passes or is an adjudicated deviation\n")
