# an invalid input's message is not wrapped as an open failure

    Code
      html_read(1L)
    Condition
      Error in `html_read()`:
      ! `path` must be a single file path, URL or connection.

---

    Code
      html_read(con)
    Condition
      Error in `html_read()`:
      ! An open connection must be in binary mode ("rb").

