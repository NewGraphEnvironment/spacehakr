# spacehakr <img src="man/figures/logo.png" align="right" height="139" alt="spacehakr hex sticker" />

<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

Spatial analysis, raster processing, and geospatial data access tools for R. 

`spacehakr` provides utilities for:
- **Command building** — Generate GDAL and OpenDroneMap CLI arguments
- **GeoServer access** — Download vector data from WFS services
- **Raster operations** — Compute extents, check for empty tiles, filter rasters
- **Vector operations** — Spatial joins, layer introspection
- **STAC queries** — Calculate statistics from STAC catalog assets
- **QGIS integration** — Query layer information via QGIS

Extracted from the `ngr` package's `ngr_spk_*` function family.

## Installation

Install the development version from GitHub:

```r
# install.packages("pak")
pak::pkg_install("NewGraphEnvironment/spacehakr")
```

## Usage

### Inspect layers in a GeoPackage

```r
library(spacehakr)

# Get layer names and geometry types from a spatial file
spk_layer_info("data.gpkg")
#>         name geomtype features fields
#> 1     roads LINESTRING     1234      8
#> 2  buildings    POLYGON      567     12
#> 3     points      POINT      890      5
```

### Compute combined extent from rasters

```r
# Get bounding box spanning multiple rasters
raster_files <- c("tile1.tif", "tile2.tif", "tile3.tif")
bbox <- spk_rast_ext(raster_files)
bbox
#>      xmin      ymin      xmax      ymax 
#>  -123.456   48.123  -122.789   48.987

# Reproject the extent to WGS84
bbox_wgs84 <- spk_rast_ext(raster_files, crs_out = "EPSG:4326")
```
### Build GDAL warp commands

```r
# Generate gdalwarp arguments for reprojection
args <- spk_gdalwarp(
  path_in = c("input1.tif", "input2.tif"),
  path_out = "output.tif",
  t_srs = "EPSG:3005",
  target_resolution = c(0.25, 0.25)
)

# Get the full command string for manual execution
cmd <- spk_gdalwarp(
 path_in = "input.tif",
  path_out = "output.tif",
  interactive = TRUE
)
cat(cmd)
#> gdalwarp -overwrite -multi -wo NUM_THREADS=ALL_CPUS ...
```

### Download from GeoServer WFS

```r
# Download vector data from a GeoServer instance
data <- spk_geoserv_dlv(
  url_base = "https://openmaps.gov.bc.ca/geo/pub",
  layer = "WHSE_BASEMAPPING.TRIM_CONTOUR_LINES",
  bbox = c(-123.5, 48.0, -123.0, 48.5)
)
```

### Filter empty raster tiles

```r
# Check if a raster contains only NA/nodata
spk_rast_not_empty("tile.tif")
#> [1] TRUE

# Remove empty tiles from a list
valid_tiles <- spk_rast_rm_empty(c("tile1.tif", "tile2.tif", "empty.tif"))
```

## Function families

| Family | Functions | Description |
|--------|-----------|-------------|
| **command-builder** | `spk_gdalwarp()`, `spk_odm()` | Build CLI arguments for GDAL and ODM |
| **geoserver** | `spk_geoserv_dlv()` | Download from WFS services |
| **raster** | `spk_rast_ext()`, `spk_rast_not_empty()`, `spk_rast_rm_empty()`, `spk_res()` | Raster extent and validation |
| **vector** | `spk_join()`, `spk_layer_info()`, `spk_poly_to_points()` | Vector operations and introspection |
| **qgis** | `spk_q_layer_info()` | QGIS layer queries |
| **stac** | `spk_stac_calc()` | STAC catalog statistics |

## License

MIT
