#' Download and Convert Files to GeoPackage Layers
#'
#' Downloads files from URLs and converts each into a layer within a GeoPackage
#' using the `ogr2ogr` command-line tool from GDAL.
#'
#' Sources are read through GDAL's `/vsicurl/` virtual filesystem, so anything
#' `ogr2ogr` can open over HTTP works — FlatGeobuf, GeoJSON, GeoPackage, shapefile
#' archives and plain CSV among them.
#'
#' @details
#' A non-spatial CSV carrying coordinate columns becomes a point layer by passing the
#' relevant GDAL open options and assigning a CRS:
#'
#' ```
#' open_options = c("X_POSSIBLE_NAMES=Longitude",
#'                  "Y_POSSIBLE_NAMES=Latitude",
#'                  "KEEP_GEOM_COLUMNS=NO"),
#' a_srs = "EPSG:4326"
#' ```
#'
#' Without them the file still imports, as an attribute table with no geometry.
#'
#' `a_srs` *assigns* a CRS to a source that carries none; `t_srs` *reprojects* a source
#' that already has one. They are not interchangeable.
#'
#' GDAL's CSV driver has no general encoding open option, so a source that is not UTF-8
#' cannot be fixed with `open_options`. Pass `encoding` instead and the file is fetched
#' and re-encoded before `ogr2ogr` sees it, rather than streamed through `/vsicurl/`.
#'
#' Canadian federal open data often ships bilingual, slash-separated column headers —
#' `Site/Site`, `Year/Année`. Verified against GDAL 3.x: both the slash and the accent
#' survive into the GeoPackage exactly, so `ogrinfo` reports the fields as `Site/Site`
#' and `Year/Année`.
#'
#' They do not survive the trip back into R unchanged, though. [sf::st_read()] returns a
#' data frame, and R makes column names syntactic — the slash becomes a dot
#' (`Site.Site`) while the accent is kept (`Year.Année`). So the name in the file and the
#' name in your session differ, and a downstream SQL `query` against this layer must use
#' the *file's* name, quoted.
#'
#' @param path_gpkg [character] Path to the output GeoPackage. Created if it does not
#'   exist; its parent directory must exist.
#' @param urls [character] URLs of the files to download and convert.
#' @param query [character] or [NULL] Optional SQL filter applied during conversion via
#'   `-where`. If `NULL` (default), no filter is applied.
#' @param layer [character] or [NULL] Optional output layer name(s). If `NULL` (default),
#'   each layer is named for the file name of its URL. If supplied, must be the same
#'   length as `urls`.
#' @param open_options [character] or [NULL] Optional GDAL open options as `"KEY=VALUE"`
#'   strings, each passed as a separate `-oo`.
#' @param a_srs [character] or [NULL] Optional CRS to *assign* to a source that carries
#'   none, e.g. `"EPSG:4326"`.
#' @param t_srs [character] or [NULL] Optional CRS to *reproject* the source to.
#' @param encoding [character] or [NULL] Optional source encoding, e.g. `"UTF-16LE"`.
#'   When supplied the file is fetched and re-encoded to UTF-8 before conversion.
#'
#' @return Invisible `NULL`. Called for its side effects.
#'
#' @seealso [spk_geoserv_dlv()] for pulling a layer from a GeoServer WFS endpoint.
#'
#' @examples
#' \dontrun{
#' path_gpkg <- fs::path(tempdir(), "layers.gpkg")
#'
#' # a coordinate CSV published as UTF-16, landing as a point layer
#' spk_source_url(
#'   path_gpkg = path_gpkg,
#'   urls = "https://example.org/opendata/sites.csv",
#'   layer = "sites",
#'   open_options = c(
#'     "X_POSSIBLE_NAMES=Longitude",
#'     "Y_POSSIBLE_NAMES=Latitude",
#'     "KEEP_GEOM_COLUMNS=NO"
#'   ),
#'   a_srs = "EPSG:4326",
#'   encoding = "UTF-16LE"
#' )
#' }
#'
#' @family download
#' @export
#' @importFrom chk chk_string chk_file chk_character chk_dir
#' @importFrom cli cli_abort
#' @importFrom fs path_dir file_exists
#' @importFrom tools file_path_sans_ext
spk_source_url <- function(path_gpkg,
                           urls,
                           query = NULL,
                           layer = NULL,
                           open_options = NULL,
                           a_srs = NULL,
                           t_srs = NULL,
                           encoding = NULL,
                           vsi = "curl") {
  chk::chk_string(path_gpkg)
  chk::chk_dir(fs::path_dir(path_gpkg))
  chk::chk_character(urls)
  if (!is.null(query)) chk::chk_string(query)
  if (!is.null(layer)) chk::chk_character(layer)
  if (!is.null(open_options)) chk::chk_character(open_options)
  if (!is.null(a_srs)) chk::chk_string(a_srs)
  if (!is.null(t_srs)) chk::chk_string(t_srs)
  if (!is.null(encoding)) chk::chk_string(encoding)
  chk::chk_string(vsi)

  # match.arg() would partial-match "curl_stream" to "curl_streaming" and, on a genuine
  # typo, report `'arg' should be one of ...` -- naming neither the argument nor the
  # value supplied. An explicit check is the reason this is an enumerated argument
  # rather than a free-form prefix string.
  if (!vsi %in% c("curl", "curl_streaming")) {
    cli::cli_abort(c(
      "`vsi` must be {.val curl} or {.val curl_streaming}, not {.val {vsi}}.",
      "i" = paste("{.val curl_streaming} reads the source with a single sequential GET.",
                  "Use it for a service endpoint that does not answer HEAD or serve",
                  "range requests -- a WFS {.code GetFeature} URL, for instance.")
    ))
  }

  if (!is.null(layer) && length(layer) != length(urls)) {
    cli::cli_abort(
      "`layer` must be NULL or the same length as `urls` ({length(urls)}), not {length(layer)}."
    )
  }

  # `encoding` downloads and re-encodes to a local file, which never reaches a virtual
  # filesystem at all. Honouring one and dropping the other silently is how `encoding`
  # came to be used as a transport switch in the first place.
  if (!is.null(encoding) && !identical(vsi, "curl")) {
    cli::cli_abort(c(
      "`encoding` and {.code vsi = \"{vsi}\"} cannot be combined.",
      "i" = paste("A source with an `encoding` is downloaded before conversion,",
                  "so it never reaches a virtual filesystem at all."),
      "x" = "Supply one or the other."
    ))
  }

  # A query-string URL has no usable file name: measured, `basename()` of a WFS
  # GetFeature request returns the entire query string. Checked over every URL up front
  # so the abort cannot land after earlier layers have already been written.
  if (is.null(layer)) {
    bad <- urls[grepl("?", urls, fixed = TRUE)]
    if (length(bad) > 0L) {
      cli::cli_abort(c(
        "`layer` is required when a URL carries a query string.",
        "i" = "No usable layer name can be derived from {.url {bad[[1]]}}.",
        "x" = "Affected: {length(bad)} of {length(urls)}."
      ))
    }
  }

  if (!nzchar(Sys.which("ogr2ogr"))) {
    cli::cli_abort("`ogr2ogr` is not on the PATH. Please install GDAL.")
  }

  for (i in seq_along(urls)) {
    url <- urls[[i]]
    source <- .spk_source_resolve(url, encoding, vsi)
    # `encoding` is the only branch that writes a temp file, and it is knowable before
    # the resolver runs. Inferring it by reconstructing the resolver's return value
    # instead would register a cleanup against a virtual path the moment `vsi` moves.
    if (!is.null(encoding)) {
      on.exit(unlink(source), add = TRUE)
    }

    args <- .spk_source_url_args(
      path_gpkg = path_gpkg,
      source = source,
      layer = if (is.null(layer)) tools::file_path_sans_ext(basename(url)) else layer[[i]],
      query = query,
      open_options = open_options,
      a_srs = a_srs,
      t_srs = t_srs,
      update = fs::file_exists(path_gpkg)
    )

    .spk_ogr2ogr(args, url)
  }

  invisible(NULL)
}

