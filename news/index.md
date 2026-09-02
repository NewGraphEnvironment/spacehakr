# Changelog

## spacehakr 0.1.0.9000 (development)

- Add \[spk_source_url()\] and \[spk_source_bcdata()\], which fetch
  layers into a GeoPackage from an arbitrary URL and from the BC Data
  Catalogue respectively. Sourcing data from public endpoints is what a
  reader needs to regenerate a report’s inputs, so these belong in a
  public package.

  \[spk_source_url()\] reads through GDAL’s `/vsicurl/` virtual
  filesystem and takes an optional SQL `query` applied as `-where`. It
  subsumes a separate CSV-only fetcher that was byte-equivalent to it
  with the filter omitted, so there is one entry point rather than two.

  `bcdata` joins `Imports` for \[spk_source_bcdata()\].

- Adopt the two STAC articles from `ngr`. Both demonstrate
  [`spk_stac_calc()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_stac_calc.md),
  so they follow the function here rather than documenting a deprecated
  shim on ngr’s site. They live in `vignettes/articles/` — pkgdown
  builds them, `R CMD build` ignores them. As true vignettes they would
  have to build on all five check runners against the live Planetary
  Computer API.

- Exclude `.git` from the build. In a `git worktree` checkout `.git` is
  a *file* holding an absolute developer path, and `R CMD build` ships
  it (it is only excluded when it is a directory).

## spacehakr 0.1.0

First tagged release. Twelve spatial functions extracted from `ngr`’s
`ngr_spk_*` family — GDAL and OpenDroneMap command building, GeoServer
WFS download, STAC raster math, spatial joins and raster utilities. See
the [reference
index](https://newgraphenvironment.github.io/spacehakr/reference/).

This release exists so `ngr` has a pinnable version to depend on while
it deprecates its own copies of these functions
([ngr#7](https://github.com/NewGraphEnvironment/ngr/issues/7)).

- Declare `rlang` in `Imports`. It was imported by
  [`spk_join()`](http://www.newgraphenvironment.com/spacehakr/reference/spk_join.md)
  via `@importFrom rlang .data` but never declared, so `R CMD check`
  failed with
  `Namespace dependency missing from DESCRIPTION Imports/Depends entries`.
  This went unnoticed because the package had no `R-CMD-check` workflow.
- Add an `R-CMD-check` workflow, so the twelve test files run on every
  push rather than never.
- Guard the `gdalwarp` run in `test-spk_gdalwarp.R`. It shelled out to
  the GDAL CLI at file top level with no guard, which errors the whole
  file on any machine without it — including every GitHub runner. Now
  scoped to a `test_that()` block that skips when `gdalwarp` is not on
  `PATH`.
