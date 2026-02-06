# Spatial Join with Optional Mask Filtering and Column Selection

Joins a target
[sf::sf](https://r-spatial.github.io/sf/reference/sf.html) object with a
mask [sf::sf](https://r-spatial.github.io/sf/reference/sf.html) object
using a specified spatial predicate. Optional filtering and selection of
columns from the mask can be applied.

## Usage

``` r
spk_join(
  target_tbl,
  mask_tbl,
  target_col_return = "*",
  mask_col_return = NULL,
  mask_col_filter = NULL,
  mask_col_filter_values = NULL,
  mask_col_filter_values_negate = FALSE,
  join_fun = sf::st_intersects,
  path_gpkg = NULL,
  collapse = FALSE,
  target_col_collapse = NULL,
  ...
)
```

## Arguments

- target_tbl:

  [sf::sf](https://r-spatial.github.io/sf/reference/sf.html) The target
  table to be spatially joined.

- mask_tbl:

  [character](https://rdrr.io/r/base/character.html) or
  [sf::sf](https://r-spatial.github.io/sf/reference/sf.html) The mask
  table name (if reading from `path_gpkg`) or an sf object.

- target_col_return:

  [character](https://rdrr.io/r/base/character.html) A vector of target
  column names to retain. Use "\*" to retain all.

- mask_col_return:

  [character](https://rdrr.io/r/base/character.html) or
  [NULL](https://rdrr.io/r/base/NULL.html) Optional. A vector of mask
  column names to retain. Default is `NULL`.

- mask_col_filter:

  [character](https://rdrr.io/r/base/character.html) or
  [NULL](https://rdrr.io/r/base/NULL.html) Optional. A single mask
  column name used for filtering rows.

- mask_col_filter_values:

  [character](https://rdrr.io/r/base/character.html) or
  [NULL](https://rdrr.io/r/base/NULL.html) Optional. Values to match (or
  exclude) in `mask_col_filter`.

- mask_col_filter_values_negate:

  [logical](https://rdrr.io/r/base/logical.html) Whether to exclude
  (`TRUE`) or include (`FALSE`) matching rows. Default is `FALSE`.

- join_fun:

  [function](https://rdrr.io/r/base/function.html) Spatial predicate
  function from
  [`sf::st_intersects()`](https://r-spatial.github.io/sf/reference/geos_binary_pred.html),
  [`sf::st_within()`](https://r-spatial.github.io/sf/reference/geos_binary_pred.html),
  etc. Default is
  [`sf::st_intersects`](https://r-spatial.github.io/sf/reference/geos_binary_pred.html).

- path_gpkg:

  [character](https://rdrr.io/r/base/character.html) or
  [NULL](https://rdrr.io/r/base/NULL.html) Optional. Path to a
  GeoPackage to read `mask_tbl` from if not already an sf object.

- collapse:

  [logical](https://rdrr.io/r/base/logical.html) Whether to collapse
  results to one amalgamated row with multiple results when more than
  one result is returned. Default is TRUE

- target_col_collapse:

  [character](https://rdrr.io/r/base/character.html) or
  [NULL](https://rdrr.io/r/base/NULL.html) Optional. A target column
  name to group by to facilitate collapsing the result.

- ...:

  Additional arguments passed to
  [`sf::st_join()`](https://r-spatial.github.io/sf/reference/st_join.html).

## Value

A sf object with the result of the spatial join. If `target_col_return`
is not "\*", only selected columns are returned.

## See also

Other vector:
[`spk_layer_info()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_layer_info.md),
[`spk_poly_to_points()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_poly_to_points.md)
