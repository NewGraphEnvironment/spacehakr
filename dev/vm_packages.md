# R Packages Required for spacehakr Development

## Core Dependencies (DESCRIPTION Imports)
These must be installed for the package to work:

- `chk` - Argument validation
- `cli` - User messaging
- `dplyr` - Data manipulation
- `fs` - File system operations
- `glue` - String interpolation
- `httr` - HTTP requests
- `purrr` - Functional programming
- `sf` - Vector spatial data
- `stringr` - String manipulation
- `terra` - Raster operations
- `tibble` - Tidy data frames
- `xml2` - XML parsing

## Test/Dev Dependencies (DESCRIPTION Suggests)
Needed for running tests and development:

- `mockery` - Test mocking ⚠️ *not installed on this VM*
- `processx` - Process management (used in gdalwarp tests)
- `rstac` - STAC catalog queries ⚠️ *not installed on this VM*
- `stars` - Raster data cubes ⚠️ *not installed on this VM*
- `testthat` (>= 3.0.0) - Testing framework

## Development Tools
- `devtools` - Package development
- `roxygen2` - Documentation generation
- `lintr` - Code linting
- `usethis` - Package setup utilities

## Optional (referenced in vignettes/examples)
- `mapview` - Interactive maps ⚠️ *not installed on this VM*
- `leaflet` - Interactive maps
- `leafem` - Leaflet extensions

## System Dependencies
- GDAL >= 3.0 (gdalwarp, gdal_translate, ogrinfo)
- Docker (for OpenDroneMap functions)

## Installation Commands

```r
# Core dependencies
install.packages(c(
  "chk", "cli", "dplyr", "fs", "glue", "httr", 
  "purrr", "sf", "stringr", "terra", "tibble", "xml2"
))

# Dev/test dependencies
install.packages(c(
  "devtools", "testthat", "mockery", "processx", 
  "rstac", "stars", "lintr", "usethis", "roxygen2"
))

# Optional
install.packages(c("mapview", "leaflet", "leafem"))
```
