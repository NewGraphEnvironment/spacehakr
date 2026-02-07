# Remove Empty Raster Files

Scans a directory for raster files (e.g., .tif, .tiff, .vrt) and removes
those that contain only zero values. Uses
[`spk_rast_not_empty()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_rast_not_empty.md)
to check each raster.

## Usage

``` r
spk_rast_rm_empty(
  path = NULL,
  delete = TRUE,
  regexp = "\\.(tif|tiff|vrt)$",
  quiet = FALSE
)
```

## Arguments

- path:

  [character](https://rdrr.io/r/base/character.html) A single path to
  search for raster files.

- delete:

  [logical](https://rdrr.io/r/base/logical.html) Whether to delete the
  empty files. Default is `TRUE`.

- regexp:

  [character](https://rdrr.io/r/base/character.html) A regular
  expression passed to
  [`fs::dir_ls()`](https://fs.r-lib.org/reference/dir_ls.html) to select
  raster files. Default is '\\(tif\|tiff\|vrt)\$'.

- quiet:

  [logical](https://rdrr.io/r/base/logical.html) If `FALSE`, prints
  messages about files that are or can be removed. Default is `FALSE`.

## Value

[character](https://rdrr.io/r/base/character.html) A character vector of
paths to the raster files that were empty. Returns invisibly.

## See also

[`spk_rast_not_empty()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_rast_not_empty.md),
[`fs::dir_ls()`](https://fs.r-lib.org/reference/dir_ls.html),
[`fs::file_delete()`](https://fs.r-lib.org/reference/delete.html),
[`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html),
[`terra::values()`](https://rspatial.github.io/terra/reference/values.html)

Other raster:
[`spk_rast_ext()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_rast_ext.md),
[`spk_rast_not_empty()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_rast_not_empty.md),
[`spk_res()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_res.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Remove empty rasters from a directory
spk_rast_rm_empty("path/to/rasters")
} # }
```
