#' Extract Resolution from a Raster
#'
#' This function calculates and extracts the resolution (in metres) of a single pixel (centre) from a raster file.
#' It determines the central pixel of the raster, crops to that single pixel, and
#' returns its resolution in the specified CRS. Uses [terra::rast()], [terra::ext()], [terra::crop()], and [terra::project()]
#' to perform these operations.
#'
#' @param path [character] A file path to the input raster.
#' @param crs_out [character] The desired CRS (default is "EPSG:3005").
#'
#' @return [numeric] A vector of length two representing the resolution of the single pixel in metres in the specified CRS.
#' @family raster
#'
#' @details
#' The function first calculates the extent and resolution of the raster, identifies the central pixel,
#' and crops the raster to that pixel. It then projects the cropped raster to the specified CRS and
#' calculates the resolution of the single pixel.
#'
#' @examples
#' path <- system.file("extdata", "test1.tif", package = "spacehakr")
#' crs_out <- "EPSG:32609"
#' spk_res(path, crs_out)
#'
#' @importFrom terra rast ext res crop project
#' @importFrom chk chk_character
#' @export
spk_res <- function(
    path,
    crs_out = "EPSG:3005"
){
  chk::chk_character(path)
  chk::chk_character(crs_out)

  r <- terra::rast(path)

  # Get the raster extent and resolution
  r_ext <- terra::ext(r)
  r_res <- terra::res(r)  # Pixel size in x and y directions

  # Calculate the center row and column
  center_row <- ceiling(nrow(r) / 2)
  center_col <- ceiling(ncol(r) / 2)

  # Calculate the extent of the single pixel (xmin, xmax, ymin, ymax)
  xmin <- r_ext$xmin + (center_col - 1) * r_res[1]
  xmax <- xmin + r_res[1]
  ymax <- r_ext$ymax - (center_row - 1) * r_res[2]
  ymin <- ymax - r_res[2]

  pixel_ext <- terra::ext(xmin, xmax, ymin, ymax)

  # Crop the raster to this single pixel
  pixel_rast <- terra::crop(r, pixel_ext)

  # Get the resolution of the single pixel in meters
  pixel_rast |>
    terra::project(crs_out) |>
    terra::res()
}
