# Retrieve and optionally calculate spectral indices from a STAC item

Retrieve raster assets from a single STAC item with optional clipping to
an AOI and optional spectral index calculation. When `calc = NULL`, the
function simply returns the first asset (`asset_a`), optionally clipped.
When `calc` specifies an index (e.g., `"ndvi"`), the function reads the
required assets and computes the index.

## Usage

``` r
spk_stac_calc(
  feature,
  aoi = NULL,
  asset_a = "red",
  asset_b = "nir08",
  asset_c = NULL,
  calc = "ndvi",
  vsi_prefix = "/vsicurl/",
  quiet = FALSE,
  timing = FALSE
)
```

## Arguments

- feature:

  [list](https://rdrr.io/r/base/list.html) A single STAC Item (one
  element from an `items$features` list).

- aoi:

  [sf::sf](https://r-spatial.github.io/sf/reference/sf.html) or
  [NULL](https://rdrr.io/r/base/NULL.html) Optional. An AOI object used
  to restrict reads (by bbox) and to crop and mask the output. If
  `NULL`, the full assets are read and no crop/mask is applied. Default
  is `NULL`.

- asset_a:

  [character](https://rdrr.io/r/base/character.html) A single string
  giving the asset name for the first (or only) input band. For NDVI
  this corresponds to the red band. Default is `"red"`.

- asset_b:

  [character](https://rdrr.io/r/base/character.html) or
  [NULL](https://rdrr.io/r/base/NULL.html) Optional. A single string
  giving the asset name for the second input band. For NDVI this
  corresponds to the NIR band. For RGB this is the green band. Required
  when `calc` is not `NULL`. Default is `"nir08"`.

- asset_c:

  [character](https://rdrr.io/r/base/character.html) or
  [NULL](https://rdrr.io/r/base/NULL.html) Optional. A single string
  giving the asset name for the third input band. Required when
  `calc = "rgb"` (blue band). Default is `NULL`.

- calc:

  [character](https://rdrr.io/r/base/character.html) or
  [NULL](https://rdrr.io/r/base/NULL.html) Optional. The calculation to
  perform:

  - `NULL`: No calculation; return `asset_a` only (optionally clipped).

  - `"ndvi"`: Normalized Difference Vegetation Index using
    `(asset_b - asset_a) / (asset_b + asset_a)`.

  - `"rgb"`: Stack three bands into an RGB composite. Requires `asset_a`
    (red), `asset_b` (green), and `asset_c` (blue).

  Default is `"ndvi"`.

- vsi_prefix:

  [character](https://rdrr.io/r/base/character.html) Optional. A single
  string giving the GDAL VSI prefix used by
  [`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html)
  to enable streaming, windowed reads over HTTP. Exposed to allow
  alternative VSI backends (e.g. `/vsis3/`). Default is `"/vsicurl/"`.

- quiet:

  [logical](https://rdrr.io/r/base/logical.html) Optional. If `TRUE`,
  suppress CLI messages. Default is `FALSE`.

- timing:

  [logical](https://rdrr.io/r/base/logical.html) Optional. If `TRUE`,
  emit simple elapsed-time messages for reads. Default is `FALSE`.

## Value

A
[terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
with asset values or calculated index values.

## Details

The default asset names (`"red"` and `"nir08"`) align with common
conventions in Landsat Collection 2 Level-2 STAC items (e.g. the
`landsat-c2-l2` collection on Planetary Computer), but are fully
parameterized to support other collections with different band naming
schemes.

This function expects `feature` to provide the required `assets`
referenced by `asset_a` and, when `calc` is not `NULL`, also `asset_b`
(and `asset_c` for RGB). When `aoi` is not `NULL`, `feature` must also
have `properties$"proj:epsg"` so the AOI can be transformed for windowed
reads.

When `calc = NULL`, only `asset_a` is read and returned (optionally
clipped to the AOI). When `calc = "ndvi"`, the function computes the
Normalized Difference Vegetation Index using `(b - a) / (b + a)`. When
`calc = "rgb"`, the three assets are stacked into an RGB composite at
native resolution. This structure allows additional spectral indices
(e.g. NDWI, EVI) to be added in the future without changing the data
access or cropping logic.

When `aoi` is provided, reading is limited to the AOI bounding box in
the feature's projected CRS, and then cropped/masked to the AOI. When
`aoi = NULL`, the full assets are read and returned for the full raster
extent.

## Production-ready alternative

This function is a proof of concept demonstrating how to perform raster
calculations on STAC items using `terra`. For production workflows
involving time series reductions, multi-image composites, or data cubes
with varying pixel sizes and coordinate reference systems, consider the
[gdalcubes](https://github.com/appelmar/gdalcubes) package. Key
functions include:

- `stac_image_collection()`: Create an image collection directly from
  STAC query results with automatic band detection and VSI prefix
  handling.

- `cube_view()`: Define spatiotemporal extent, resolution, aggregation,
  and resampling method in a single specification.

- `raster_cube()`: Build a data cube from an image collection,
  automatically reprojecting and resampling images to a common grid.

- `apply_pixel()`: Apply arithmetic expressions (e.g.,
  `"(nir - red) / (nir + red)"`) across all pixels.

- `reduce_time()`: Temporal reductions (mean, median, max, etc.) to
  composite multi-date imagery.

## See also

[`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html),
[`terra::crop()`](https://rspatial.github.io/terra/reference/crop.html),
[`terra::mask()`](https://rspatial.github.io/terra/reference/mask.html),
[`sf::st_transform()`](https://r-spatial.github.io/sf/reference/st_transform.html)

## Examples

``` r
if (FALSE) { # \dontrun{
# STAC query against Planetary Computer (Landsat C2 L2)
stac_url <- "https://planetarycomputer.microsoft.com/api/stac/v1"
y <- 2000
date_time <- paste0(y, "-05-01/", y, "-07-30")

# Define an AOI from a bounding box (WGS84)
bbox <- c(
  xmin = -126.55350240037997,
  ymin =  54.4430453753869,
  xmax = -126.52422763064457,
  ymax =  54.46001902038006
)

aoi <- sf::st_as_sfc(sf::st_bbox(bbox, crs = 4326)) |>
  sf::st_as_sf()

stac_query <- rstac::stac(stac_url) |>
  rstac::stac_search(
    collections = "landsat-c2-l2",
    datetime = date_time,
    intersects = sf::st_geometry(aoi)[[1]],
    limit = 200
  ) |>
  rstac::ext_filter(`eo:cloud_cover` <= 10)

items <- stac_query |>
  rstac::post_request() |>
  rstac::items_fetch() |>
  rstac::items_sign_planetary_computer()

ndvi_list <- items$features |>
  purrr::map(spk_stac_calc, aoi = aoi)

ndvi_list <- ndvi_list |>
  purrr::set_names(purrr::map_chr(items$features, "id"))

# Retrieve a single asset (no calculation) from Sentinel-2
stac_query_s2 <- rstac::stac(stac_url) |>
  rstac::stac_search(
    collections = "sentinel-2-l2a",
    datetime = "2023-07-01/2023-07-31",
    intersects = sf::st_geometry(aoi)[[1]],
    limit = 10
  ) |>
  rstac::ext_filter(`eo:cloud_cover` <= 10)

items_s2 <- stac_query_s2 |>
  rstac::post_request() |>
  rstac::items_fetch() |>
  rstac::items_sign_planetary_computer()

# Get just the visual (RGB) asset clipped to AOI, no calculation
visual_list <- items_s2$features |>
  purrr::map(spk_stac_calc, aoi = aoi, asset_a = "visual", calc = NULL)

# Build RGB composite from native 10m bands (higher resolution than visual)
rgb_list <- items_s2$features |>
  purrr::map(
    spk_stac_calc,
    aoi = aoi,
    asset_a = "B04",
    asset_b = "B03",
    asset_c = "B02",
    calc = "rgb"
  )
} # }
```