#' Run ogr2ogr and abort with its stderr on failure
#'
#' Internal. The exit status is the only thing distinguishing a written layer from one
#' that was never created, so it is captured rather than discarded, and `stderr` goes to
#' a file so the diagnostic survives to be reported.
#'
#' @param args [character] Argument vector, excluding the command itself.
#' @param url [character] Source URL, used only to name the failure.
#'
#' @return Invisible `NULL`.
#'
#' @noRd
#' @importFrom cli cli_abort
.spk_ogr2ogr <- function(args, url) {
  err <- tempfile(fileext = ".txt")
  on.exit(unlink(err), add = TRUE)

  status <- system2("ogr2ogr", args = args, stdout = FALSE, stderr = err)

  if (!identical(as.integer(status), 0L)) {
    cli::cli_abort("ogr2ogr failed for {.url {url}} (status {status}):\n{stderr_tail(err)}")
  }

  invisible(NULL)
}

#' Last lines of a captured stderr file
#'
#' Internal. Named without a leading dot so it can be called from inside a cli glue
#' template — cli reads `{.name ...}` as inline class markup, so a dotted name there
#' would be parsed as a style rather than evaluated.
#'
#' @param path [character] File holding captured stderr.
#'
#' @return [character] The last lines, newline-joined, or `""` if the file is absent.
#'
#' @noRd
#' @importFrom utils tail
stderr_tail <- function(path) {
  if (!file.exists(path)) {
    return("")
  }
  paste(utils::tail(readLines(path, warn = FALSE), 10L), collapse = "\n")
}

