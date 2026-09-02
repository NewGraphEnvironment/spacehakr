# Download a BC Data Catalogue Layer to a GeoPackage

Downloads a layer from the BC Data Catalogue, optionally intersects it
with a mask, and writes it to a GeoPackage.

## Usage

``` r
spk_source_bcdata(
  bcdata_record_id = NULL,
  path_gpkg = NULL,
  mask = NULL,
  layer_name = NULL
)
```

## Arguments

- bcdata_record_id:

  [character](https://rdrr.io/r/base/character.html) A BC Data Catalogue
  record permanent id (e.g. `7ecfafa6-5e18-48cd-8d9b-eae5b5ea2881`),
  record name (e.g. `pscis-assessments`) or object name (e.g.
  `WHSE_FISH.PSCIS_ASSESSMENT_SVW`). Record names can be found at
  <https://catalogue.data.gov.bc.ca/>. Case is not significant — the
  value is upper-cased within the function.

- path_gpkg:

  [character](https://rdrr.io/r/base/character.html) Path to the output
  GeoPackage file. Must already exist.

- mask:

  [sf::sf](https://r-spatial.github.io/sf/reference/sf.html) Optional
  masking polygon used to clip the spatial extent.

- layer_name:

  [character](https://rdrr.io/r/base/character.html) Optional layer name
  to write to the GeoPackage. If `NULL`, defaults to `bcdata_record_id`
  lower-cased. Designed to work best when an object name is passed as
  `bcdata_record_id`.

## Value

The value of
[`sf::st_write()`](https://r-spatial.github.io/sf/reference/st_write.html),
invisibly. Called for its side effects.

## Details

Passing a `mask` can massively increase download speed, because the
bounding box of the mask is pushed down into the catalogue API query
rather than the full layer being collected and clipped locally.

## See also

[`spk_source_url()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_source_url.md)
for pulling layers from arbitrary URLs.

Other download:
[`spk_source_url()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_source_url.md)

## Examples

``` r
if (FALSE) { # \dontrun{
path_gpkg <- fs::path(tempdir(), "layers.gpkg")
get_this <- c("whse_basemapping.bcgs_5k_grid", "WHSE_BASEMAPPING.BCGS_2500_GRID")
name_this <- c("grid_5k", "grid_2500")
purrr::walk2(
  .x = get_this,
  .y = name_this,
  .f = ~ spk_source_bcdata(
    bcdata_record_id = .x,
    path_gpkg = path_gpkg,
    layer_name = .y
  )
)
} # }
```
