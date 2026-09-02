# spacehakr 0.1.0

First tagged release. Twelve spatial functions extracted from `ngr`'s `ngr_spk_*`
family — GDAL and OpenDroneMap command building, GeoServer WFS download, STAC
raster math, spatial joins and raster utilities. See the
[reference index](https://newgraphenvironment.github.io/spacehakr/reference/).

This release exists so `ngr` has a pinnable version to depend on while it
deprecates its own copies of these functions
([ngr#7](https://github.com/NewGraphEnvironment/ngr/issues/7)).

- Declare `rlang` in `Imports`. It was imported by `spk_join()` via
  `@importFrom rlang .data` but never declared, so `R CMD check` failed with
  `Namespace dependency missing from DESCRIPTION Imports/Depends entries`. This
  went unnoticed because the package had no `R-CMD-check` workflow.
- Add an `R-CMD-check` workflow, so the twelve test files run on every push
  rather than never.
- Guard the `gdalwarp` run in `test-spk_gdalwarp.R`. It shelled out to the GDAL
  CLI at file top level with no guard, which errors the whole file on any
  machine without it — including every GitHub runner. Now scoped to a
  `test_that()` block that skips when `gdalwarp` is not on `PATH`.
