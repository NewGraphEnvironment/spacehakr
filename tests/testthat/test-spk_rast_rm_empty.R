test_that("spk_rast_rm_empty detects empty raster", {
  skip_if_not_installed("terra")

  f <- tempfile(fileext = ".tif")
  r <- terra::rast(nrows = 10, ncols = 10, vals = 0)
  terra::writeRaster(r, f, overwrite = TRUE)

  tmpdir <- tempfile()
  fs::dir_create(tmpdir)
  fs::file_move(f, tmpdir)

  result <- spk_rast_rm_empty(path = tmpdir, delete = FALSE)
  expect_true(length(result) == 1)
  expect_true(grepl("\\.tif$", result))
})
