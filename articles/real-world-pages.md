# Real-world pages: long tables, lists and text

The other guides use small, made-up snippets. This one works on real,
plain, old-style pages: CRAN’s own package lists and mirror list, the R
FAQ, Project Gutenberg’s top-100 lists, and the directory listings web
servers write. They are the kind of page zuhtml is built for: large,
table- and list-shaped, and written long before anyone thought of them
as data.

This article is built with the package website only, because it fetches
live pages. The numbers in it are from the day the site was last built.

``` r

library(zuhtml)
```

zuhtml never downloads anything. Each page is fetched once into a
temporary file, and
[`html_read()`](https://pedrobtz.github.io/zuhtml/reference/html_parse.md)
parses the file:

``` r

fetch <- function(url) {
  path <- tempfile(fileext = ".html")
  utils::download.file(url, path, quiet = TRUE, mode = "wb")
  path
}
cran <- "https://cran.r-project.org/"
```

## A long table: every CRAN package

`available_packages_by_name.html` is one table with a row per package,
about 25,000 rows and several megabytes of HTML.

``` r

by_name <- html_read(
  fetch(paste0(cran, "web/packages/available_packages_by_name.html")),
  base_url = paste0(cran, "web/packages/available_packages_by_name.html")
)
html_info(by_name)[c("nodes", "input_bytes", "native_bytes")]
#> $nodes
#> [1] 226921
#> 
#> $input_bytes
#> [1] 4165766
#> 
#> $native_bytes
#> [1] 13570635

packages <- html_tables(by_name)[[1]]
dim(packages)
#> [1] 25204     2
head(packages)
#>              V1
#> 1              
#> 2     a11yShiny
#> 3           a5R
#> 4       aae.pop
#> 5 AalenJohansen
#> 6       aamatch
#>                                                                            V2
#> 1                                                                            
#> 2                     Accessibility Enhancements to Popular R Shiny Functions
#> 3                                            'A5' Discrete Global Grid System
#> 4                                    Flexible Population Dynamics Simulations
#> 5                                       Conditional Aalen-Johansen Estimation
#> 6 Artless Automatic or Artful Multivariate Matching for Observational Studies
```

The table has no header row, so the columns are `V1` and `V2`, and a few
rows are empty: they are the targets of the A-to-Z index at the top of
the page. The markup says so, which makes a more precise extraction
possible. The index rows carry an `id`, the package rows do not, and
each package row has a link:

``` r

rows <- html_elements(by_name, "table tr:not([id])")
length(rows)
#> [1] 25178

packages <- data.frame(
  package = html_text_clean(html_element(rows, "td:first-child")),
  title = html_text_clean(html_element(rows, "td:nth-child(2)")),
  url = html_url(html_element(rows, "a"))
)
head(packages, 3)
#>     package                                                   title
#> 1 a11yShiny Accessibility Enhancements to Popular R Shiny Functions
#> 2       a5R                        'A5' Discrete Global Grid System
#> 3   aae.pop                Flexible Population Dynamics Simulations
#>                                                            url
#> 1 https://cran.r-project.org/web/packages/a11yShiny/index.html
#> 2       https://cran.r-project.org/web/packages/a5R/index.html
#> 3   https://cran.r-project.org/web/packages/aae.pop/index.html
```

[`html_element()`](https://pedrobtz.github.io/zuhtml/reference/html_elements.md)
returns one result per row, so the three columns line up even if some
row lacked a link.
[`html_url()`](https://pedrobtz.github.io/zuhtml/reference/html_url.md)
resolves the relative `../../web/packages/...` links against the page’s
address.

With a data frame, the rest is ordinary R:

``` r

first <- toupper(substr(packages$package, 1, 1))
head(sort(table(first), decreasing = TRUE))
#> first
#>    S    R    C    M    P    G 
#> 2841 2383 2033 2023 1810 1491
head(packages$package[grepl("\\bshiny\\b", packages$title, ignore.case = TRUE)])
#> [1] "a11yShiny"     "abstractr"     "activAnalyzer" "adepro"       
#> [5] "AdverseEvents" "airGRteaching"
```

## A table with a header: packages by publication date

The same list sorted by date has a header row, so
[`html_table()`](https://pedrobtz.github.io/zuhtml/reference/html_table.md)
names the columns itself:

``` r

by_date <- html_read(
  fetch(paste0(cran, "web/packages/available_packages_by_date.html"))
)
recent <- html_tables(by_date)[[1]]
names(recent)
#> [1] "Date"    "Package" "Title"
head(recent, 3)
#>         Date          Package
#> 1 2026-09-24 AI4OfficialStats
#> 2 2026-09-24        autotestR
#> 3 2026-09-24       BarcodingR
#>                                                           Title
#> 1 Audit Statistical Fidelity of AI-Mediated Official Statistics
#> 2               Automated Functions for Basic Statistical Tests
#> 3                     Species Identification using DNA Barcodes

year <- substr(recent$Date, 1, 4)
tail(table(year), 8)
#> year
#> 2019 2020 2021 2022 2023 2024 2025 2026 
#>  611  919 1152 1640 2278 2769 5281 8960
```

Dates stay character, as every cell does: convert them when you know
they are dates.

``` r

range(as.Date(recent$Date))
#> [1] "2011-09-07" "2026-09-24"
```

## Many small tables: CRAN mirrors

The mirror list is a definition list: each `<dt>` names a country, and
the `<dd>` after it holds a table of that country’s mirrors.

``` r

mirrors_page <- html_read(fetch(paste0(cran, "mirrors.html")))
countries <- html_elements(mirrors_page, "dt")
length(countries)
#> [1] 41
head(html_text_clean(countries))
#> [1] "0-Cloud"   "Argentina" "Australia" "Austria"   "Belgium"   "Brazil"
```

[`html_next_sibling()`](https://pedrobtz.github.io/zuhtml/reference/html_children.md)
is aligned, one result per `<dt>`, so each country’s table can be read
beside its name:

``` r

mirrors <- do.call(rbind, lapply(countries, function(dt) {
  tab <- html_element(html_next_sibling(dt), "table")
  rows <- html_table(tab, header = FALSE)
  data.frame(country = html_text_clean(dt), url = rows$V1, host = rows$V2)
}))
nrow(mirrors)
#> [1] 83
head(mirrors[, c("country", "url")])
#>     country                                    url
#> 1   0-Cloud           https://cloud.r-project.org/
#> 2 Argentina http://mirror.fcaglp.unlp.edu.ar/CRAN/
#> 3 Australia                 https://cran.csiro.au/
#> 4 Australia https://mirror.aarnet.edu.au/pub/CRAN/
#> 5 Australia        https://cran.ms.unimelb.edu.au/
#> 6   Austria                 https://cran.wu.ac.at/
sort(table(mirrors$country), decreasing = TRUE)[1:5]
#> 
#>     China       USA   Germany Australia    Brazil 
#>        14        10         7         3         3
```

## Lists of strings: Project Gutenberg’s top 100

Project Gutenberg’s top-100 page has six ordered lists, each under a
heading:

``` r

top <- html_read(fetch("https://www.gutenberg.org/browse/scores/top"))
html_text_clean(html_elements(top, "h2"))
#> [1] "Top 100 EBooks yesterday"     "Top 100 Authors yesterday"   
#> [3] "Top 100 EBooks last 7 days"   "Top 100 Authors last 7 days" 
#> [5] "Top 100 EBooks last 30 days"  "Top 100 Authors last 30 days"
```

[`html_list()`](https://pedrobtz.github.io/zuhtml/reference/html_list.md)
reads one list into a character vector, one string per item. The lists
are the `<ol>`s right after a heading, and
[`html_previous_sibling()`](https://pedrobtz.github.io/zuhtml/reference/html_children.md),
being aligned, gives each list’s heading:

``` r

ols <- html_elements(top, "h2 + ol")
lists <- lapply(ols, html_list)
names(lists) <- html_text_clean(html_previous_sibling(ols))
lengths(lists)
#>     Top 100 EBooks yesterday    Top 100 Authors yesterday 
#>                          100                          100 
#>   Top 100 EBooks last 7 days  Top 100 Authors last 7 days 
#>                          100                          100 
#>  Top 100 EBooks last 30 days Top 100 Authors last 30 days 
#>                          100                          100
head(lists[["Top 100 EBooks yesterday"]])
#> [1] "Moby Dick; Or, The Whale by Herman Melville (7134)"
#> [2] "Pride and Prejudice by Jane Austen (7123)"         
#> [3] "The Odyssey by Homer (5768)"                       
#> [4] "A Room with a View by E. M. Forster (5195)"        
#> [5] "Crime and Punishment by Fyodor Dostoyevsky (4859)" 
#> [6] "The Secret of Chimneys by Agatha Christie (4800)"
```

Each item is a string of the form “Title by Author (downloads)”. Plain
string handling turns a list into a data frame:

``` r

books <- lists[["Top 100 EBooks last 30 days"]]
m <- regmatches(books, regexec("^(.*) by (.*) \\(([0-9]+)\\)$", books))
ok <- lengths(m) == 4
top30 <- data.frame(
  title = vapply(m[ok], `[`, "", 2),
  author = vapply(m[ok], `[`, "", 3),
  downloads = as.integer(vapply(m[ok], `[`, "", 4))
)
head(top30)
#>                      title              author downloads
#> 1 Moby Dick; Or, The Whale     Herman Melville    190821
#> 2      Pride and Prejudice         Jane Austen    186807
#> 3              The Odyssey               Homer    147299
#> 4       A Room with a View       E. M. Forster    144510
#> 5         Romeo and Juliet William Shakespeare    133750
#> 6     Crime and Punishment  Fyodor Dostoyevsky    126752
```

A few items have no author, and the pattern skips them (3 this time).

## Text: the R FAQ

The R FAQ is a long page of prose, lists and code. Its headings are the
table of contents:

``` r

faq <- html_read(fetch(paste0(cran, "doc/FAQ/R-FAQ.html")))
headings <- html_text_clean(html_elements(faq, "h2, h3"))
length(headings)
#> [1] 95
head(sub(" \u00b6$", "", headings), 8)
#> [1] "Table of Contents"           "1 Introduction"             
#> [3] "1.1 Legalese"                "1.2 Obtaining this document"
#> [5] "1.3 Citing this document"    "1.4 Notation"               
#> [7] "1.5 Feedback"                "2 R Basics"
```

(The `¶` is the text of the permalink next to each heading.)

Each numbered section is a `div` holding its heading, its paragraphs and
a navigation bar, which is itself a paragraph, `<p class="nav-panel">`.
Reading every section into a list of paragraph strings takes one aligned
call for the titles and one
[`lapply()`](https://rdrr.io/r/base/lapply.html) for the bodies.
`:scope > p:not(.nav-panel)` keeps the section’s own paragraphs, not
those of nested elements, and leaves out the navigation bar:

``` r

sections <- html_elements(faq, "div.section-level-extent")
titles <- sub(" \u00b6$", "", html_text_clean(html_element(sections, "h3")))
paragraphs <- lapply(sections, function(s) {
  html_text_clean(html_elements(s, ":scope > p:not(.nav-panel)"))
})
names(paragraphs) <- titles
length(paragraphs)
#> [1] 84
paragraphs[["2.1 What is R?"]]
#> [1] "R is a system for statistical computation and graphics. It consists of a language plus a run-time environment with graphics, a debugger, access to certain system functions, and the ability to run programs stored in script files."                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                
#> [2] "The design of R has been heavily influenced by two existing languages: Becker, Chambers & Wilks’ S (see What is S?) and Sussman’s Scheme. Whereas the resulting language is very similar in appearance to S, the underlying implementation and semantics are derived from Scheme. See What are the differences between R and S?, for further details."                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               
#> [3] "The core of R is an interpreted computer language which allows branching and looping as well as modular programming using functions. Most of the user-visible functions in R are written in R. It is possible for the user to interface to procedures written in the C, C++, or FORTRAN languages for efficiency. The R distribution contains functionality for a large number of statistical procedures. Among these are: linear and generalized linear models, nonlinear regression models, time series analysis, classical parametric and nonparametric tests, clustering and smoothing. There is also a large set of functions which provide a flexible graphical environment for creating various kinds of data presentations. Additional modules (“add-on packages”) are available for a variety of specific purposes (see R Add-On Packages)."
#> [4] "R was initially written by Ross Ihaka and Robert Gentleman at the Department of Statistics of the University of Auckland in Auckland, New Zealand. In addition, a large group of individuals has contributed to R by sending code and bug reports."                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  
#> [5] "Since mid-1997 there has been a core group (the “R Core Team”) who can modify the R source code archive, currently consisting of"                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    
#> [6] "plus Heiner Schwarte up to October 1999, Guido Masarotto up to June 2003, Stefano Iacus up to July 2014, Seth Falcon up to August 2015, Duncan Murdoch up to September 2017, Martin Morgan up to June 2021, Douglas Bates up to March 2024, and Friedrich Leisch up to April 2024."                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  
#> [7] "R has a home page at https://www.R-project.org/. It is free software distributed under a GNU-style copyleft, and an official part of the GNU project (“GNU S”)."
```

[`html_text_clean()`](https://pedrobtz.github.io/zuhtml/reference/html_text_clean.md)
collapses whitespace and drops markup, which suits prose. For code,
[`html_text()`](https://pedrobtz.github.io/zuhtml/reference/html_text.md)
keeps the text exactly as written:

``` r

code <- html_elements(faq, "pre.example-preformatted")
length(code)
#> [1] 73
cat(html_text(code[[1]]))
#> @Misc{,
#>   author        = {Kurt Hornik and the R Core Team},
#>   title         = {{R} {FAQ}},
#>   year          = {2026},
#>   url           = {https://CRAN.R-project.org/doc/manuals/R-FAQ.html}
#> }
```

Lists inside the prose come out one string per item:

``` r

bullets <- html_elements(faq, "div.section-level-extent ul")
length(bullets)
#> [1] 8
html_list(bullets[[1]])
#> [1] "How can R be installed (Unix-like)" "How can R be installed (Windows)"  
#> [3] "How can R be installed (Mac)"
```

## Directory listings

Web servers that list a directory’s files write the oldest-style pages
of all: a title “Index of /path”, a link to the parent directory at the
top, then one line per file. There are two common layouts, and both are
easy to read with the right tool.

### Listings as tables

Apache’s fancy index, used by CRAN and by GNU’s mirror, is a table: a
header row, a row holding only a rule (`<hr>`), then one row per entry,
the first being “Parent Directory”.

``` r

r4_url <- paste0(cran, "src/base/R-4/")
r4 <- html_read(fetch(r4_url), base_url = r4_url)
html_text_clean(html_element(r4, "title"))
#> [1] "Index of /src/base/R-4"

listing <- html_tables(r4)[[1]]
head(listing, 3)
#>   V1             Name    Last modified Size Description
#> 1    Parent Directory                     -            
#> 2      R-4.0.0.tar.gz 2020-04-24 09:05  32M            
#> 3      R-4.0.1.tar.gz 2020-06-06 09:05  32M
```

Both leading rows are all `<th>` cells, so
[`html_table()`](https://pedrobtz.github.io/zuhtml/reference/html_table.md)
takes them as the header; the rule row is empty and adds nothing to the
names. The first column holds only an icon. Its `alt` text says what
each entry is, which the table’s cleaned text cannot see, so read it
separately, starting from the link in each entry’s second cell:

``` r

entries <- html_elements(r4, "tr td:nth-child(2) a")
kind <- html_attr(html_element(html_parent(html_parent(entries)), "img"), "alt")
table(kind)
#> kind
#>       [   ] [PARENTDIR] 
#>          39           1

files <- data.frame(
  name = html_text(entries),
  url = html_url(entries),
  kind = kind
)
files <- files[files$kind != "[PARENTDIR]", ]
tail(files, 3)
#>              name                                                    url  kind
#> 38 R-4.6.0.tar.xz https://cran.r-project.org/src/base/R-4/R-4.6.0.tar.xz [   ]
#> 39 R-4.6.1.tar.gz https://cran.r-project.org/src/base/R-4/R-4.6.1.tar.gz [   ]
#> 40 R-4.6.1.tar.xz https://cran.r-project.org/src/base/R-4/R-4.6.1.tar.xz [   ]
```

The parent-directory link is an absolute path, `/src/base/`, and
[`html_url()`](https://pedrobtz.github.io/zuhtml/reference/html_url.md)
resolves it against the listing’s address, so walking up a level is one
more
[`html_read()`](https://pedrobtz.github.io/zuhtml/reference/html_parse.md):

``` r

parent_url <- html_url(html_element(r4, "a:not([href^='?'])"))
parent_url
#> [1] "https://cran.r-project.org/src/base/"
parent <- html_read(fetch(parent_url), base_url = parent_url)
# Subdirectories end in "/"; the parent link is absolute, the rest are not.
subdirs <- html_elements(
  parent, "tr td:nth-child(2) a[href$='/']:not([href^='/'])"
)
html_text(subdirs)
#> [1] "Historic/" "R-0/"      "R-1/"      "R-2/"      "R-3/"      "R-4/"
```

The sizes (`32M`) are text. A small helper turns the suffixes into
bytes:

``` r

size_bytes <- function(x) {
  x <- trimws(x)
  mult <- c(K = 2^10, M = 2^20, G = 2^30)[substring(x, nchar(x))]
  num <- suppressWarnings(as.numeric(sub("[KMG]$", "", x)))
  ifelse(is.na(mult), num, num * mult)
}
listing <- listing[grepl("tar\\.gz$", listing$Name), ]
listing$bytes <- size_bytes(listing$Size)
head(listing[, c("Name", "Last modified", "bytes")], 3)
#>             Name    Last modified    bytes
#> 2 R-4.0.0.tar.gz 2020-04-24 09:05 33554432
#> 3 R-4.0.1.tar.gz 2020-06-06 09:05 33554432
#> 4 R-4.0.2.tar.gz 2020-06-22 09:05 33554432
```

### Listings as preformatted text

nginx, which serves kernel.org, writes the listing inside one `<pre>`: a
link, then plain text with the date and size, then a newline, for each
file.

    <pre><a href="../">../</a>
    <a href="ChangeLog-6.0">ChangeLog-6.0</a>        03-Oct-2022 05:09     14M

There is no cell to select for the date. It is the text node after each
link, and `html_next_sibling(..., elements_only = FALSE)` returns
exactly that, one per link, aligned:

``` r

kernel_url <- "https://cdn.kernel.org/pub/linux/kernel/v6.x/"
kernel <- html_read(fetch(kernel_url), base_url = kernel_url)
links <- html_elements(kernel, "pre > a:not([href='../'])")
length(links)
#> [1] 3703

after <- html_text(html_next_sibling(links, elements_only = FALSE))
fields <- strsplit(trimws(after), "[[:space:]]+")
head(fields, 3)
#> [[1]]
#> [1] "-"
#> 
#> [[2]]
#> [1] "-"
#> 
#> [[3]]
#> [1] "03-Oct-2022" "05:09"       "14M"

is_file <- lengths(fields) == 3
releases <- data.frame(
  name = html_text(links)[is_file],
  date = vapply(fields[is_file], `[`, "", 1),
  size = size_bytes(vapply(fields[is_file], `[`, "", 3)),
  url = html_url(links[is_file])
)
tarballs <- releases[grepl("^linux-6\\.[0-9.]+\\.tar\\.xz$", releases$name), ]
nrow(tarballs)
#> [1] 740
tail(tarballs[, c("name", "date", "size")], 3)
#>                      name        date      size
#> 2954 linux-6.19.12.tar.xz 11-Apr-2026 156237824
#> 2957 linux-6.19.13.tar.xz 18-Apr-2026 156237824
#> 2960 linux-6.19.14.tar.xz 22-Apr-2026 156237824
```

The dates are written like `03-Oct-2022`; month names are English
whatever the locale, so parse them in the C locale:

``` r

old <- Sys.getlocale("LC_TIME")
invisible(Sys.setlocale("LC_TIME", "C"))
tarballs$date <- as.Date(tarballs$date, format = "%d-%b-%Y")
invisible(Sys.setlocale("LC_TIME", old))
range(tarballs$date)
#> [1] "2022-10-03" "2026-09-21"
```

Apache writes the same preformatted layout when fancy indexing is on but
tables are off, as on archive.apache.org. The header links there sort
the listing (`?C=N;O=D`), and an attribute selector leaves them out:

``` r

httpd_url <- "https://archive.apache.org/dist/httpd/"
httpd <- html_read(fetch(httpd_url), base_url = httpd_url)
all_links <- html_elements(httpd, "pre a")
head(html_text(all_links), 5)
#> [1] "Name"             "Last modified"    "Size"             "Description"     
#> [5] "Parent Directory"
entries <- html_elements(httpd, "pre a:not([href^='?'])")
entries <- entries[html_text(entries) != "Parent Directory"]
head(html_text(entries[grepl("/$", html_attr(entries, "href"))]))
#> [1] "beta/"     "binaries/" "contrib/"  "docs/"     "flood/"    "libapreq/"
```

## A very large page, and the limits

CRAN’s check summary, with one row per package and one column per check
flavor, is tens of megabytes of HTML: larger than the default
`max_input` of 16 MiB.

``` r

summary_page <- fetch(paste0(cran, "web/checks/check_summary_by_package.html"))
file.size(summary_page) / 2^20
#> [1] 52.25634
err <- tryCatch(html_read(summary_page), zuhtml_limit_error = function(e) e)
err$limit
#> [1] "max_input"
```

Limits are per call, so a trusted page can simply be given more room:

``` r

big <- html_limits(max_input = 128 * 2^20, max_memory = 4 * 2^30)
checks <- html_read(summary_page, limits = big)
html_info(checks)[c("nodes", "native_bytes", "parse_peak_bytes")]
#> $nodes
#> [1] 2574065
#> 
#> $native_bytes
#> [1] 166213236
#> 
#> $parse_peak_bytes
#> [1] 621746241
status <- html_tables(checks, limits = big)[[1]]
dim(status)
#> [1] 25714    17
names(status)[1:4]
#> [1] "Package"                               
#> [2] "Version"                               
#> [3] "r-devel\nLinux\nx86_64\n(Debian Clang)"
#> [4] "r-devel\nLinux\nx86_64\n(Debian GCC)"
```

The flavor names contain line breaks because the header cells do: they
are written `r-devel<br>Linux<br>...`, and cleaned text turns `<br>`
into `"\n"`. Replace them if single-line names suit better:

``` r

names(status) <- gsub("\n", " ", names(status))
names(status)[1:4]
#> [1] "Package"                             "Version"                            
#> [3] "r-devel Linux x86_64 (Debian Clang)" "r-devel Linux x86_64 (Debian GCC)"
table(status[[3]])[1:5]
#> 
#>       ERROR  NOTE NOTE*    OK 
#>   631    64  5615    12 19345
```
