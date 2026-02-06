# Generate Regularly Spaced Points Inside Polygons

This function generates a regularly spaced grid of points inside each
polygon in a given `sf` object and assigns it an ID. The point density
is determined by a specified column.

## Usage

``` r
spk_poly_to_points(sf_in, col_density, col_id = NULL)
```

## Arguments

- sf_in:

  An `sf` object containing polygon geometries.

- col_density:

  [character](https://rdrr.io/r/base/character.html) The name of the
  column containing point density values per polygon.

- col_id:

  [character](https://rdrr.io/r/base/character.html) or
  [NULL](https://rdrr.io/r/base/NULL.html) The name of the column to use
  as the ID. Defaults to "id" if NULL.

## Value

An `sf` object containing the generated points with an ID column.

## See also

Other vector:
[`spk_join()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_join.md),
[`spk_layer_info()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_layer_info.md)

## Examples

``` r
poly <- sf::st_sf(
  region = c("A", "B"),
  col_density = c(1, 5),
  geometry = sf::st_sfc(
    sf::st_polygon(list(rbind(c(0, 0), c(10, 0), c(10, 10), c(0, 10), c(0, 0)))),
    sf::st_polygon(list(rbind(c(15, 15), c(20, 15), c(20, 20), c(15, 20), c(15, 15))))
  )
)

points <- spk_poly_to_points(poly, col_density = "col_density", col_id = "region")

plot(sf::st_geometry(poly))
 plot(sf::st_geometry(points), add = TRUE, col = "red", pch = 16)

```
