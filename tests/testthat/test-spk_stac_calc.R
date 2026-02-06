# Test input validation --------------------------------------------------------

testthat::test_that("spk_stac_calc errors when feature is not a list with assets", {

  testthat::expect_error(
    spk_stac_calc(feature = "not_a_list"),
    "must be a single STAC item"
  )

  testthat::expect_error(
    spk_stac_calc(feature = list(no_assets = TRUE)),
    "must be a single STAC item"
  )

  testthat::expect_error(
    spk_stac_calc(feature = list(assets = "not_a_list")),
    "must be a single STAC item"
  )
})

testthat::test_that("spk_stac_calc errors when aoi is not sf or NULL", {
  mock_feature <- list(
    id = "test_item",
    assets = list(
      red = list(href = "https://example.com/red.tif"),
      nir08 = list(href = "https://example.com/nir.tif")
    )
  )

  testthat::expect_error(
    spk_stac_calc(feature = mock_feature, aoi = "not_sf"),
    "must be an sf object"
  )

  testthat::expect_error(
    spk_stac_calc(feature = mock_feature, aoi = data.frame(x = 1)),
    "must be an sf object"
  )
})

testthat::test_that("spk_stac_calc errors when required assets are missing", {
  mock_feature <- list(
    id = "test_item",
    assets = list(
      blue = list(href = "https://example.com/blue.tif")
    )
  )

  testthat::expect_error(
    spk_stac_calc(feature = mock_feature, quiet = TRUE),
    "Missing asset href.*asset_a.*red"
  )

  mock_feature2 <- list(
    id = "test_item",
    assets = list(
      red = list(href = "https://example.com/red.tif")
    )
  )

  testthat::expect_error(
    spk_stac_calc(feature = mock_feature2, quiet = TRUE),
    "Missing asset href.*asset_b.*nir08"
  )
})

testthat::test_that("spk_stac_calc errors when asset href is empty", {
  mock_feature <- list(
    id = "test_item",
    assets = list(
      red = list(href = ""),
      nir08 = list(href = "https://example.com/nir.tif")
    )
  )

  testthat::expect_error(
    spk_stac_calc(feature = mock_feature, quiet = TRUE),
    "Missing asset href.*asset_a.*red"
  )
})

testthat::test_that("spk_stac_calc errors when aoi provided but proj:epsg missing", {
  mock_feature <- list(
    id = "test_item",
    properties = list(),
    assets = list(
      red = list(href = "https://example.com/red.tif"),
      nir08 = list(href = "https://example.com/nir.tif")
    )
  )

  aoi <- sf::st_as_sfc(sf::st_bbox(c(xmin = 0, ymin = 0, xmax = 1, ymax = 1), crs = 4326)) |>
    sf::st_as_sf()

  testthat::expect_error(
    spk_stac_calc(feature = mock_feature, aoi = aoi, quiet = TRUE),
    "Missing.*proj:epsg"
  )
})

# Test parameter validation ----------------------------------------------------

testthat::test_that("spk_stac_calc validates string parameters", {
  mock_feature <- list(
    id = "test_item",
    assets = list(
      red = list(href = "https://example.com/red.tif"),
      nir08 = list(href = "https://example.com/nir.tif")
    )
  )

  testthat::expect_error(spk_stac_calc(feature = mock_feature, asset_a = 123))
  testthat::expect_error(spk_stac_calc(feature = mock_feature, asset_b = 123))
  testthat::expect_error(spk_stac_calc(feature = mock_feature, calc = 123))
  testthat::expect_error(spk_stac_calc(feature = mock_feature, vsi_prefix = 123))
})

testthat::test_that("spk_stac_calc validates flag parameters", {
  mock_feature <- list(
    id = "test_item",
    assets = list(
      red = list(href = "https://example.com/red.tif"),
      nir08 = list(href = "https://example.com/nir.tif")
    )
  )

  testthat::expect_error(spk_stac_calc(feature = mock_feature, quiet = "yes"))
  testthat::expect_error(spk_stac_calc(feature = mock_feature, timing = "yes"))
})

# Test internal .spk_calc helper -------------------------------------------

testthat::test_that(".spk_calc computes NDVI correctly", {
  testthat::skip_if_not_installed("terra")

  # Create synthetic rasters with known values
  a <- terra::rast(nrows = 2, ncols = 2, vals = c(100, 200, 150, 50))
  b <- terra::rast(nrows = 2, ncols = 2, vals = c(300, 400, 150, 250))

  # Calculate expected NDVI: (nir - red) / (nir + red)
  red_vals <- c(100, 200, 150, 50)
  nir_vals <- c(300, 400, 150, 250)
  expected <- (nir_vals - red_vals) / (nir_vals + red_vals)

  result <- spacehakr:::.spk_calc("ndvi", a = a, b = b)
  result_vals <- as.vector(terra::values(result))

  testthat::expect_equal(result_vals, expected, tolerance = 1e-10)
})

