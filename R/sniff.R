# Encoding sniffing: the HTML standard's prescan of the first 1024 bytes for
# a <meta> charset declaration
# (https://html.spec.whatwg.org/multipage/parsing.html#prescan-a-byte-stream-to-determine-its-encoding),
# with the Encoding Standard's labels (https://encoding.spec.whatwg.org/).

# Encoding name -> its labels, from the Encoding Standard's table.
zuh_enc_table <- list(
  "UTF-8" = c("unicode-1-1-utf-8", "unicode11utf8", "unicode20utf8",
              "utf-8", "utf8", "x-unicode20utf8"),
  "IBM866" = c("866", "cp866", "csibm866", "ibm866"),
  "ISO-8859-2" = c("csisolatin2", "iso-8859-2", "iso-ir-101", "iso8859-2",
                   "iso88592", "iso_8859-2", "iso_8859-2:1987", "l2",
                   "latin2"),
  "ISO-8859-3" = c("csisolatin3", "iso-8859-3", "iso-ir-109", "iso8859-3",
                   "iso88593", "iso_8859-3", "iso_8859-3:1988", "l3",
                   "latin3"),
  "ISO-8859-4" = c("csisolatin4", "iso-8859-4", "iso-ir-110", "iso8859-4",
                   "iso88594", "iso_8859-4", "iso_8859-4:1988", "l4",
                   "latin4"),
  "ISO-8859-5" = c("csisolatincyrillic", "cyrillic", "iso-8859-5",
                   "iso-ir-144", "iso8859-5", "iso88595", "iso_8859-5",
                   "iso_8859-5:1988"),
  "ISO-8859-6" = c("arabic", "asmo-708", "csiso88596e", "csiso88596i",
                   "csisolatinarabic", "ecma-114", "iso-8859-6",
                   "iso-8859-6-e", "iso-8859-6-i", "iso-ir-127", "iso8859-6",
                   "iso88596", "iso_8859-6", "iso_8859-6:1987"),
  "ISO-8859-7" = c("csisolatingreek", "ecma-118", "elot_928", "greek",
                   "greek8", "iso-8859-7", "iso-ir-126", "iso8859-7",
                   "iso88597", "iso_8859-7", "iso_8859-7:1987",
                   "sun_eu_greek"),
  "ISO-8859-8" = c("csiso88598e", "csisolatinhebrew", "hebrew", "iso-8859-8",
                   "iso-8859-8-e", "iso-ir-138", "iso8859-8", "iso88598",
                   "iso_8859-8", "iso_8859-8:1988", "visual"),
  "ISO-8859-8-I" = c("csiso88598i", "iso-8859-8-i", "logical"),
  "ISO-8859-10" = c("csisolatin6", "iso-8859-10", "iso-ir-157",
                    "iso8859-10", "iso885910", "l6", "latin6"),
  "ISO-8859-13" = c("iso-8859-13", "iso8859-13", "iso885913"),
  "ISO-8859-14" = c("iso-8859-14", "iso8859-14", "iso885914"),
  "ISO-8859-15" = c("csisolatin9", "iso-8859-15", "iso8859-15",
                    "iso885915", "iso_8859-15", "l9"),
  "ISO-8859-16" = "iso-8859-16",
  "KOI8-R" = c("cskoi8r", "koi", "koi8", "koi8-r", "koi8_r"),
  "KOI8-U" = c("koi8-ru", "koi8-u"),
  "macintosh" = c("csmacintosh", "mac", "macintosh", "x-mac-roman"),
  "windows-874" = c("dos-874", "iso-8859-11", "iso8859-11", "iso885911",
                    "tis-620", "windows-874"),
  "windows-1250" = c("cp1250", "windows-1250", "x-cp1250"),
  "windows-1251" = c("cp1251", "windows-1251", "x-cp1251"),
  "windows-1252" = c("ansi_x3.4-1968", "ascii", "cp1252", "cp819",
                     "csisolatin1", "ibm819", "iso-8859-1", "iso-ir-100",
                     "iso8859-1", "iso88591", "iso_8859-1",
                     "iso_8859-1:1987", "l1", "latin1", "us-ascii",
                     "windows-1252", "x-cp1252"),
  "windows-1253" = c("cp1253", "windows-1253", "x-cp1253"),
  "windows-1254" = c("cp1254", "csisolatin5", "iso-8859-9", "iso-ir-148",
                     "iso8859-9", "iso88599", "iso_8859-9", "iso_8859-9:1989",
                     "l5", "latin5", "windows-1254", "x-cp1254"),
  "windows-1255" = c("cp1255", "windows-1255", "x-cp1255"),
  "windows-1256" = c("cp1256", "windows-1256", "x-cp1256"),
  "windows-1257" = c("cp1257", "windows-1257", "x-cp1257"),
  "windows-1258" = c("cp1258", "windows-1258", "x-cp1258"),
  "x-mac-cyrillic" = c("x-mac-cyrillic", "x-mac-ukrainian"),
  "GBK" = c("chinese", "csgb2312", "csiso58gb231280", "gb2312", "gb_2312",
            "gb_2312-80", "gbk", "iso-ir-58", "x-gbk"),
  "gb18030" = "gb18030",
  "Big5" = c("big5", "big5-hkscs", "cn-big5", "csbig5", "x-x-big5"),
  "EUC-JP" = c("cseucpkdfmtjapanese", "euc-jp", "x-euc-jp"),
  "ISO-2022-JP" = c("csiso2022jp", "iso-2022-jp"),
  "Shift_JIS" = c("csshiftjis", "ms932", "ms_kanji", "shift-jis",
                  "shift_jis", "sjis", "windows-31j", "x-sjis"),
  "EUC-KR" = c("cseuckr", "csksc56011987", "euc-kr", "iso-ir-149", "korean",
               "ks_c_5601-1987", "ks_c_5601-1989", "ksc5601", "ksc_5601",
               "windows-949"),
  "replacement" = c("csiso2022kr", "hz-gb-2312", "iso-2022-cn",
                    "iso-2022-cn-ext", "iso-2022-kr", "replacement"),
  "UTF-16BE" = c("unicodefffe", "utf-16be"),
  "UTF-16LE" = c("csunicode", "iso-10646-ucs-2", "ucs-2", "unicode",
                 "unicodefeff", "utf-16", "utf-16le"),
  "x-user-defined" = "x-user-defined"
)

