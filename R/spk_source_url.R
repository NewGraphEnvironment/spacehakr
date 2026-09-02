#' Download and Convert Files to GeoPackage Layers with Optional Filtering
#'
#' Downloads files from URLs and converts each into a layer within a GeoPackage
#' using the `ogr2ogr` command-line tool from GDAL. Optionally applies an SQL
#' filter to the data during conversion.
#'
#' Sources are read through GDAL's `/vsicurl/` virtual filesystem, so anything
#' `ogr2ogr` can open over HTTP works — FlatGeobuf, GeoJSON, GeoPackage, shapefile
#' archives and plain CSV among them. The layer name is derived from the file name
#' of each URL.
#'
#' @param path_gpkg [character] A string specifying the path to the output GeoPackage
#'   file. Must already exist.
#' @param urls [character] A vector of URLs pointing to the files to be downloaded
#'   and converted.
#' @param query [character] or [NULL] An optional SQL query string used to filter the
#'   data during conversion. If `NULL` (default), no filter is applied.
#'
#' @return Invisible `NULL`. Called for its side effects.
#'
#' @seealso [spk_geoserv_dlv()] for pulling a layer from a GeoServer WFS endpoint.
#'
#' @examples
#' \dontrun{
#' path_gpkg <- fs::path(tempdir(), "layers.gpkg")
#' base_url <- "https://raw.githubusercontent.com/smnorris/bcfishpass/main/parameters"
#' urls <- paste0(base_url, "/example_newgraph/parameters_habitat_thresholds.csv")
#' spk_source_url(path_gpkg, urls)
#' }
#'
#' @family download
#' @export
#' @importFrom chk chk_string chk_file chk_character
#' @importFrom cli cli_abort
#' @importFrom tools file_path_sans_ext
spk_source_url <- function(path_gpkg, urls, query = NULL) {
  chk::chk_string(path_gpkg)
  chk::chk_file(path_gpkg)
  chk::chk_character(urls)
  if (!is.null(query)) {
    chk::chk_string(query)
  }

  if (!nzchar(Sys.which("ogr2ogr"))) {
    cli::cli_abort("`ogr2ogr` is not on the PATH. Please install GDAL.")
  }

  for (url in urls) {
    args <- .spk_source_url_args(path_gpkg, url, query)
    system2("ogr2ogr", args = args, stdout = TRUE, stderr = TRUE)
  }

  invisible(NULL)
}

#' Build the ogr2ogr argument vector for a single source URL
#'
#' Internal. Split out from [spk_source_url()] so the invocation can be tested by
#' equality without GDAL installed, matching the argument-builder pattern used by
#' [spk_gdalwarp()].
#'
#' @param path_gpkg [character] Path to the output GeoPackage.
#' @param url [character] A single source URL.
#' @param query [character] or [NULL] Optional SQL filter.
#'
#' @return [character] The argument vector, excluding the `ogr2ogr` command itself.
#'
#' @noRd
#' @importFrom tools file_path_sans_ext
.spk_source_url_args <- function(path_gpkg, url, query = NULL) {
  layer_name <- tools::file_path_sans_ext(basename(url))

  c(
    "-f", "GPKG",
    path_gpkg,
    "-update",
    "-overwrite",
    "-nln", layer_name,
    if (!is.null(query)) c("-where", shQuote(query)),
    paste0("/vsicurl/", url)
  )
}
