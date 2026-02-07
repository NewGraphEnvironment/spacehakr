test_that("spk_rast_ext returns combined extent from single raster", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  
  f <- system.file("extdata", "test1.tif", package = "spacehakr")
  
  result <- spk_rast_ext(f)
  
  expect_s3_class(result, "bbox")
  expect_true(all(c("xmin", "xmax", "ymin", "ymax") %in% names(result)))
  expect_true(!is.null(sf::st_crs(result)))
})

test_that("spk_rast_ext returns combined extent from multiple rasters", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  
  files_in <- c(
    system.file("extdata", "test1.tif", package = "spacehakr"),
    system.file("extdata", "test2.tif", package = "spacehakr")
  )
  
  result <- spk_rast_ext(files_in)
  
  expect_s3_class(result, "bbox")
  
  # Combined extent should encompass both rasters
  # Get individual extents
  ext1 <- sf::st_bbox(terra::ext(terra::rast(files_in[1])), crs = terra::crs(terra::rast(files_in[1])))
  ext2 <- sf::st_bbox(terra::ext(terra::rast(files_in[2])), crs = terra::crs(terra::rast(files_in[2])))
  
  # Combined extent should have min of mins and max of maxs
  expect_lte(result["xmin"], min(ext1["xmin"], ext2["xmin"]))
  expect_gte(result["xmax"], max(ext1["xmax"], ext2["xmax"]))
})

test_that("spk_rast_ext reprojects bbox when crs_out is specified", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  
  f <- system.file("extdata", "test1.tif", package = "spacehakr")
  
  # Get original CRS
  orig_crs <- terra::crs(terra::rast(f))
  
  # Reproject to different CRS
  result <- spk_rast_ext(f, crs_out = "EPSG:4326")
  
  result_crs <- sf::st_crs(result)
  
  expect_s3_class(result, "bbox")
  expect_equal(result_crs$input, "EPSG:4326")
})

test_that("spk_rast_ext retains original CRS when crs_out is NULL", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  
  f <- system.file("extdata", "test1.tif", package = "spacehakr")
  
  orig_crs <- sf::st_crs(terra::crs(terra::rast(f)))
  
  result <- spk_rast_ext(f, crs_out = NULL)
  result_crs <- sf::st_crs(result)
  
  expect_equal(result_crs, orig_crs)
})

test_that("spk_rast_ext errors when rasters have different CRS", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  
  # Create two temp rasters with different CRS
  f1 <- tempfile(fileext = ".tif")
  f2 <- tempfile(fileext = ".tif")
  on.exit(unlink(c(f1, f2)), add = TRUE)
  
  r1 <- terra::rast(nrows = 10, ncols = 10, vals = 1, crs = "EPSG:4326")
  r2 <- terra::rast(nrows = 10, ncols = 10, vals = 1, crs = "EPSG:32609")
  
  terra::writeRaster(r1, f1, overwrite = TRUE)
  terra::writeRaster(r2, f2, overwrite = TRUE)
  
  expect_error(
    spk_rast_ext(c(f1, f2)),
    "Found multiple CRS values"
  )
})

test_that("spk_rast_ext errors on non-existent file", {
  skip_if_not_installed("terra")
  
  expect_error(
    spk_rast_ext("nonexistent.tif"),
    "must specify an existing file"
  )
})

test_that("spk_rast_ext validates input is character vector", {
  skip_if_not_installed("terra")
  
  f <- system.file("extdata", "test1.tif", package = "spacehakr")
  
  # Should work with character vector
  expect_no_error(spk_rast_ext(f))
  
  # Should also work if passed as vector (coerces via as.vector)
  expect_no_error(spk_rast_ext(c(f)))
})
