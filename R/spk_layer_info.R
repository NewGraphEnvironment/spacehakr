#' Summarise Layers and Geometry Types in a Spatial Data Source
#'
#' Extracts and summarises information about layers within a spatial vector data source.
#' Attempts to determine the geometry type of each layer by querying a sample feature.
#'
#' @param path [character] A single string. Path to the vector spatial data source (e.g., a GeoPackage or shapefile).
#'
#' @return [data.frame] A data frame of available layers and their geometry types.
#' If a layer contains no geometry, or an error occurs during reading, the `geomtype` will be `NA`.
#'
#' @details
#' Uses [sf::st_layers()] to list available layers in the data source.
#' For each layer, attempts to read a single feature using an SQL query and determines the geometry type using [sf::st_geometry_type()].
#' Layers with no geometry or errors in reading are safely assigned `NA`.
#' The `driver` column is removed from the output as it may contain invalid entries for further data frame operations.
#'
#' @seealso [sf::st_layers()], [sf::st_read()], [sf::st_geometry_type()]
#'
#' @family vector
#'
#' @importFrom sf st_layers st_read st_geometry_type
#' @importFrom dplyr mutate select
#' @importFrom purrr map_chr
#' @importFrom glue glue
#'
#' @export
spk_layer_info <- function(path) {
  sf::st_layers(path) |>
    as.data.frame() |>
    dplyr::mutate(
      geomtype = purrr::map_chr(
        name,
        ~ tryCatch(
          {
            geom <- sf::st_read(
              path,
              query = glue::glue("SELECT * FROM \"{.x}\" LIMIT 1"),
              quiet = TRUE
            ) |>
              sf::st_geometry_type()
            if (length(geom) == 0) NA_character_ else as.character(geom)
          },
          error = function(e) NA_character_
        )
      )
    ) |>
    dplyr::select(-driver)
}




