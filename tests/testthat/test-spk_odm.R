test_that("spk_odm constructs correct arguments for processx::run", {
  # Create temp directory for testing
  tmpdir <- tempdir()
  project_dir <- file.path(tmpdir, "test_project")
  dir.create(project_dir, showWarnings = FALSE)
  on.exit(unlink(project_dir, recursive = TRUE), add = TRUE)
  
  args <- spk_odm(
    path_project = project_dir,
    interactive = FALSE
  )
  
  expect_type(args, "character")
  expect_true("run" %in% args)
  expect_true("--rm" %in% args)
  expect_true("-v" %in% args)
  expect_true("opendronemap/odm" %in% args)
  expect_true("--project-path" %in% args)
  expect_true("--dtm" %in% args)
  expect_true("--dsm" %in% args)
})

test_that("spk_odm includes default parameters", {
  tmpdir <- tempdir()
  project_dir <- file.path(tmpdir, "test_project2")
  dir.create(project_dir, showWarnings = FALSE)
  on.exit(unlink(project_dir, recursive = TRUE), add = TRUE)
  
  args <- spk_odm(path_project = project_dir)
  
  # Check default params are included
  expect_true("--dtm" %in% args)
  expect_true("--dsm" %in% args)
  expect_true("--pc-quality" %in% args)
  expect_true("low" %in% args)
  expect_true("--dem-resolution" %in% args)
  expect_true("10" %in% args)
})

test_that("spk_odm can disable default parameters", {
  tmpdir <- tempdir()
  project_dir <- file.path(tmpdir, "test_project3")
  dir.create(project_dir, showWarnings = FALSE)
  on.exit(unlink(project_dir, recursive = TRUE), add = TRUE)
  
  args <- spk_odm(
    path_project = project_dir,
    params_default = NULL
  )
  
  # Default params should not be present
  expect_false("--dtm" %in% args)
  expect_false("--dsm" %in% args)
})

test_that("spk_odm includes additional parameters", {
  tmpdir <- tempdir()
  project_dir <- file.path(tmpdir, "test_project4")
  dir.create(project_dir, showWarnings = FALSE)
  on.exit(unlink(project_dir, recursive = TRUE), add = TRUE)
  
  args <- spk_odm(
    path_project = project_dir,
    params_add = c("--fast-orthophoto", "--skip-report")
  )
  
  expect_true("--fast-orthophoto" %in% args)
  expect_true("--skip-report" %in% args)
})

test_that("spk_odm returns single string when interactive=TRUE", {
  tmpdir <- tempdir()
  project_dir <- file.path(tmpdir, "test_project5")
  dir.create(project_dir, showWarnings = FALSE)
  on.exit(unlink(project_dir, recursive = TRUE), add = TRUE)
  
  cmd <- spk_odm(
    path_project = project_dir,
    interactive = TRUE
  )
  
  expect_type(cmd, "character")
  expect_length(cmd, 1)  # Single string
  expect_true(grepl("^docker run -ti", cmd))
})

test_that("spk_odm constructs correct volume mapping", {
  tmpdir <- tempdir()
  project_dir <- file.path(tmpdir, "test_project6")
  dir.create(project_dir, showWarnings = FALSE)
  on.exit(unlink(project_dir, recursive = TRUE), add = TRUE)
  
  args <- spk_odm(path_project = project_dir)
  
  # Find -v flag and check next arg is volume mapping
  v_index <- which(args == "-v")
  expect_true(length(v_index) > 0)
  
  volume_mapping <- args[v_index + 1]
  expect_true(grepl(":/datasets$", volume_mapping))
})

test_that("spk_odm errors on non-existent directory", {
  expect_error(
    spk_odm("/nonexistent/path"),
    "must specify an existing directory"
  )
})

test_that("spk_odm errors on invalid params_default type", {
  tmpdir <- tempdir()
  project_dir <- file.path(tmpdir, "test_project7")
  dir.create(project_dir, showWarnings = FALSE)
  on.exit(unlink(project_dir, recursive = TRUE), add = TRUE)
  
  expect_error(
    spk_odm(path_project = project_dir, params_default = 123),
    class = "chk_error"
  )
})