#' Resolve a URL to something ogr2ogr can open
#'
#' Internal. Returns a `/vsicurl/` path for the streaming case, or a local temp file
#' re-encoded to UTF-8 when `encoding` is supplied — GDAL's CSV driver has no general
#' encoding open option, so a non-UTF-8 source cannot be handled in place.
#'
#' @param url [character] A single source URL.
#' @param encoding [character] or [NULL] Source encoding.
#'
#' @return [character] A `/vsicurl/` path, or the path of a temp file the caller must
#'   clean up.
#'
#' @noRd
#' @importFrom httr2 request req_perform
#' @importFrom tools file_ext
.spk_source_resolve <- function(url, encoding = NULL, vsi = "curl") {
  if (is.null(encoding)) {
    return(paste0("/vsi", vsi, "/", url))
  }

  raw_file <- tempfile(fileext = paste0(".", tools::file_ext(url)))
  on.exit(unlink(raw_file), add = TRUE)
  httr2::req_perform(httr2::request(url), path = raw_file)

  .spk_reencode(raw_file, encoding, tools::file_ext(url))
}

#' Re-encode a file to UTF-8
#'
#' Internal. Split from `.spk_source_resolve()` so it can be tested against a local
#' fixture without a network fetch.
#'
#' @param path [character] File to convert.
#' @param encoding [character] Source encoding, e.g. `"UTF-16LE"`.
#' @param ext [character] Extension for the output temp file.
#'
#' @return [character] Path of a new UTF-8 temp file.
#'
#' @noRd
.spk_reencode <- function(path, encoding, ext = "csv") {
  con <- file(path, encoding = encoding)
  on.exit(close(con), add = TRUE)
  lines <- readLines(con, warn = FALSE)

  out <- tempfile(fileext = paste0(".", ext))
  writeLines(lines, out, useBytes = TRUE)
  out
}

#' Build the ogr2ogr argument vector for a single source
#'
#' Internal. Split out from [spk_source_url()] so the invocation can be tested by
#' equality without GDAL installed, matching the argument-builder pattern used by
#' [spk_gdalwarp()].
#'
#' @param path_gpkg [character] Path to the output GeoPackage.
#' @param source [character] Resolved source — a `/vsicurl/` path or a local file.
#' @param layer [character] Output layer name.
#' @param query [character] or [NULL] Optional SQL filter.
#' @param open_options [character] or [NULL] Optional `KEY=VALUE` open options.
#' @param a_srs [character] or [NULL] CRS to assign.
#' @param t_srs [character] or [NULL] CRS to reproject to.
#' @param update [logical] Whether the GeoPackage already exists. `-update` against a
#'   missing file is an ogr2ogr error; `-f GPKG` alone creates it.
#'
#' @return [character] The argument vector, excluding the `ogr2ogr` command itself.
#'
#' @noRd
.spk_source_url_args <- function(path_gpkg,
                                 source,
                                 layer,
                                 query = NULL,
                                 open_options = NULL,
                                 a_srs = NULL,
                                 t_srs = NULL,
                                 update = TRUE) {
  c(
    "-f", "GPKG",
    path_gpkg,
    if (update) c("-update", "-overwrite"),
    "-nln", layer,
    if (!is.null(open_options)) c(rbind("-oo", open_options)),
    if (!is.null(a_srs)) c("-a_srs", a_srs),
    if (!is.null(t_srs)) c("-t_srs", t_srs),
    # No shQuote: system2() with an args vector does not go through a shell, so quoting
    # here would reach -where literally.
    if (!is.null(query)) c("-where", query),
    source
  )
}
