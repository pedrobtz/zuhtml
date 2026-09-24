# Conditions raised by zuhtml

Every error zuhtml raises is a condition of class `zuhtml_error` with
one more specific subclass. Handle them by class, for example with
`tryCatch(..., zuhtml_limit_error = function(e) ...)`, never by matching
the message text, which may change.

## Details

- `zuhtml_input_error`: an argument is invalid, for example `x` is not a
  single string or raw vector, a file does not exist, or a limit is not
  a whole number in range. Field `arg` names the argument.

- `zuhtml_encoding_error`: raw input cannot be decoded: an unknown
  encoding, a byte sequence invalid in the declared encoding, or a
  byte-order mark that contradicts `encoding`. Field `encoding`.

- `zuhtml_limit_error`: a resource limit from
  [`html_limits()`](https://pedrobtz.github.io/zuhtml/reference/html_limits.md)
  was exceeded. Fields `limit` (its name, such as `"max_depth"`),
  `maximum` (its value) and `observed` (the value that tripped it, where
  known). Nothing is returned and all native memory is released.

- `zuhtml_parse_error`: an internal invariant of the parser failed. This
  is a bug; please report it.

- `zuhtml_pointer_error`: a document is no longer available, for example
  because it was restored from a saved R session. Parse the HTML again.

Recoverable HTML errors, such as a missing end tag, are not conditions:
they are repaired as a browser would repair them and recorded for
[`html_problems()`](https://pedrobtz.github.io/zuhtml/reference/html_problems.md).