testthat::test_that(".spk_calc returns values in expected NDVI range", {
  testthat::skip_if_not_installed("terra")

  # NDVI should be between -1 and 1 for valid reflectance values
  set.seed(42)
  a <- terra::rast(matrix(stats::runif(100, 0, 1000), nrow = 10))
  b <- terra::rast(matrix(stats::runif(100, 0, 1000), nrow = 10))

  result <- spacehakr:::.spk_calc("ndvi", a = a, b = b)
  result_vals <- terra::values(result)

  testthat::expect_true(all(result_vals >= -1 & result_vals <= 1, na.rm = TRUE))
})

testthat::test_that(".spk_calc errors on unknown calc type", {
  testthat::skip_if_not_installed("terra")

  a <- terra::rast(matrix(1:4, nrow = 2))
  b <- terra::rast(matrix(5:8, nrow = 2))

  testthat::expect_error(
    spacehakr:::.spk_calc("unknown_index", a = a, b = b),
    "Unknown calc"
  )
})

testthat::test_that(".spk_calc stacks RGB correctly", {
  testthat::skip_if_not_installed("terra")

  # Create synthetic rasters for R, G, B bands

  r <- terra::rast(nrows = 2, ncols = 2, vals = c(100, 200, 150, 50))
  g <- terra::rast(nrows = 2, ncols = 2, vals = c(110, 210, 160, 60))
  b <- terra::rast(nrows = 2, ncols = 2, vals = c(120, 220, 170, 70))

  result <- spacehakr:::.spk_calc("rgb", a = r, b = g, c = b)

  # Should have 3 layers

testthat::expect_equal(terra::nlyr(result), 3)

  # Check values are preserved
  testthat::expect_equal(as.vector(terra::values(result[[1]])), c(100, 200, 150, 50))
  testthat::expect_equal(as.vector(terra::values(result[[2]])), c(110, 210, 160, 60))
  testthat::expect_equal(as.vector(terra::values(result[[3]])), c(120, 220, 170, 70))
})

# Test calc = NULL (single asset retrieval) ------------------------------------

testthat::test_that("spk_stac_calc allows asset_b = NULL when calc = NULL", {
  mock_feature <- list(
    id = "test_item",
    assets = list(
      visual = list(href = "https://example.com/visual.tif")
    )
  )

  # Should not error on validation - will only fail when trying to read the URL
  testthat::expect_error(
    spk_stac_calc(
      feature = mock_feature,
      asset_a = "visual",
      asset_b = NULL,
      calc = NULL,
      quiet = TRUE
    ),
    "cannot open|HTTP|curl"
  )
})

testthat::test_that("spk_stac_calc errors when asset_b is NULL but calc is specified", {
  mock_feature <- list(
    id = "test_item",
    assets = list(
      red = list(href = "https://example.com/red.tif")
    )
  )

  testthat::expect_error(
    spk_stac_calc(
      feature = mock_feature,
      asset_b = NULL,
      calc = "ndvi",
      quiet = TRUE
    ),
    "asset_b.*required when.*calc.*is not NULL"
  )
})

# Test calc = "rgb" validation -------------------------------------------------

testthat::test_that("spk_stac_calc errors when calc = 'rgb' but asset_c is NULL", {
  mock_feature <- list(
    id = "test_item",
    assets = list(
      B04 = list(href = "https://example.com/B04.tif"),
      B03 = list(href = "https://example.com/B03.tif")
    )
  )

  testthat::expect_error(
    spk_stac_calc(
      feature = mock_feature,
      asset_a = "B04",
      asset_b = "B03",
      asset_c = NULL,
      calc = "rgb",
      quiet = TRUE
    ),
    "asset_c.*required when.*calc.*rgb"
  )
})

testthat::test_that("spk_stac_calc errors when calc = 'rgb' and asset_c href is missing", {
  mock_feature <- list(
    id = "test_item",
    assets = list(
      B04 = list(href = "https://example.com/B04.tif"),
      B03 = list(href = "https://example.com/B03.tif"),
      B02 = list(href = "")
    )
  )

  testthat::expect_error(
    spk_stac_calc(
      feature = mock_feature,
      asset_a = "B04",
      asset_b = "B03",
      asset_c = "B02",
      calc = "rgb",
      quiet = TRUE
    ),
    "Missing asset href.*asset_c.*B02"
  )
})

# Test null coalescing helper --------------------------------------------------

testthat::test_that("%||% returns first value when not NULL", {
  testthat::expect_equal(spacehakr:::`%||%`("value", "default"), "value")
  testthat::expect_equal(spacehakr:::`%||%`(0, "default"), 0)
  testthat::expect_equal(spacehakr:::`%||%`(FALSE, TRUE), FALSE)
})

testthat::test_that("%||% returns second value when first is NULL", {
  testthat::expect_equal(spacehakr:::`%||%`(NULL, "default"), "default")
  testthat::expect_equal(spacehakr:::`%||%`(NULL, 42), 42)
})
