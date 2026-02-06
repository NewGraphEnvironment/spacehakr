#' Generate Regularly Spaced Points Inside Polygons
#'
#' This function generates a regularly spaced grid of points inside each polygon
#' in a given `sf` object and assigns it an ID. The point density is determined by a specified column.
#'
#' @param sf_in An `sf` object containing polygon geometries.
#' @param col_density [character] The name of the column containing point density values per polygon.
#' @param col_id [character] or [NULL] The name of the column to use as the ID. Defaults to "id" if NULL.
#'
#' @return An `sf` object containing the generated points with an ID column.
#'
#' @importFrom sf st_sample st_geometry st_sf st_area
#' @importFrom chk chk_is chk_string chk_subset
#' @family vector
#' @export
#'
#' @examples
#' poly <- sf::st_sf(
#'   region = c("A", "B"),
#'   col_density = c(1, 5),
#'   geometry = sf::st_sfc(
#'     sf::st_polygon(list(rbind(c(0, 0), c(10, 0), c(10, 10), c(0, 10), c(0, 0)))),
#'     sf::st_polygon(list(rbind(c(15, 15), c(20, 15), c(20, 20), c(15, 20), c(15, 15))))
#'   )
#' )
#'
#' points <- spk_poly_to_points(poly, col_density = "col_density", col_id = "region")
#'
#' plot(sf::st_geometry(poly))
#'  plot(sf::st_geometry(points), add = TRUE, col = "red", pch = 16)
#'
spk_poly_to_points <- function(sf_in, col_density, col_id = NULL) {
  # Assign default ID column if NULL
  if (is.null(col_id)) {
    col_id <- "id"
  }
  if (!col_id %in% names(sf_in)) {
    sf_in[[col_id]] <- seq_len(nrow(sf_in))
  }

  # Validate input
  chk::chk_is(sf_in, "sf")
  chk::chk_string(col_density)
  chk::chk_subset(col_density, names(sf_in))

  # capture the original crs
  crs_og <- sf::st_crs(sf_in)

  # Generate points within each polygon using st_sample
  point_list <- mapply(function(poly, density) {
    sf::st_sample(poly, size = as.integer(density * sf::st_area(poly)), type = "regular")
  }, sf::st_geometry(sf_in), sf_in[[col_density]], SIMPLIFY = FALSE)

  # Assign ID to points
  id_list <- rep(sf_in[[col_id]], lengths(point_list))  # Repeat IDs for each point
  points <- do.call(c, point_list)
  sf_points <- sf::st_sf(setNames(data.frame(id_list), col_id), geometry = points)
  sf::st_crs(sf_points) <- crs_og

  return(sf_points)
}
