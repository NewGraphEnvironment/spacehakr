#' Check if Raster Has Non-Zero Data
#'
#' Determines whether a raster file contains any non-zero values.
#'
#' @param f [character] A single file path to a raster file.
#'
#' @return [logical] `TRUE` if the raster has any non-zero values, otherwise `FALSE`.
#'
#' @examples
#' \dontrun{
#' # Check if a raster has non-zero data
#' has_data <- spk_rast_not_empty("path/to/raster.tif")
#' }
#'
#' @importFrom terra rast values
#' @importFrom chk chk_file
#' @export
#' @family raster
spk_rast_not_empty <- function(f) {
  chk::chk_file(f)
  r <- terra::rast(f)
  vals <- terra::values(r, mat = FALSE)
  if (length(vals) == 0) return(FALSE)
  any(vals != 0, na.rm = TRUE)
}
