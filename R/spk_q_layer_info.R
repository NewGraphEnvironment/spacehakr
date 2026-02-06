#' Extract Layer Information from QGIS Project
#'
#' Reads a QGIS project file (`.qgs` or `.qgz`) and extracts layer metadata, including menu name, provider, data source, and layer name.
#'
#' @param path [character] A single file path to a QGIS project file. Must end with `.qgs` or `.qgz`.
#' @param attrs [character] Optional. A character vector of XML attribute names to extract from each layer node. Defaults to `c("id", "name", "source", "providerKey")`.
#'
#' @details
#' If the input is a `.qgz` file, it will be unzipped to extract the internal `project.qgs`. The function then parses the XML structure of the project to extract layer information from `<layer-tree-layer>` nodes.
#'
#' Returned columns include:
#' - `name_menu`: layer name as displayed in the QGIS menu
#' - `provider`: data provider key (e.g., `ogr`, `gdal`)
#' - `source`: absolute or relative path to the data source
#' - `layer_name`: the internal layer name string
#' - `id`: QGIS-assigned layer id
#' - `time_exported`: timestamp in format `yyyymmdd hh::mm` when the function was run
#'
#' @return A [tibble::tibble] with one row per layer, including extracted attributes, plus computed `layer_name` and `time_exported`, sorted alphabetically by `name`.
#'
#' @examples
#' \dontrun{
#' res <- spk_q_layer_info(
#'   "~/Projects/gis/ng_koot_west_2023/ng_koot_west_2023.qgs",
#'   attrs = c("id", "name", "source", "providerKey")
#' )
#' }
#'
#' @importFrom fs path_temp dir_create path path_dir path_abs
#' @importFrom utils unzip
#' @importFrom xml2 read_xml xml_ns_strip xml_find_all xml_attr
#' @importFrom tibble as_tibble
#' @importFrom dplyr mutate if_else select arrange
#' @importFrom purrr map_dfc
#' @family spacehakr
#' @export
spk_q_layer_info <- function(path, attrs = c("id", "name", "source", "providerKey")) {
  # Validate input
  chk::chk_string(path)
  chk::chk_character(attrs)

  if (grepl("\\.qgz$", path, ignore.case = TRUE)) {
    tmpdir <- fs::path_temp("qgz"); fs::dir_create(tmpdir)
    utils::unzip(path, files = "project.qgs", exdir = tmpdir)
    path <- fs::path(tmpdir, "project.qgs")
  }

  doc <- xml2::read_xml(path); xml2::xml_ns_strip(doc)
  proj_dir <- fs::path_dir(path)

  nodes <- xml2::xml_find_all(doc, "//layer-tree-layer[@id]")

  layer_tbl <- purrr::map_dfc(attrs, ~ xml2::xml_attr(nodes, .x)) |>
    stats::setNames(tolower(attrs)) |>
    tibble::as_tibble()

  layer_tbl |>
    dplyr::mutate(
      source = dplyr::if_else(
        startsWith(source, "./"),
        fs::path_abs(fs::path(proj_dir, substring(source, 3L))),
        source
      ),
      layer_name   = sub(".*\\|layername=([^|]+).*", "\\1", source),
      time_exported = as.POSIXct(format(Sys.time(), "%Y%m%d %H:%M"), format = "%Y%m%d %H:%M")
    ) |>
    dplyr::select(dplyr::everything(), layer_name, time_exported) |>
    dplyr::arrange(name)
}
