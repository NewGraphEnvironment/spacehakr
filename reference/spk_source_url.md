# Download and Convert Files to GeoPackage Layers

Downloads files from URLs and converts each into a layer within a
GeoPackage using the `ogr2ogr` command-line tool from GDAL.

## Usage

``` r
spk_source_url(
  path_gpkg,
  urls,
  query = NULL,
  layer = NULL,
  open_options = NULL,
  a_srs = NULL,
  t_srs = NULL,
  encoding = NULL
)
```

## Arguments

- path_gpkg:

  [character](https://rdrr.io/r/base/character.html) Path to the output
  GeoPackage. Created if it does not exist; its parent directory must
  exist.

- urls:

  [character](https://rdrr.io/r/base/character.html) URLs of the files
  to download and convert.

- query:

  [character](https://rdrr.io/r/base/character.html) or
  [NULL](https://rdrr.io/r/base/NULL.html) Optional SQL filter applied
  during conversion via `-where`. If `NULL` (default), no filter is
  applied.

- layer:

  [character](https://rdrr.io/r/base/character.html) or
  [NULL](https://rdrr.io/r/base/NULL.html) Optional output layer
  name(s). If `NULL` (default), each layer is named for the file name of
  its URL. If supplied, must be the same length as `urls`.

- open_options:

  [character](https://rdrr.io/r/base/character.html) or
  [NULL](https://rdrr.io/r/base/NULL.html) Optional GDAL open options as
  `"KEY=VALUE"` strings, each passed as a separate `-oo`.

- a_srs:

  [character](https://rdrr.io/r/base/character.html) or
  [NULL](https://rdrr.io/r/base/NULL.html) Optional CRS to *assign* to a
  source that carries none, e.g. `"EPSG:4326"`.

- t_srs:

  [character](https://rdrr.io/r/base/character.html) or
  [NULL](https://rdrr.io/r/base/NULL.html) Optional CRS to *reproject*
  the source to.

- encoding:

  [character](https://rdrr.io/r/base/character.html) or
  [NULL](https://rdrr.io/r/base/NULL.html) Optional source encoding,
  e.g. `"UTF-16LE"`. When supplied the file is fetched and re-encoded to
  UTF-8 before conversion.

## Value

Invisible `NULL`. Called for its side effects.

## Details

Sources are read through GDAL's `/vsicurl/` virtual filesystem, so
anything `ogr2ogr` can open over HTTP works — FlatGeobuf, GeoJSON,
GeoPackage, shapefile archives and plain CSV among them.

A non-spatial CSV carrying coordinate columns becomes a point layer by
passing the relevant GDAL open options and assigning a CRS:

    open_options = c("X_POSSIBLE_NAMES=Longitude",
                     "Y_POSSIBLE_NAMES=Latitude",
                     "KEEP_GEOM_COLUMNS=NO"),
    a_srs = "EPSG:4326"

Without them the file still imports, as an attribute table with no
geometry.

`a_srs` *assigns* a CRS to a source that carries none; `t_srs`
*reprojects* a source that already has one. They are not
interchangeable.

GDAL's CSV driver has no general encoding open option, so a source that
is not UTF-8 cannot be fixed with `open_options`. Pass `encoding`
instead and the file is fetched and re-encoded before `ogr2ogr` sees it,
rather than streamed through `/vsicurl/`.

Canadian federal open data often ships bilingual, slash-separated column
headers — `Site/Site`, `Year/Année`. Verified against GDAL 3.x: both the
slash and the accent survive into the GeoPackage exactly, so `ogrinfo`
reports the fields as `Site/Site` and `Year/Année`.

They do not survive the trip back into R unchanged, though.
[`sf::st_read()`](https://r-spatial.github.io/sf/reference/st_read.html)
returns a data frame, and R makes column names syntactic — the slash
becomes a dot (`Site.Site`) while the accent is kept (`Year.Année`). So
the name in the file and the name in your session differ, and a
downstream SQL `query` against this layer must use the *file's* name,
quoted.

## See also

[`spk_geoserv_dlv()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_geoserv_dlv.md)
for pulling a layer from a GeoServer WFS endpoint.

Other download:
[`spk_source_bcdata()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_source_bcdata.md)

## Examples

``` r
if (FALSE) { # \dontrun{
path_gpkg <- fs::path(tempdir(), "layers.gpkg")

# a coordinate CSV published as UTF-16, landing as a point layer
spk_source_url(
  path_gpkg = path_gpkg,
  urls = "https://example.org/opendata/sites.csv",
  layer = "sites",
  open_options = c(
    "X_POSSIBLE_NAMES=Longitude",
    "Y_POSSIBLE_NAMES=Latitude",
    "KEEP_GEOM_COLUMNS=NO"
  ),
  a_srs = "EPSG:4326",
  encoding = "UTF-16LE"
)
} # }
```
