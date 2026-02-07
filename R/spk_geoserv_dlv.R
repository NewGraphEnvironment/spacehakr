#' Download a Vector Layer from a GeoServer WFS
#'
#' This function downloads a single vector layer from a WFS (Web Feature Service)
#' endpoint and saves it locally in GeoJSON or another supported format.
#'
#' By default, the `layer_name_out` is inferred from `layer_name_raw` by removing
#' a namespace prefix (e.g., `geonode:`), which is common in GeoServer layers.
#'
#' @param url_geoserver [character] A single URL string to the GeoServer WFS endpoint.
#' @param dir_out [character] A directory path where the output file will be saved. Must exist or be creatable.
#' @param layer_name_raw [character] A WFS layer name, usually including a namespace (e.g., `geonode:LayerName`).
#' @param layer_name_out [character] Optional. Output file name without extension. Defaults to the name extracted from `layer_name_raw`.
#' @param crs [integer] EPSG code for the coordinate reference system to request from the server. Default is 3005.
#' @param bbox [sf::st_bbox()] Optional. A bounding box to filter features spatially. Must be in the same CRS or coercible.
#' @param format_out [character] WFS output format. Common values: "json", "GML2", "shape-zip". Default is "json" and function will need to be modified in the future to accommodate other formats.
#' @param discard_no_features [logical] Optional. If `TRUE`, automatically deletes downloaded files that have zero features. Default is `TRUE`.
#'
#' @return Invisibly returns the output file path on success. Prints status messages to console.
#'
#' @details
#' If a bounding box is passed as a `sf::st_bbox()` object and it has a different CRS
#' than the target CRS, it will be transformed using `sf::st_transform()`.
#'
#' Regardless of `discard_no_features`, the function will scan the first few lines of the downloaded
#' GeoJSON file and warn if no features are found. If `discard_no_features = TRUE`, the empty file is deleted.
#'
#' @seealso [fs::dir_create()], [fs::path()], [sf::st_bbox()], [sf::st_transform()], [cli::cli_alert_warning()]
#'
#' @examples
#' \dontrun{
#' dir_out <- "data/gis/skt/esi_sows"
#' layer_name_raw <- "geonode:UBulkley_wshed"
#' spk_geoserv_dl(
#'   dir_out = dir_out,
#'   layer_name_raw = layer_name_raw
#' )
#' }
#'
#' @family geoserver
#' @export
#' @importFrom chk chk_string chk_dir chk_not_null chk_flag
#' @importFrom fs dir_create path path_abs file_delete
#' @importFrom stringr str_extract
#' @importFrom sf st_crs st_transform st_bbox st_as_sfc
#' @importFrom cli cli_alert_warning cli_alert_success cli_abort
#' @importFrom httr2 request req_url_query req_error req_perform resp_status
spk_geoserv_dlv <- function(
  url_geoserver = "https://maps.skeenasalmon.info/geoserver/ows",
  dir_out = NULL,
  layer_name_raw = NULL,
  layer_name_out = stringr::str_extract(layer_name_raw, "(?<=:).*"),
  crs = 3005,
  bbox = NULL,
  format_out = "json",
  discard_no_features = TRUE
) {
  chk::chk_string(url_geoserver)
  chk::chk_string(layer_name_raw)
  chk::chk_string(layer_name_out)
  chk::chk_dir(dir_out)
  chk::chk_not_null(crs)
  chk::chk_flag(discard_no_features)

  # create directory with fs
  fs::dir_create(dir_out)

  # Construct the WFS GetFeature request URL
  query_params <- list(
    service = "WFS",
    version = "1.0.0",
    request = "GetFeature",
    typename = layer_name_raw,
    outputFormat = format_out,
    srsName = paste0("EPSG:", crs)
  )

  if (!is.null(bbox)) {
    if (inherits(bbox, "bbox")) {
      bbox_crs <- sf::st_crs(bbox)
      target_crs <- sf::st_crs(crs)
      if (!is.na(bbox_crs) && bbox_crs != target_crs) {
        bbox <- sf::st_bbox(sf::st_transform(sf::st_as_sfc(bbox), target_crs))
      }
    }
    bbox_str <- paste(c(bbox, paste0("EPSG:", crs)), collapse = ",")
    query_params$bbox <- bbox_str
  }

  # Send request and save response to a GeoJSON file
  file_out <- fs::path(dir_out, layer_name_out, ext = "geojson")

  response <- httr2::request(url_geoserver) |>
    httr2::req_url_query(!!!query_params) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform(path = file_out)

  status <- httr2::resp_status(response)

  if (status == 200) {
    if (format_out == "json") {
      text <- readLines(file_out, n = 10, warn = FALSE)
      if (any(grepl('"features"\\s*:\\s*\\[\\s*\\]', text))) {
        cli::cli_alert_warning("Downloaded layer has 0 features: {.file {file_out}}")
        if (discard_no_features) {
          fs::file_delete(file_out)
          cli::cli_alert_warning("Discarded downloaded layer with 0 features: {.file {file_out}}")
          return(invisible(NULL))
        }
      }
    }
    cli::cli_alert_success("GeoJSON saved to: {.file {fs::path_abs(file_out)}}")
  } else {
    cli::cli_abort("Failed to download layer. HTTP Status: {status}")
  }

  invisible(file_out)
}
