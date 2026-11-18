# zuhtml.so exports R_init_zuhtml and nothing else: no zuh_ symbol and none
# of Gumbo's, which another package's copy of the parser could collide with.

test_that("the shared object exports exactly R_init_zuhtml", {
  skip_on_cran()
  skip_on_os("windows")
  # covr links the gcov runtime into the shared object, which exports its own
  # symbols.
  skip_if(nzchar(Sys.getenv("R_COVR")), "coverage build")
  skip_if(!nzchar(Sys.which("nm")), "nm not available")
  path <- getLoadedDLLs()[["zuhtml"]][["path"]]
  syms <- exported_symbols(path)
  skip_if(is.null(syms))
  # An instrumented build links a runtime that exports symbols of its own;
  # every R-CMD-check leg runs this test on the shared object CRAN builds.
  skip_if(any(grepl("gcov|llvm_prf|llvm_profile", syms)), "instrumented build")
  expect_identical(syms, "R_init_zuhtml")
})
