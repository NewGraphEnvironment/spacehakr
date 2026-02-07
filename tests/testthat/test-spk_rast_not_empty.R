test_that("spk_rast_not_empty returns TRUE for raster with data", {
  skip_if_not_installed("terra")
  
  # Use existing test raster with data
  f <- system.file("extdata", "test1.tif", package = "spacehakr")
  
  result <- spk_rast_not_empty(f)
  
  expect_type(result, "logical")
  expect_true(result)
})

test_that("spk_rast_not_empty returns FALSE for empty raster (all zeros)", {
  skip_if_not_installed("terra")
  
  # Create temporary empty raster
  f <- tempfile(fileext = ".tif")
  on.exit(unlink(f), add = TRUE)
  
  r <- terra::rast(nrows = 10, ncols = 10, vals = 0)
  terra::writeRaster(r, f, overwrite = TRUE)
  
  result <- spk_rast_not_empty(f)
  
  expect_type(result, "logical")
  expect_false(result)
})

test_that("spk_rast_not_empty returns FALSE for empty raster (all NA)", {
  skip_if_not_installed("terra")
  
  # Create temporary raster with all NAs
  f <- tempfile(fileext = ".tif")
  on.exit(unlink(f), add = TRUE)
  
  r <- terra::rast(nrows = 10, ncols = 10, vals = NA)
  terra::writeRaster(r, f, overwrite = TRUE)
  
  result <- spk_rast_not_empty(f)
  
  expect_type(result, "logical")
  expect_false(result)
})

test_that("spk_rast_not_empty errors on non-existent file", {
  skip_if_not_installed("terra")
  
  expect_error(
    spk_rast_not_empty("nonexistent.tif"),
    "must specify an existing file"
  )
})

test_that("spk_rast_not_empty handles raster with sparse non-zero data", {
  skip_if_not_installed("terra")
  
  # Create raster with mostly zeros but one non-zero value
  f <- tempfile(fileext = ".tif")
  on.exit(unlink(f), add = TRUE)
  
  vals <- rep(0, 100)
  vals[50] <- 1  # One non-zero value
  r <- terra::rast(nrows = 10, ncols = 10, vals = vals)
  terra::writeRaster(r, f, overwrite = TRUE)
  
  result <- spk_rast_not_empty(f)
  
  expect_true(result)
})
