#' Download a BC Data Catalogue Layer to a GeoPackage
#'
#' Downloads a layer from the BC Data Catalogue, optionally intersects it with a
#' mask, and writes it to a GeoPackage.
#'
#' Passing a `mask` can massively increase download speed, because the bounding box
#' of the mask is pushed down into the catalogue API query rather than the full
#' layer being collected and clipped locally.
#'
#' @param bcdata_record_id [character] A BC Data Catalogue record permanent id
#'   (e.g. `7ecfafa6-5e18-48cd-8d9b-eae5b5ea2881`), record name (e.g.
#'   `pscis-assessments`) or object name (e.g. `WHSE_FISH.PSCIS_ASSESSMENT_SVW`).
#'   Record names can be found at <https://catalogue.data.gov.bc.ca/>. Case is not
#'   significant — the value is upper-cased within the function.
#' @param path_gpkg [character] Path to the output GeoPackage file. Must already exist.
#' @param mask [sf] Optional masking polygon used to clip the spatial extent.
#' @param layer_name [character] Optional layer name to write to the GeoPackage. If
#'   `NULL`, defaults to `bcdata_record_id` lower-cased. Designed to work best when an
#'   object name is passed as `bcdata_record_id`.
#'
#' @return The value of [sf::st_write()], invisibly. Called for its side effects.
#'
#' @seealso [spk_source_url()] for pulling layers from arbitrary URLs.
#'
#' @examples
#' \dontrun{
#' path_gpkg <- fs::path(tempdir(), "layers.gpkg")
#' get_this <- c("whse_basemapping.bcgs_5k_grid", "WHSE_BASEMAPPING.BCGS_2500_GRID")
#' name_this <- c("grid_5k", "grid_2500")
#' purrr::walk2(
#'   .x = get_this,
#'   .y = name_this,
#'   .f = ~ spk_source_bcdata(
#'     bcdata_record_id = .x,
#'     path_gpkg = path_gpkg,
#'     layer_name = .y
#'   )
#' )
#' }
#'
#' @family download
#' @export
#' @importFrom bcdata bcdc_query_geodata collect filter INTERSECTS
#' @importFrom sf st_geometry st_transform st_intersection st_write
#' @importFrom stringr str_to_lower str_to_upper
#' @importFrom chk chk_string chk_file
spk_source_bcdata <- function(
    bcdata_record_id = NULL,
    path_gpkg = NULL,
    mask = NULL,
    layer_name = NULL) {
  chk::chk_string(bcdata_record_id)
  chk::chk_file(path_gpkg)
  if (!is.null(layer_name)) {
    chk::chk_string(layer_name)
  }
  bcdata_record_id <- stringr::str_to_upper(bcdata_record_id)

  if (!is.null(mask)) {
    mask <- mask |>
      sf::st_geometry() |>
      sf::st_transform(crs = 3005)
    l <- bcdata::bcdc_query_geodata(bcdata_record_id) |>
      bcdata::filter(bcdata::INTERSECTS(mask)) |>
      bcdata::collect() |>
      sf::st_intersection(mask)
  } else {
    l <- bcdata::bcdc_query_geodata(bcdata_record_id) |>
      bcdata::collect()
  }

  if (is.null(layer_name)) {
    layer_name <- bcdata_record_id
  }

  l |>
    sf::st_write(
      dsn = path_gpkg,
      layer = stringr::str_to_lower(layer_name),
      delete_layer = TRUE
    )
}
