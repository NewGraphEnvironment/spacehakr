# The ogr2ogr invocation is verified by building the argument vector and comparing it,
# not by running GDAL. `.spk_source_url_args()` exists for exactly this reason.
#
# There is deliberately no live end-to-end test here. The function reads sources through
# GDAL's /vsicurl/ virtual filesystem, so exercising it for real requires a network
# fetch, and no test in this package touches the network. The argument vector is the
# contract; whether GDAL honours it is GDAL's business.

testthat::test_that("spk_source_url validates its arguments", {
  gpkg <- tempfile(fileext = ".gpkg")
  file.create(gpkg)
  on.exit(unlink(gpkg), add = TRUE)

  testthat::expect_error(
    spk_source_url(path_gpkg = 1L, urls = "https://example.com/a.csv"),
    class = "chk_error"
  )
  testthat::expect_error(
    spk_source_url(path_gpkg = gpkg, urls = 1L),
    class = "chk_error"
  )
  testthat::expect_error(
    spk_source_url(path_gpkg = gpkg, urls = "https://example.com/a.csv", query = 1L),
    class = "chk_error"
  )
})

testthat::test_that("spk_source_url rejects a path_gpkg that does not exist", {
  testthat::expect_error(
    spk_source_url(
      path_gpkg = file.path(tempdir(), "definitely-not-here.gpkg"),
      urls = "https://example.com/a.csv"
    ),
    class = "chk_error"
  )
})

testthat::test_that(".spk_source_url_args builds the ogr2ogr arguments", {
  args <- .spk_source_url_args(
    path_gpkg = "layers.gpkg",
    url = "https://example.com/data/parameters_habitat_thresholds.csv"
  )

  testthat::expect_equal(
    args,
    c(
      "-f", "GPKG",
      "layers.gpkg",
      "-update",
      "-overwrite",
      "-nln", "parameters_habitat_thresholds",
      "/vsicurl/https://example.com/data/parameters_habitat_thresholds.csv"
    )
  )
})

testthat::test_that(".spk_source_url_args derives the layer name from the URL basename", {
  args <- .spk_source_url_args("layers.gpkg", "https://example.com/a/b/crossings_vw.fgb")
  testthat::expect_equal(args[which(args == "-nln") + 1L], "crossings_vw")
})

testthat::test_that(".spk_source_url_args adds -where only when a query is supplied", {
  without <- .spk_source_url_args("layers.gpkg", "https://example.com/a.fgb")
  testthat::expect_false("-where" %in% without)

  with_query <- .spk_source_url_args(
    "layers.gpkg",
    "https://example.com/a.fgb",
    query = "watershed_group_code in ('ADMS')"
  )
  testthat::expect_true("-where" %in% with_query)
  testthat::expect_equal(
    with_query[which(with_query == "-where") + 1L],
    shQuote("watershed_group_code in ('ADMS')")
  )
  # the source must stay last, after any filter
  testthat::expect_equal(
    with_query[length(with_query)],
    "/vsicurl/https://example.com/a.fgb"
  )
})
