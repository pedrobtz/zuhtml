test_that("the compiled library is loaded", {
  expect_true("zuhtml" %in% names(getLoadedDLLs()))
})

test_that("native routines are registered and dynamic lookup is off", {
  dll <- getLoadedDLLs()[["zuhtml"]]
  expect_false(unclass(dll)[["dynamicLookup"]])
  routines <- getDLLRegisteredRoutines(dll)
  expect_true("C_zuh_loaded" %in% names(routines$.Call))
})

test_that("the smoke entry point is callable", {
  expect_true(.Call(C_zuh_loaded))
})
