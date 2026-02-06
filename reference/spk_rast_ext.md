# Compute Combined Extent (Bounding Box) from Multiple Raster Files

Computes the combined spatial extent (bounding box) from one or more
raster files. It ensures that all input rasters share the same CRS and
optionally reprojects the bounding box to a specified CRS. The function
relies on
[`terra::ext()`](https://rspatial.github.io/terra/reference/ext.html),
[`terra::crs()`](https://rspatial.github.io/terra/reference/crs.html),
and
[`sf::st_bbox()`](https://r-spatial.github.io/sf/reference/st_bbox.html)
for extent extraction and CRS handling.

## Usage

``` r
spk_rast_ext(x, crs_out = NULL)
```

## Arguments

- x:

  [character](https://rdrr.io/r/base/character.html) A vector of file
  paths, URLs, or database connection strings to raster data sources.
  Each path must exist and be accessible to GDAL.

- crs_out:

  [character](https://rdrr.io/r/base/character.html) or
  [NULL](https://rdrr.io/r/base/NULL.html) Optional. A CRS string (e.g.,
  "EPSG:4326") to reproject the combined bounding box. If `NULL`, the
  CRS of the input rasters is retained. Default is `NULL`.

## Value

A bounding box object with:

- `xmin`: Minimum x-coordinate.

- `xmax`: Maximum x-coordinate.

- `ymin`: Minimum y-coordinate.

- `ymax`: Maximum y-coordinate. If `crs_out` is specified, the bounding
  box is reprojected to the target CRS.

## Details

This function ensures all input rasters share the same CRS before
computing the union of their extents. The resulting bounding box can be
reprojected to a target CRS if `crs_out` is provided. It uses
[`terra::ext()`](https://rspatial.github.io/terra/reference/ext.html) to
extract extents,
[`terra::crs()`](https://rspatial.github.io/terra/reference/crs.html) to
check CRS consistency, and
[`sf::st_bbox()`](https://r-spatial.github.io/sf/reference/st_bbox.html)
for constructing and reprojecting the bounding box.

## See also

Other raster:
[`spk_rast_not_empty()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_rast_not_empty.md),
[`spk_rast_rm_empty()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_rast_rm_empty.md),
[`spk_res()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_res.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Define input files
files_in <- c(
  "/path/to/file1.tif",
  "/path/to/file2.tif",
  "/path/to/file3.tif"
)

# Get the combined extent without reprojection
bbox_combined <- spk_rast_ext(files_in)

# Get the combined extent and reproject to EPSG:4326
bbox_reprojected <- spk_rast_ext(files_in, crs_out = "EPSG:4326")
} # }
```
