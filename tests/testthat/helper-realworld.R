# Pages from other projects' test suites, in fixtures/realworld/ (see its
# README.md): pandas' read_html() fixtures and Mozilla Readability's
# synthetic test pages, each with the article Readability extracts.
realworld <- function(...) test_path("fixtures", "realworld", ...)

readability_pages <- function() {
  basename(list.dirs(realworld("readability"), recursive = FALSE))
}

# Whitespace-insensitive, for comparing text across two extractors.
squash <- function(x) gsub("[[:space:]]+", " ", x)
