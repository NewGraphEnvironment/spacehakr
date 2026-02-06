# spacehakr <img src="man/figures/logo.png" align="right" height="139" alt="spacehakr hex sticker" />

<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

Spatial analysis and geospatial data tools for R — raster processing, WFS access, GDAL command building, and more.

## Installation

```r
# install.packages("pak")
pak::pkg_install("NewGraphEnvironment/spacehakr")
```

## Examples

```r
library(spacehakr)

# Inspect layers in a GeoPackage
spk_layer_info("data.gpkg")

# Compute extent from multiple rasters
spk_rast_ext(c("tile1.tif", "tile2.tif"))

# Build GDAL warp command
spk_gdalwarp(
  path_in = "input.tif",
  path_out = "output.tif",
  t_srs = "EPSG:3005"
)

# Download from GeoServer WFS
spk_geoserv_dlv(
 url_base = "https://openmaps.gov.bc.ca/geo/pub",
  layer = "WHSE_BASEMAPPING.TRIM_CONTOUR_LINES",
  bbox = c(-123.5, 48.0, -123.0, 48.5)
)
```

## License

MIT
