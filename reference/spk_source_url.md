# Download and Convert Files to GeoPackage Layers with Optional Filtering

Downloads files from URLs and converts each into a layer within a
GeoPackage using the `ogr2ogr` command-line tool from GDAL. Optionally
applies an SQL filter to the data during conversion.

## Usage

``` r
spk_source_url(path_gpkg, urls, query = NULL)
```

## Arguments

- path_gpkg:

  [character](https://rdrr.io/r/base/character.html) A string specifying
  the path to the output GeoPackage file. Must already exist.

- urls:

  [character](https://rdrr.io/r/base/character.html) A vector of URLs
  pointing to the files to be downloaded and converted.

- query:

  [character](https://rdrr.io/r/base/character.html) or
  [NULL](https://rdrr.io/r/base/NULL.html) An optional SQL query string
  used to filter the data during conversion. If `NULL` (default), no
  filter is applied.

## Value

Invisible `NULL`. Called for its side effects.

## Details

Sources are read through GDAL's `/vsicurl/` virtual filesystem, so
anything `ogr2ogr` can open over HTTP works — FlatGeobuf, GeoJSON,
GeoPackage, shapefile archives and plain CSV among them. The layer name
is derived from the file name of each URL.

## See also

[`spk_geoserv_dlv()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_geoserv_dlv.md)
for pulling a layer from a GeoServer WFS endpoint.

Other download:
[`spk_source_bcdata()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_source_bcdata.md)

## Examples

``` r
if (FALSE) { # \dontrun{
path_gpkg <- fs::path(tempdir(), "layers.gpkg")
base_url <- "https://raw.githubusercontent.com/smnorris/bcfishpass/main/parameters"
urls <- paste0(base_url, "/example_newgraph/parameters_habitat_thresholds.csv")
spk_source_url(path_gpkg, urls)
} # }
```
