# Summarise Layers and Geometry Types in a Spatial Data Source

Extracts and summarises information about layers within a spatial vector
data source. Attempts to determine the geometry type of each layer by
querying a sample feature.

## Usage

``` r
spk_layer_info(path)
```

## Arguments

- path:

  [character](https://rdrr.io/r/base/character.html) A single string.
  Path to the vector spatial data source (e.g., a GeoPackage or
  shapefile).

## Value

[data.frame](https://rdrr.io/r/base/data.frame.html) A data frame of
available layers and their geometry types. If a layer contains no
geometry, or an error occurs during reading, the `geomtype` will be
`NA`.

## Details

Uses
[`sf::st_layers()`](https://r-spatial.github.io/sf/reference/st_layers.html)
to list available layers in the data source. For each layer, attempts to
read a single feature using an SQL query and determines the geometry
type using
[`sf::st_geometry_type()`](https://r-spatial.github.io/sf/reference/st_geometry_type.html).
Layers with no geometry or errors in reading are safely assigned `NA`.
The `driver` column is removed from the output as it may contain invalid
entries for further data frame operations.

## See also

[`sf::st_layers()`](https://r-spatial.github.io/sf/reference/st_layers.html),
[`sf::st_read()`](https://r-spatial.github.io/sf/reference/st_read.html),
[`sf::st_geometry_type()`](https://r-spatial.github.io/sf/reference/st_geometry_type.html)

Other vector:
[`spk_join()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_join.md),
[`spk_poly_to_points()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_poly_to_points.md)
