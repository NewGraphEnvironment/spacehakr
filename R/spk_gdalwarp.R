#' Generate GDALWarp Command Arguments
#'
#' Constructs the command-line arguments for GDAL's `gdalwarp` utility, allowing for flexible reprojection and
#' resampling of raster data. The function can return either a vector of arguments for programmatic use or a complete
#' command string for manual execution when `interactive = TRUE`.
#'
#' @param path_in [character] A vector of file paths to input rasters. Must be valid file paths.
#' @param path_out [character] A single file path for the output raster. The directory must exist.
#' @param s_srs [character] or [NULL] Optional. The source spatial reference system in any GDAL-supported format
#'   (e.g., EPSG codes, PROJ strings). Defaults to `NULL`, meaning it will be inferred from the input raster.
#' @param t_srs [character] The target spatial reference system in any GDAL-supported format. Defaults to `"EPSG:3005"`.
#' @param resampling [character] The resampling method. One of `"nearest"`, `"bilinear"`, `"cubic"`, `"cubicspline"`,
#'   `"lanczos"`, `"average"`, `"mode"`. Defaults to `"bilinear"`.
#' @param target_resolution [numeric] A numeric vector of length 2 specifying the output pixel resolution in meters for
#'   the x and y directions. Defaults to `c(0.15, 0.15)` (15cm x 15cm pixels).
#' @param overwrite [logical] Whether to overwrite the output file if it exists. Defaults to `TRUE`.
#' @param interactive [logical] Whether to return the full `gdalwarp` command as a string for manual use. Defaults to `FALSE`.
#' @param params_default [character] or [NULL] Optional. A character vector of default parameters to include in the
#'   `gdalwarp` command. Defaults to `c("-multi", "-wo", "NUM_THREADS=ALL_CPUS")`.
#' @param params_add [character] or [NULL] Optional. A character vector of additional parameters to include in the
#'   `gdalwarp` command.
#'
#' @return [character] A vector of arguments for programmatic use or a complete command string if `interactive = TRUE`.
#'
#'
#' @examples
#' \dontrun{
#' # Generate arguments for programmatic use
#' args <- spk_gdalwarp(
#'   path_in = c("input1.tif", "input2.tif"),
#'   path_out = "output.tif",
#'   s_srs = "EPSG:4326",
#'   t_srs = "EPSG:3857",
#'   target_resolution = c(0.1, 0.1)
#' )
#'
#' # Generate a full command for manual use
#' cmd <- spk_gdalwarp(
#'   path_in = c("input1.tif", "input2.tif"),
#'   path_out = "output.tif",
#'   s_srs = "EPSG:4326",
#'   t_srs = "EPSG:3857",
#'   target_resolution = c(0.1, 0.1),
#'   interactive = TRUE
#' )
#' cat(cmd, "\n")
#' }
#'
#' @details
#' The function constructs command-line arguments for `gdalwarp`, enabling flexible raster reprojection, resampling, and
#' transformation. Note that `gdalwarp` requires GDAL to be installed on your system. On macOS, you can install GDAL
#' using Homebrew by running `brew install gdal`. For more details on `gdalwarp`, visit: <https://gdal.org/en/stable/programs/gdalwarp.html>.
#'
#' @family command-builder
#'
#' @seealso [gdalwarp documentation](https://gdal.org/en/stable/programs/gdalwarp.html)
#'
#' @importFrom chk chk_file chk_string chk_flag chk_character chk_vector chk_number
#' @importFrom fs path_dir
#' @export
spk_gdalwarp <- function(path_in,
                             path_out,
                             s_srs = NULL,
                             t_srs = "EPSG:3005",
                             resampling = "bilinear",
                             target_resolution = c(0.15, 0.15),  # Default: 15cm x 15cm,
                             overwrite = TRUE,
                             interactive = FALSE,
                             params_default = c("-multi", "-wo", "NUM_THREADS=ALL_CPUS"),
                             params_add = NULL) {
  # Validate input parameters
  lapply(path_in, chk::chk_file)
  if (!is.null(s_srs)) {
    chk::chk_string(s_srs)
  }
  chk::chk_dir(fs::path_dir(path_out))
  chk::chk_string(t_srs)
  chk::chk_string(resampling)
  chk::chk_flag(overwrite)
  chk::chk_flag(interactive)
  chk::chk_vector(target_resolution)
  lapply(target_resolution, chk::chk_number)

  if (length(target_resolution) != 2 || any(target_resolution <= 0)) {
    cli::cli_abort("`target_resolution` must be a numeric vector of length 2 with positive values.")
  }

  if (!is.null(params_default)) {
    chk::chk_character(params_default)
  }

  if (!is.null(params_add)) {
    chk::chk_character(params_add)
  }

  # Construct gdalwarp command arguments
  args <- c(
    if (overwrite) "-overwrite",
    params_default,
    if (!is.null(s_srs)) c("-s_srs", s_srs),
    c("-t_srs", t_srs),
    c("-r", resampling),
    c("-tr", as.character(target_resolution)),
    path_in,
    path_out
  )

  # Add additional parameters if provided
  if (!is.null(params_add)) {
    args <- c(args, params_add)
  }

  # Return the full command as a string if interactive
  if (interactive) {
    return(paste(c("gdalwarp", args), collapse = " "))
  }

  # Return the arguments as a vector
  args
}
