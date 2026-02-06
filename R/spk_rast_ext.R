#' Compute Combined Extent (Bounding Box) from Multiple Raster Files
#'
#' Computes the combined spatial extent (bounding box) from one or more raster files.
#' It ensures that all input rasters share the same CRS and optionally reprojects the bounding box
#' to a specified CRS. The function relies on [terra::ext()], [terra::crs()], and [sf::st_bbox()] for extent extraction and CRS handling.
#'
#' @param x [character] A vector of file paths, URLs, or database connection strings to raster data sources.
#' Each path must exist and be accessible to GDAL.
#' @param crs_out [character] or [NULL] Optional. A CRS string (e.g., "EPSG:4326") to reproject the combined bounding box.
#' If `NULL`, the CRS of the input rasters is retained. Default is `NULL`.
#'
#' @return A bounding box object with:
#'   - `xmin`: Minimum x-coordinate.
#'   - `xmax`: Maximum x-coordinate.
#'   - `ymin`: Minimum y-coordinate.
#'   - `ymax`: Maximum y-coordinate.
#' If `crs_out` is specified, the bounding box is reprojected to the target CRS.
#'
#' @details
#' This function ensures all input rasters share the same CRS before computing the union of their extents.
#' The resulting bounding box can be reprojected to a target CRS if `crs_out` is provided.
#' It uses [terra::ext()] to extract extents, [terra::crs()] to check CRS consistency, and [sf::st_bbox()]
#' for constructing and reprojecting the bounding box.
#'
#' @family raster
#'
#' @importFrom terra rast crs ext union
#' @importFrom chk chk_vector chk_character chk_file
#' @importFrom cli cli_abort
#' @importFrom sf st_bbox st_transform
#'
#' @examples
#'
#' \dontrun{
#' # Define input files
#' files_in <- c(
#'   "/path/to/file1.tif",
#'   "/path/to/file2.tif",
#'   "/path/to/file3.tif"
#' )
#'
#' # Get the combined extent without reprojection
#' bbox_combined <- spk_rast_ext(files_in)
#'
#' # Get the combined extent and reproject to EPSG:4326
#' bbox_reprojected <- spk_rast_ext(files_in, crs_out = "EPSG:4326")
#' }
#' @export
spk_rast_ext <- function(x, crs_out = NULL) {
  # Ensure x is a vector
  if (!is.vector(x)) x <- as.vector(x)
  chk::chk_character(x)

  # Check if files exist
  lapply(x, chk::chk_file)

  # Open rasters and check CRS consistency
  rasters <- lapply(x, terra::rast)
  crs_list <- sapply(rasters, terra::crs)
  if (length(unique(crs_list)) > 1) {
    cli::cli_abort("Found multiple CRS values among input rasters. Ensure all rasters share the same CRS.")
  }

  # Compute combined extent
  ext_combined <- Reduce(
    terra::union,
    lapply(rasters, terra::ext)
  )

  # Create bounding box
  bbox <- sf::st_bbox(ext_combined, crs = crs_list[1])

  # Reproject bounding box if crs_out is specified
  if (!is.null(crs_out)) {
    bbox <- sf::st_transform(sf::st_as_sfc(bbox), crs_out)
    bbox <- sf::st_bbox(bbox)
  }

  bbox
}
