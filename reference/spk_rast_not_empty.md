# Check if Raster Has Non-Zero Data

Determines whether a raster file contains any non-zero values.

## Usage

``` r
spk_rast_not_empty(f)
```

## Arguments

- f:

  [character](https://rdrr.io/r/base/character.html) A single file path
  to a raster file.

## Value

[logical](https://rdrr.io/r/base/logical.html) `TRUE` if the raster has
any non-zero values, otherwise `FALSE`.

## See also

Other raster:
[`spk_rast_ext()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_rast_ext.md),
[`spk_rast_rm_empty()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_rast_rm_empty.md),
[`spk_res()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_res.md)