zuh_enc_labels <- stats::setNames(
  rep(names(zuh_enc_table), lengths(zuh_enc_table)),
  unlist(zuh_enc_table, use.names = FALSE)
)

# iconv() names to try for each encoding the prescan can return, where the
# Encoding Standard's name may not be one, in order; iconv implementations
# differ (glibc, libiconv, and win_iconv on Windows). Where the standard's
# encoding is a superset of an older one, the superset comes first.
zuh_enc_iconv <- list(
  "IBM866" = "CP866", "ISO-8859-8-I" = "ISO-8859-8",
  "macintosh" = c("MACINTOSH", "MACROMAN", "CP10000"),
  "windows-874" = "CP874", "windows-1250" = "CP1250",
  "windows-1251" = "CP1251", "windows-1252" = "CP1252",
  "windows-1253" = "CP1253", "windows-1254" = "CP1254",
  "windows-1255" = "CP1255", "windows-1256" = "CP1256",
  "windows-1257" = "CP1257", "windows-1258" = "CP1258",
  "x-mac-cyrillic" = c("MACCYRILLIC", "MAC-CYRILLIC", "CP10007"),
  "Big5" = c("BIG5-HKSCS", "BIG5", "CP950"),
  "Shift_JIS" = c("CP932", "SHIFT_JIS"), "EUC-KR" = c("CP949", "EUC-KR")
)

# The iconv() name for an encoding the prescan returned: the first
# candidate this iconv() knows, else the first (which then fails as
# unsupported).
zuh_iconv_name <- function(enc) {
  cand <- if (enc %in% names(zuh_enc_iconv)) zuh_enc_iconv[[enc]] else enc
  for (c in cand) {
    ok <- tryCatch(!is.na(iconv("a", c, "UTF-8")), error = function(e) FALSE,
                   warning = function(w) FALSE)
    if (ok) return(c)
  }
  cand[[1L]]
}

# "Get an encoding": the encoding a label names, or NA.
zuh_enc_label <- function(label) {
  label <- tolower(sub("^[\t\n\f\r ]+", "", sub("[\t\n\f\r ]+$", "", label)))
  unname(zuh_enc_labels[label])
}

zuh_bytes_chr <- function(v) {
  v[v == 0L] <- 1L
  rawToChar(as.raw(v))
}

