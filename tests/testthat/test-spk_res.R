path <- system.file("extdata", "test1.tif", package = "spacehakr")
crs_out <- "EPSG:32609"
result <- spk_res(path, crs_out)

test_that("spk_res gives expected result", {
  expect_equal(result, c(20, 20))
})
