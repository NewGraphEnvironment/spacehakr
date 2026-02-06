files_in <- c(
    system.file("extdata", "test1.tif", package = "spacehakr"),
    system.file("extdata", "test2.tif", package = "spacehakr")
  )

# burn to temp file
file_out <- fs::path(tempdir(), "test_out.tif")
res <- c(20, 20)

args <- spk_gdalwarp(
  path_in = files_in,
  path_out = file_out,
  t_srs = "EPSG:32609",
  target_resolution = res
)

expected_args <- c(
  "-overwrite",
  "-multi", "-wo", "NUM_THREADS=ALL_CPUS",
  "-t_srs", "EPSG:32609",
  "-r", "bilinear",
  "-tr",
  res,
  files_in,
  file_out
)

testthat::test_that("spk_gdalwarp constructs correct arguments", {
  testthat::expect_equal(args, expected_args)
})


# run the cmd
processx::run(
  command = "gdalwarp",
  args = args,
  echo = TRUE,
  spinner = TRUE
)

# test that the output file exists
test_that("output file exists", {
  expect_true(fs::file_exists(file_out))
})

# clean up
fs::file_delete(file_out)