# The encoding the first 1024 bytes of `x` declare, as
# list(encoding = <Encoding Standard name>, label = <as written>), or NULL.
# A UTF-16 label means UTF-8, and x-user-defined means windows-1252, as the
# standard says.
zuh_prescan <- function(x) {
  b <- as.integer(x[seq_len(min(length(x), 1024L))])
  n <- length(b)
  ws <- c(9L, 10L, 12L, 13L, 32L)
  lower <- function(v) if (v >= 65L && v <= 90L) v + 32L else v
  alpha <- function(v) (v >= 65L && v <= 90L) || (v >= 97L && v <= 122L)
  at <- function(i, s) {
    k <- utf8ToInt(s)
    j <- i + seq_along(k) - 1L
    j[length(j)] <= n &&
      all(vapply(b[j], lower, 0L) == k)
  }
  # The position just after the next `s` at or after i, or NA.
  after <- function(i, s) {
    if (i > n) return(NA_integer_)
    p <- grepRaw(s, as.raw(b), offset = i, fixed = TRUE)
    if (length(p) == 0L) NA_integer_ else p + nchar(s)
  }

  # "Get an attribute": list(name, value, i), list(none = TRUE, i) at a
  # ">", or NULL at the end of the window.
  get_attr <- function(i) {
    while (i <= n && (b[i] %in% ws || b[i] == 47L)) i <- i + 1L
    if (i > n) return(NULL)
    if (b[i] == 62L) return(list(none = TRUE, i = i))
    name <- integer()
    value <- integer()
    repeat {
      c <- b[i]
      if (c == 61L && length(name)) {
        i <- i + 1L
        break
      }
      if (c %in% ws) {
        while (i <= n && b[i] %in% ws) i <- i + 1L
        if (i > n) return(NULL)
        if (b[i] != 61L) return(list(name = name, value = value, i = i))
        i <- i + 1L
        break
      }
      if (c == 47L || c == 62L) {
        return(list(name = name, value = value, i = i))
      }
      name <- c(name, lower(c))
      i <- i + 1L
      if (i > n) return(NULL)
    }
    while (i <= n && b[i] %in% ws) i <- i + 1L
    if (i > n) return(NULL)
    c <- b[i]
    if (c == 34L || c == 39L) {
      i <- i + 1L
      repeat {
        if (i > n) return(NULL)
        if (b[i] == c) return(list(name = name, value = value, i = i + 1L))
        value <- c(value, lower(b[i]))
        i <- i + 1L
      }
    }
    if (c == 62L) return(list(name = name, value = value, i = i))
    repeat {
      value <- c(value, lower(b[i]))
      i <- i + 1L
      if (i > n) return(NULL)
      if (b[i] %in% ws || b[i] == 62L) {
        return(list(name = name, value = value, i = i))
      }
    }
  }

  i <- 1L
  while (i <= n) {
    if (at(i, "<!--")) {
      i <- after(i + 2L, "-->")
      if (is.na(i)) return(NULL)
      next
    }
    if (at(i, "<meta") && i + 5L <= n && (b[i + 5L] %in% c(ws, 47L))) {
      i <- i + 5L
      seen <- character()
      got_pragma <- FALSE
      need_pragma <- NA
      charset <- NULL
      label <- NULL
      repeat {
        a <- get_attr(i)
        if (is.null(a)) return(NULL)
        i <- a$i
        if (isTRUE(a$none)) break
        name <- zuh_bytes_chr(a$name)
        if (name %in% seen) next
        seen <- c(seen, name)
        value <- zuh_bytes_chr(a$value)
        if (name == "http-equiv") {
          if (value == "content-type") got_pragma <- TRUE
        } else if (name == "content") {
          if (is.null(charset)) {
            found <- zuh_meta_charset(a$value)
            if (!is.null(found)) {
              enc <- zuh_enc_label(zuh_bytes_chr(found))
              if (!is.na(enc)) {
                charset <- enc
                label <- zuh_bytes_chr(found)
                need_pragma <- TRUE
              }
            }
          }
        } else if (name == "charset") {
          charset <- zuh_enc_label(value)
          label <- value
          need_pragma <- FALSE
        }
      }
      if (!is.na(need_pragma) && (!need_pragma || got_pragma) &&
          !is.null(charset) && !is.na(charset)) {
        if (charset %in% c("UTF-16BE", "UTF-16LE")) charset <- "UTF-8"
        if (charset == "x-user-defined") charset <- "windows-1252"
        return(list(encoding = charset, label = label))
      }
      i <- i + 1L
      next
    }
    if (b[i] == 60L && i + 1L <= n &&
        (alpha(b[i + 1L]) ||
         (b[i + 1L] == 47L && i + 2L <= n && alpha(b[i + 2L])))) {
      while (i <= n && !(b[i] %in% ws) && b[i] != 62L) i <- i + 1L
      repeat {
        a <- get_attr(i)
        if (is.null(a)) return(NULL)
        i <- a$i
        if (isTRUE(a$none)) break
      }
      i <- i + 1L
      next
    }
    if (at(i, "<!") || at(i, "</") || at(i, "<?")) {
      i <- after(i + 2L, ">")
      if (is.na(i)) return(NULL)
      next
    }
    i <- i + 1L
  }
  NULL
}

# "Extract a character encoding from a meta element": the bytes of the
# charset in a content attribute's (lowercased) value, or NULL.
zuh_meta_charset <- function(v) {
  n <- length(v)
  ws <- c(9L, 10L, 12L, 13L, 32L)
  key <- utf8ToInt("charset")
  i <- 1L
  repeat {
    hit <- NA_integer_
    j <- i
    while (j + 6L <= n) {
      if (all(v[j:(j + 6L)] == key)) {
        hit <- j
        break
      }
      j <- j + 1L
    }
    if (is.na(hit)) return(NULL)
    i <- hit + 7L
    while (i <= n && v[i] %in% ws) i <- i + 1L
    if (i > n) return(NULL)
    if (v[i] != 61L) next
    i <- i + 1L
    while (i <= n && v[i] %in% ws) i <- i + 1L
    if (i > n) return(NULL)
    if (v[i] == 34L || v[i] == 39L) {
      close <- which(v[-seq_len(i)] == v[i])
      if (length(close) == 0L) return(NULL)
      return(v[seq_len(close[1L] - 1L) + i])
    }
    end <- i
    while (end <= n && !(v[end] %in% c(ws, 59L))) end <- end + 1L
    return(v[i:(end - 1L)])
  }
}
