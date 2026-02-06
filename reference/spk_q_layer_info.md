# Extract Layer Information from QGIS Project

Reads a QGIS project file (`.qgs` or `.qgz`) and extracts layer
metadata, including menu name, provider, data source, and layer name.

## Usage

``` r
spk_q_layer_info(path, attrs = c("id", "name", "source", "providerKey"))
```

## Arguments

- path:

  [character](https://rdrr.io/r/base/character.html) A single file path
  to a QGIS project file. Must end with `.qgs` or `.qgz`.

- attrs:

  [character](https://rdrr.io/r/base/character.html) Optional. A
  character vector of XML attribute names to extract from each layer
  node. Defaults to `c("id", "name", "source", "providerKey")`.

## Value

A [tibble::tibble](https://tibble.tidyverse.org/reference/tibble.html)
with one row per layer, including extracted attributes, plus computed
`layer_name` and `time_exported`, sorted alphabetically by `name`.

## Details

If the input is a `.qgz` file, it will be unzipped to extract the
internal `project.qgs`. The function then parses the XML structure of
the project to extract layer information from `<layer-tree-layer>`
nodes.

Returned columns include:

- `name_menu`: layer name as displayed in the QGIS menu

- `provider`: data provider key (e.g., `ogr`, `gdal`)

- `source`: absolute or relative path to the data source

- `layer_name`: the internal layer name string

- `id`: QGIS-assigned layer id

- `time_exported`: timestamp in format `yyyymmdd hh::mm` when the
  function was run

## Examples

``` r
if (FALSE) { # \dontrun{
res <- spk_q_layer_info(
  "~/Projects/gis/ng_koot_west_2023/ng_koot_west_2023.qgs",
  attrs = c("id", "name", "source", "providerKey")
)
} # }
```
