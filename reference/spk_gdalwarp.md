# Generate GDALWarp Command Arguments

Constructs the command-line arguments for GDAL's `gdalwarp` utility,
allowing for flexible reprojection and resampling of raster data. The
function can return either a vector of arguments for programmatic use or
a complete command string for manual execution when
`interactive = TRUE`.

## Usage

``` r
spk_gdalwarp(
  path_in,
  path_out,
  s_srs = NULL,
  t_srs = "EPSG:3005",
  resampling = "bilinear",
  target_resolution = c(0.15, 0.15),
  overwrite = TRUE,
  interactive = FALSE,
  params_default = c("-multi", "-wo", "NUM_THREADS=ALL_CPUS"),
  params_add = NULL
)
```

## Arguments

- path_in:

  [character](https://rdrr.io/r/base/character.html) A vector of file
  paths to input rasters. Must be valid file paths.

- path_out:

  [character](https://rdrr.io/r/base/character.html) A single file path
  for the output raster. The directory must exist.

- s_srs:

  [character](https://rdrr.io/r/base/character.html) or
  [NULL](https://rdrr.io/r/base/NULL.html) Optional. The source spatial
  reference system in any GDAL-supported format (e.g., EPSG codes, PROJ
  strings). Defaults to `NULL`, meaning it will be inferred from the
  input raster.

- t_srs:

  [character](https://rdrr.io/r/base/character.html) The target spatial
  reference system in any GDAL-supported format. Defaults to
  `"EPSG:3005"`.

- resampling:

  [character](https://rdrr.io/r/base/character.html) The resampling
  method. One of `"nearest"`, `"bilinear"`, `"cubic"`, `"cubicspline"`,
  `"lanczos"`, `"average"`, `"mode"`. Defaults to `"bilinear"`.

- target_resolution:

  [numeric](https://rdrr.io/r/base/numeric.html) A numeric vector of
  length 2 specifying the output pixel resolution in meters for the x
  and y directions. Defaults to `c(0.15, 0.15)` (15cm x 15cm pixels).

- overwrite:

  [logical](https://rdrr.io/r/base/logical.html) Whether to overwrite
  the output file if it exists. Defaults to `TRUE`.

- interactive:

  [logical](https://rdrr.io/r/base/logical.html) Whether to return the
  full `gdalwarp` command as a string for manual use. Defaults to
  `FALSE`.

- params_default:

  [character](https://rdrr.io/r/base/character.html) or
  [NULL](https://rdrr.io/r/base/NULL.html) Optional. A character vector
  of default parameters to include in the `gdalwarp` command. Defaults
  to `c("-multi", "-wo", "NUM_THREADS=ALL_CPUS")`.

- params_add:

  [character](https://rdrr.io/r/base/character.html) or
  [NULL](https://rdrr.io/r/base/NULL.html) Optional. A character vector
  of additional parameters to include in the `gdalwarp` command.

## Value

[character](https://rdrr.io/r/base/character.html) A vector of arguments
for programmatic use or a complete command string if
`interactive = TRUE`.

## Details

The function constructs command-line arguments for `gdalwarp`, enabling
flexible raster reprojection, resampling, and transformation. Note that
`gdalwarp` requires GDAL to be installed on your system. On macOS, you
can install GDAL using Homebrew by running `brew install gdal`. For more
details on `gdalwarp`, visit:
<https://gdal.org/en/stable/programs/gdalwarp.html>.

## See also

[gdalwarp
documentation](https://gdal.org/en/stable/programs/gdalwarp.html)

Other command-builder:
[`spk_odm()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_odm.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Generate arguments for programmatic use
args <- spk_gdalwarp(
  path_in = c("input1.tif", "input2.tif"),
  path_out = "output.tif",
  s_srs = "EPSG:4326",
  t_srs = "EPSG:3857",
  target_resolution = c(0.1, 0.1)
)

# Generate a full command for manual use
cmd <- spk_gdalwarp(
  path_in = c("input1.tif", "input2.tif"),
  path_out = "output.tif",
  s_srs = "EPSG:4326",
  t_srs = "EPSG:3857",
  target_resolution = c(0.1, 0.1),
  interactive = TRUE
)
cat(cmd, "\n")
} # }
```
