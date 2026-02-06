#' Remove Empty Raster Files
#'
#' Scans a directory for raster files (e.g., .tif, .tiff, .vrt) and removes those that contain only zero values.
#' Uses [spk_rast_not_empty()] to check each raster.
#'
#' @param path [character] A single path to search for raster files.
#' @param delete [logical] Whether to delete the empty files. Default is `TRUE`.
#' @param regexp [character] A regular expression passed to [fs::dir_ls()] to select raster files. Default is '\.(tif|tiff|vrt)$'.
#' @param quiet [logical] If `FALSE`, prints messages about files that are or can be removed. Default is `FALSE`.
#'
#' @return [character] A character vector of paths to the raster files that were empty. Returns invisibly.
#'
#' @seealso [spk_rast_not_empty()], [fs::dir_ls()], [fs::file_delete()], [terra::rast()], [terra::values()]
#'
#' @importFrom chk chk_string chk_flag chk_dir chk_not_null
#' @importFrom fs dir_ls file_delete
#' @importFrom purrr keep
#' @importFrom cli cli_alert_info cli_alert_success
#'
#' @export
#' @family raster
spk_rast_rm_empty <- function(path = NULL, delete = TRUE, regexp = "\\.(tif|tiff|vrt)$", quiet = FALSE) {
  chk::chk_not_null(path)
  chk::chk_string(path)
  chk::chk_dir(path)
  chk::chk_flag(delete)
  chk::chk_flag(quiet)

  rast_files <- fs::dir_ls(path, regexp = regexp)
  rast_files_with_data <- purrr::keep(rast_files, spk_rast_not_empty)
  rast_files_empty <- setdiff(rast_files, rast_files_with_data)

  if (!quiet && length(rast_files_empty) > 0) {
    if (delete) {
      cli::cli_alert_info("Removing empty rasters:")
      cli::cli_alert_success(rast_files_empty)
    } else {
      cli::cli_alert_info("Empty rasters found (not deleted):")
      cli::cli_alert_info(rast_files_empty)
    }
  }

  if (delete && length(rast_files_empty) > 0) {
    fs::file_delete(rast_files_empty)
  }

  invisible(rast_files_empty)
}
