# Extract Resolution from a Raster

This function calculates and extracts the resolution (in metres) of a
single pixel (centre) from a raster file. It determines the central
pixel of the raster, crops to that single pixel, and returns its
resolution in the specified CRS. Uses
[`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html),
[`terra::ext()`](https://rspatial.github.io/terra/reference/ext.html),
[`terra::crop()`](https://rspatial.github.io/terra/reference/crop.html),
and
[`terra::project()`](https://rspatial.github.io/terra/reference/project.html)
to perform these operations.

## Usage

``` r
spk_res(path, crs_out = "EPSG:3005")
```

## Arguments

- path:

  [character](https://rdrr.io/r/base/character.html) A file path to the
  input raster.

- crs_out:

  [character](https://rdrr.io/r/base/character.html) The desired CRS
  (default is "EPSG:3005").

## Value

[numeric](https://rdrr.io/r/base/numeric.html) A vector of length two
representing the resolution of the single pixel in metres in the
specified CRS.

## Details

The function first calculates the extent and resolution of the raster,
identifies the central pixel, and crops the raster to that pixel. It
then projects the cropped raster to the specified CRS and calculates the
resolution of the single pixel.

## See also

Other raster:
[`spk_rast_ext()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_rast_ext.md),
[`spk_rast_not_empty()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_rast_not_empty.md),
[`spk_rast_rm_empty()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_rast_rm_empty.md)

## Examples

``` r
path <- system.file("extdata", "test1.tif", package = "spacehakr")
crs_out <- "EPSG:32609"
spk_res(path, crs_out)
#> [1] 20 20
```
