test_that("spk_layer_info returns layer information from GeoPackage", {
  skip_if_not_installed("sf")
  
  # Use existing test data
  path <- system.file("extdata/poly.gpkg", package = "spacehakr")
  
  result <- spk_layer_info(path)
  
  expect_s3_class(result, "data.frame")
  expect_true("name" %in% names(result))
  expect_true("geomtype" %in% names(result))
  expect_true(nrow(result) > 0)
})

test_that("spk_layer_info identifies geometry type correctly", {
  skip_if_not_installed("sf")
  
  path <- system.file("extdata/poly.gpkg", package = "spacehakr")
  
  result <- spk_layer_info(path)
  
  # poly.gpkg should contain polygon geometry
  expect_true(any(grepl("POLYGON", result$geomtype, ignore.case = TRUE)))
})

test_that("spk_layer_info handles GeoPackage with multiple layers", {
  skip_if_not_installed("sf")
  
  # Create temp GeoPackage with multiple layers
  tmpfile <- tempfile(fileext = ".gpkg")
  on.exit(unlink(tmpfile), add = TRUE)
  
  # Create two simple sf objects
  pts <- sf::st_sf(
    id = 1:3,
    geometry = sf::st_sfc(
      sf::st_point(c(0, 0)),
      sf::st_point(c(1, 1)),
      sf::st_point(c(2, 2)),
      crs = 4326
    )
  )
  
  poly <- sf::st_sf(
    id = 1,
    geometry = sf::st_sfc(
      sf::st_polygon(list(matrix(c(0, 0, 1, 0, 1, 1, 0, 1, 0, 0), ncol = 2, byrow = TRUE))),
      crs = 4326
    )
  )
  
  sf::st_write(pts, tmpfile, layer = "points", quiet = TRUE)
  sf::st_write(poly, tmpfile, layer = "polygons", quiet = TRUE, append = TRUE)
  
  result <- spk_layer_info(tmpfile)
  
  expect_equal(nrow(result), 2)
  expect_true("points" %in% result$name)
  expect_true("polygons" %in% result$name)
})

test_that("spk_layer_info returns NA for layers with no geometry", {
  skip_if_not_installed("sf")
  
  # Create temp GeoPackage with empty layer
  tmpfile <- tempfile(fileext = ".gpkg")
  on.exit(unlink(tmpfile), add = TRUE)
  
  # Create an empty sf object
  empty_sf <- sf::st_sf(
    id = integer(0),
    geometry = sf::st_sfc(crs = 4326)
  )
  
  sf::st_write(empty_sf, tmpfile, layer = "empty", quiet = TRUE)
  
  result <- spk_layer_info(tmpfile)
  
  expect_true(is.na(result$geomtype[result$name == "empty"]))
})

test_that("spk_layer_info errors on non-existent file", {
  skip_if_not_installed("sf")
  
  expect_error(
    spk_layer_info("nonexistent.gpkg"),
    # sf::st_layers will error on missing file
    class = "error"
  )
})

test_that("spk_layer_info does not include driver column", {
  skip_if_not_installed("sf")
  
  path <- system.file("extdata/poly.gpkg", package = "spacehakr")
  
  result <- spk_layer_info(path)
  
  # Driver column should be removed per function docs
  expect_false("driver" %in% names(result))
})
