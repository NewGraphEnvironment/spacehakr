# The BC Data Catalogue is mocked at the bcdata boundary — no test in this package
# touches the network.
#
# mockery::stub() rather than testthat::local_mocked_bindings(): the function calls
# bcdata::bcdc_query_geodata() fully qualified, and rebinding in the bcdata namespace
# does not intercept a `::` call — the first draft of these tests passed the write
# assertions while the record-id spy never fired at all.

fake_layer <- function() {
  sf::st_sf(
    id = 1:2,
    geometry = sf::st_sfc(
      sf::st_point(c(1000000, 1000000)),
      sf::st_point(c(1000100, 1000100)),
      crs = 3005
    )
  )
}

testthat::test_that("spk_source_bcdata validates its arguments", {
  gpkg <- tempfile(fileext = ".gpkg")
  file.create(gpkg)
  on.exit(unlink(gpkg), add = TRUE)

  testthat::expect_error(
    spk_source_bcdata(bcdata_record_id = 1L, path_gpkg = gpkg),
    class = "chk_error"
  )
  testthat::expect_error(
    spk_source_bcdata(bcdata_record_id = NULL, path_gpkg = gpkg),
    class = "chk_error"
  )
  testthat::expect_error(
    spk_source_bcdata(
      bcdata_record_id = "whse_basemapping.bcgs_5k_grid",
      path_gpkg = gpkg,
      layer_name = 1L
    ),
    class = "chk_error"
  )
})

testthat::test_that("spk_source_bcdata rejects a path_gpkg that does not exist", {
  testthat::expect_error(
    spk_source_bcdata(
      bcdata_record_id = "whse_basemapping.bcgs_5k_grid",
      path_gpkg = file.path(tempdir(), "definitely-not-here.gpkg")
    ),
    class = "chk_error"
  )
})

testthat::test_that("spk_source_bcdata upper-cases the record id before querying", {
  testthat::skip_if_not_installed("sf")

  testthat::skip_if_not_installed("mockery")

  seen <- NULL
  f <- spk_source_bcdata
  mockery::stub(f, "bcdata::bcdc_query_geodata", function(record, ...) {
    seen <<- record
    record
  })
  mockery::stub(f, "bcdata::collect", function(x, ...) {
    force(x) # the native pipe nests the query inside collect(); without this it is never evaluated
    fake_layer()
  })

  gpkg <- tempfile(fileext = ".gpkg")
  on.exit(unlink(gpkg), add = TRUE)
  sf::st_write(fake_layer(), gpkg, layer = "seed", quiet = TRUE)

  f(
    bcdata_record_id = "whse_basemapping.bcgs_5k_grid",
    path_gpkg = gpkg,
    layer_name = "grid"
  )

  testthat::expect_equal(seen, "WHSE_BASEMAPPING.BCGS_5K_GRID")
})

testthat::test_that("spk_source_bcdata writes a lower-cased layer name", {
  testthat::skip_if_not_installed("sf")

  testthat::skip_if_not_installed("mockery")

  f <- spk_source_bcdata
  mockery::stub(f, "bcdata::bcdc_query_geodata", function(record, ...) record)
  mockery::stub(f, "bcdata::collect", function(x, ...) {
    force(x) # the native pipe nests the query inside collect(); without this it is never evaluated
    fake_layer()
  })

  gpkg <- tempfile(fileext = ".gpkg")
  on.exit(unlink(gpkg), add = TRUE)
  sf::st_write(fake_layer(), gpkg, layer = "seed", quiet = TRUE)

  f(
    bcdata_record_id = "whse_basemapping.bcgs_5k_grid",
    path_gpkg = gpkg,
    layer_name = "Grid_5K"
  )

  testthat::expect_true("grid_5k" %in% sf::st_layers(gpkg)$name)
})

testthat::test_that("spk_source_bcdata falls back to the record id as layer name", {
  testthat::skip_if_not_installed("sf")

  testthat::skip_if_not_installed("mockery")

  f <- spk_source_bcdata
  mockery::stub(f, "bcdata::bcdc_query_geodata", function(record, ...) record)
  mockery::stub(f, "bcdata::collect", function(x, ...) {
    force(x) # the native pipe nests the query inside collect(); without this it is never evaluated
    fake_layer()
  })

  gpkg <- tempfile(fileext = ".gpkg")
  on.exit(unlink(gpkg), add = TRUE)
  sf::st_write(fake_layer(), gpkg, layer = "seed", quiet = TRUE)

  f(
    bcdata_record_id = "whse_basemapping.bcgs_5k_grid",
    path_gpkg = gpkg
  )

  testthat::expect_true("whse_basemapping.bcgs_5k_grid" %in% sf::st_layers(gpkg)$name)
})
