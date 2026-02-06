# Download a Vector Layer from a GeoServer WFS

This function downloads a single vector layer from a WFS (Web Feature
Service) endpoint and saves it locally in GeoJSON or another supported
format.

## Usage

``` r
spk_geoserv_dlv(
  url_geoserver = "https://maps.skeenasalmon.info/geoserver/ows",
  dir_out = NULL,
  layer_name_raw = NULL,
  layer_name_out = stringr::str_extract(layer_name_raw, "(?<=:).*"),
  crs = 3005,
  bbox = NULL,
  format_out = "json",
  discard_no_features = TRUE
)
```

## Arguments

- url_geoserver:

  [character](https://rdrr.io/r/base/character.html) A single URL string
  to the GeoServer WFS endpoint.

- dir_out:

  [character](https://rdrr.io/r/base/character.html) A directory path
  where the output file will be saved. Must exist or be creatable.

- layer_name_raw:

  [character](https://rdrr.io/r/base/character.html) A WFS layer name,
  usually including a namespace (e.g., `geonode:LayerName`).

- layer_name_out:

  [character](https://rdrr.io/r/base/character.html) Optional. Output
  file name without extension. Defaults to the name extracted from
  `layer_name_raw`.

- crs:

  [integer](https://rdrr.io/r/base/integer.html) EPSG code for the
  coordinate reference system to request from the server. Default is
  3005.

- bbox:

  [`sf::st_bbox()`](https://r-spatial.github.io/sf/reference/st_bbox.html)
  Optional. A bounding box to filter features spatially. Must be in the
  same CRS or coercible.

- format_out:

  [character](https://rdrr.io/r/base/character.html) WFS output format.
  Common values: "json", "GML2", "shape-zip". Default is "json" and
  function will need to be modified in the future to accommodate other
  formats.

- discard_no_features:

  [logical](https://rdrr.io/r/base/logical.html) Optional. If `TRUE`,
  automatically deletes downloaded files that have zero features.
  Default is `TRUE`.

## Value

Invisibly returns the output file path on success. Prints status
messages to console.

## Details

By default, the `layer_name_out` is inferred from `layer_name_raw` by
removing a namespace prefix (e.g., `geonode:`), which is common in
GeoServer layers.

If a bounding box is passed as a
[`sf::st_bbox()`](https://r-spatial.github.io/sf/reference/st_bbox.html)
object and it has a different CRS than the target CRS, it will be
transformed using
[`sf::st_transform()`](https://r-spatial.github.io/sf/reference/st_transform.html).

Regardless of `discard_no_features`, the function will scan the first
few lines of the downloaded GeoJSON file and warn if no features are
found. If `discard_no_features = TRUE`, the empty file is deleted.

## See also

[`fs::dir_create()`](https://fs.r-lib.org/reference/create.html),
[`fs::path()`](https://fs.r-lib.org/reference/path.html),
[`sf::st_bbox()`](https://r-spatial.github.io/sf/reference/st_bbox.html),
[`sf::st_transform()`](https://r-spatial.github.io/sf/reference/st_transform.html),
[`cli::cli_alert_warning()`](https://cli.r-lib.org/reference/cli_alert.html)

## Examples

``` r
if (FALSE) { # \dontrun{
dir_out <- "data/gis/skt/esi_sows"
layer_name_raw <- "geonode:UBulkley_wshed"
spk_geoserv_dl(
  dir_out = dir_out,
  layer_name_raw = layer_name_raw
)
} # }
```
