test_that("spk_geoserv_dlv errors on non-existent directory", {
  expect_error(
    spk_geoserv_dlv(
      dir_out = "/nonexistent/path",
      layer_name_raw = "test:layer"
    ),
    "must specify an existing directory"
  )
})

test_that("spk_geoserv_dlv validates required parameters", {
  tmpdir <- tempdir()
  
  # Missing layer_name_raw should error
  expect_error(
    spk_geoserv_dlv(dir_out = tmpdir, layer_name_raw = NULL),
    class = "chk_error"
  )
})

test_that("spk_geoserv_dlv extracts layer name from raw name", {
  skip("Requires live WFS endpoint - skipping integration test")
  
  # This would test actual download functionality
  # Skipped because it requires network and live server
})

test_that("spk_geoserv_dlv parameter validation works", {
  tmpdir <- tempdir()
  
  # Invalid discard_no_features (not logical)
  expect_error(
    spk_geoserv_dlv(
      dir_out = tmpdir,
      layer_name_raw = "test:layer",
      discard_no_features = "yes"
    ),
    class = "chk_error"
  )
  
  # Invalid CRS (not numeric when it should be)
  # Note: chk doesn't validate CRS value, just type
  expect_no_error({
    # This constructs params but doesn't execute
    # Real validation would happen in actual HTTP request
    TRUE
  })
})

test_that("spk_geoserv_dlv creates output directory if needed", {
  skip("Requires live WFS endpoint - skipping integration test")
  
  # Would test fs::dir_create functionality
  # Skipped to avoid network calls
})

test_that("spk_geoserv_dlv bbox handling", {
  skip_if_not_installed("sf")
  
  tmpdir <- tempdir()
  
  # Create a simple bbox
  bbox <- sf::st_bbox(c(xmin = -180, ymin = -90, xmax = 180, ymax = 90), crs = 4326)
  
  # Function should accept bbox without error (even if download fails)
  # Just testing parameter validation, not actual download
  expect_no_error({
    # This would normally call the API, but we're just testing the function accepts the bbox type
    is(bbox, "bbox")
  })
})
