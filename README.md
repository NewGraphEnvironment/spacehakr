
<!-- README.md is generated from README.Rmd. Please edit that file -->

# spacehakr <img src="man/figures/logo.png" align="right" height="139" alt="spacehakr hex sticker" />

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/NewGraphEnvironment/spacehakr/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/NewGraphEnvironment/spacehakr/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

Spatial analysis and geospatial data tools for R — raster processing,
WFS access, GDAL command building, spatial joins, and STAC catalog
queries.

## Installation

``` r
# install.packages("pak")
pak::pkg_install("NewGraphEnvironment/spacehakr")
```

## Examples

``` r
library(spacehakr)
library(sf)
#> Linking to GEOS 3.12.1, GDAL 3.8.4, PROJ 9.4.0; sf_use_s2() is TRUE
library(terra)
#> terra 1.8.93
```

### Inspect Layers in a GeoPackage

Query layer names and geometry types from any vector data source:

``` r
# Get path to bundled test data
gpkg_path <- system.file("extdata", "poly.gpkg", package = "spacehakr")

spk_layer_info(gpkg_path)
#>   name geomtype features fields
#> 1 poly  POLYGON        5      3
#>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       crs
#> 1 WGS 84, GEOGCRS["WGS 84",\n    ENSEMBLE["World Geodetic System 1984 ensemble",\n        MEMBER["World Geodetic System 1984 (Transit)"],\n        MEMBER["World Geodetic System 1984 (G730)"],\n        MEMBER["World Geodetic System 1984 (G873)"],\n        MEMBER["World Geodetic System 1984 (G1150)"],\n        MEMBER["World Geodetic System 1984 (G1674)"],\n        MEMBER["World Geodetic System 1984 (G1762)"],\n        MEMBER["World Geodetic System 1984 (G2139)"],\n        ELLIPSOID["WGS 84",6378137,298.257223563,\n            LENGTHUNIT["metre",1]],\n        ENSEMBLEACCURACY[2.0]],\n    PRIMEM["Greenwich",0,\n        ANGLEUNIT["degree",0.0174532925199433]],\n    CS[ellipsoidal,2],\n        AXIS["geodetic latitude (Lat)",north,\n            ORDER[1],\n            ANGLEUNIT["degree",0.0174532925199433]],\n        AXIS["geodetic longitude (Lon)",east,\n            ORDER[2],\n            ANGLEUNIT["degree",0.0174532925199433]],\n    USAGE[\n        SCOPE["Horizontal component of 3D system."],\n        AREA["World."],\n        BBOX[-90,-180,90,180]],\n    ID["EPSG",4326]]
```

### Compute Combined Extent from Multiple Rasters

Calculate the union bounding box across multiple raster files:

``` r
# Get paths to bundled test rasters
rast_files <- c(
  system.file("extdata", "test1.tif", package = "spacehakr"),
  system.file("extdata", "test2.tif", package = "spacehakr")
)

# Get combined extent
bbox <- spk_rast_ext(rast_files)
bbox
#>      xmin      ymin      xmax      ymax 
#>  668376.2 6042688.0  672724.8 6046013.4
```

### Spatial Joins with Filtering

Join points to polygons with optional column selection and filtering:

``` r
# Load bundled test data
points <- st_read(
  system.file("extdata", "points.gpkg", package = "spacehakr"), 
  quiet = TRUE
)
polygons <- st_read(
  system.file("extdata", "poly.gpkg", package = "spacehakr"), 
  quiet = TRUE
)

# Join points to polygons, returning specific columns
result <- spk_join(
  target_tbl = points,
  mask_tbl = polygons,
  target_col_return = "id",
  mask_col_return = "attribute_string"
)

result
#> Simple feature collection with 7 features and 2 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: 0 ymin: 0 xmax: 10 ymax: 10
#> Geodetic CRS:  WGS 84
#>     id attribute_string          geom
#> 1    1                a   POINT (0 0)
#> 1.1  1                b   POINT (0 0)
#> 2    2                b   POINT (1 1)
#> 2.1  2                c   POINT (1 1)
#> 3    3                d   POINT (2 2)
#> 4    4                e   POINT (3 3)
#> 5    5             <NA> POINT (10 10)
```

### Build GDAL Warp Commands

Generate GDAL command strings for raster reprojection:

``` r
# Build a gdalwarp command (interactive = TRUE returns full command string)
input_file <- system.file("extdata", "test1.tif", package = "spacehakr")

cmd <- spk_gdalwarp(
  path_in = input_file,
  path_out = file.path(tempdir(), "output.tif"),
  t_srs = "EPSG:3005",
  target_resolution = c(10, 10),
  resampling = "bilinear",
  interactive = TRUE
)

cat(cmd)
#> gdalwarp -overwrite -multi -wo NUM_THREADS=ALL_CPUS -t_srs EPSG:3005 -r bilinear -tr 10 10 /tmp/RtmpWmInno/temp_libpathd1f65705ea16/spacehakr/extdata/test1.tif /tmp/Rtmpc0pAHm/output.tif
```

### Download from GeoServer WFS

Fetch vector data from BC’s GeoServer (requires network access):

``` r
# Download contour lines within a bounding box
contours <- spk_geoserv_dlv(
  url_geoserver = "https://openmaps.gov.bc.ca/geo/pub/ows",
  dir_out = tempdir(),
  layer_name_raw = "pub:WHSE_BASEMAPPING.TRIM_CONTOUR_LINES",
  bbox = c(-123.5, 48.0, -123.0, 48.5),
  crs = 4326
)
```

### Query STAC Catalogs

Calculate spectral indices from STAC items (requires `rstac` and network
access):

``` r
library(rstac)

# Query Landsat data
items <- stac("https://planetarycomputer.microsoft.com/api/stac/v1") |>
  stac_search(
    collections = "landsat-c2-l2",
    bbox = c(-123.5, 48.0, -123.0, 48.5),
    datetime = "2023-06-01/2023-08-31"
  ) |>
  post_request() |>
  items_sign(sign_fn = sign_planetary_computer())

# Calculate NDVI from the first item
ndvi <- spk_stac_calc(
  feature = items$features[[1]],
  asset_a = "red",
  asset_b = "nir08",
  calc = "ndvi"
)
```

## Function Reference

| Function              | Description                                      |
|-----------------------|--------------------------------------------------|
| `spk_layer_info()`    | List layers and geometry types in vector sources |
| `spk_rast_ext()`      | Compute combined extent from multiple rasters    |
| `spk_join()`          | Spatial join with filtering and column selection |
| `spk_gdalwarp()`      | Build GDAL warp commands                         |
| `spk_geoserv_dlv()`   | Download from GeoServer WFS                      |
| `spk_stac_calc()`     | Calculate indices from STAC items                |
| `spk_odm()`           | Build OpenDroneMap commands                      |
| `spk_res()`           | Query raster resolution                          |
| `spk_rast_rm_empty()` | Remove empty rasters from file lists             |

## License

MIT
