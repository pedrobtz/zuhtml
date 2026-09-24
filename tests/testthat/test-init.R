test_that("the compiled library is loaded", {
  expect_true("zuhtml" %in% names(getLoadedDLLs()))
})

test_that("native routines are registered and dynamic lookup is off", {
  dll <- getLoadedDLLs()[["zuhtml"]]
  expect_false(unclass(dll)[["dynamicLookup"]])
  routines <- getDLLRegisteredRoutines(dll)
  expect_true("C_zuhtml_info" %in% names(routines$.Call))
})
