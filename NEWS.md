# spacehakr 0.4.0

- **[spk_source_url()] silently failed on any URL containing `&`, which is every service
  endpoint.** `system2()` pastes its arguments into a command string and runs it through
  `sh`, quoting only the command itself — measured: `system2("echo", args = "a&b")` prints
  `a` and reports `sh: b: command not found`. A query-string URL was therefore split at
  each `&`, and the trailing `count=1` was read by `sh` as a successful variable
  assignment, so `ogr2ogr` reported **status 0 having written nothing**. Arguments are now
  shell-quoted at the point of invocation.

  The same gap was a **command-injection** vector, not only a correctness bug: a `;`,
  backtick or `$()` reaching `sh` inside a caller-supplied `urls` or `query` value would
  have executed. That matters wherever these values come from a config file or a layer
  catalog rather than from a literal in the calling script.

  This also restores `query`. The 0.3.0 note below says `shQuote()` was removed because
  `system2()` "does not go through a shell"; that is not correct, and a `-where` clause
  containing quotes and spaces has been dying with a shell syntax error (loudly, at least)
  ever since. A caller who worked around it by pre-quoting their query should remove that
  quoting.

- [spk_source_url()] gains `vsi`, choosing the GDAL virtual filesystem each URL is read
  through. `/vsicurl/` — still the default, so nothing changes for existing callers —
  probes a source with a `HEAD` request and reads it with HTTP range requests, which a
  service endpoint addressed by a query string typically supports neither of. Measured
  against a BC Geographic Warehouse WFS on GDAL 3.13.0: `HEAD` returns 404 and a `Range`
  request is answered with a full-body 200, so the open fails before any driver is tried,
  and forcing the driver does not help. `vsi = "curl_streaming"` reads with a single
  sequential `GET` and works. Until now the only way to avoid `/vsicurl/` was to supply
  an `encoding`, which is a statement about a source's character set rather than its
  transport — so a WFS endpoint could not be expressed at all.

- **Behaviour change:** [spk_source_url()] now requires `layer` when a URL carries a
  query string. The derived name was `tools::file_path_sans_ext(basename(url))`, which
  for a WFS `GetFeature` request is the entire query string. A caller who relied on the
  derived name for a query-string URL — a presigned object URL, say — must now pass
  `layer` explicitly.

- [spk_source_url()] no longer leaks temp files when given several URLs with an
  `encoding`. `on.exit()` was registered inside the loop, so all registrations resolved
  to the last value of the source path: the final temp file was unlinked once per URL
  and every earlier one survived for the life of the session. Measured at 2 of 3 leaked.

- [spk_source_url()] refuses `encoding` combined with a non-default `vsi`. An encoded
  source is downloaded and re-encoded before conversion, so it never reaches a virtual
  filesystem, and honouring one argument while silently dropping the other is what made
  `encoding` usable as a transport switch in the first place.

# spacehakr 0.3.0

- [spk_source_url()] now fails loudly. The `ogr2ogr` exit status was never checked, so a
  bad URL, a 404 or an unreadable source returned exactly what success returned, and a
  layer that was never written looked identical to one that was. `stderr` now goes to a
  file rather than being merged into a discarded value, and a non-zero status aborts
  naming the URL and the tail of the diagnostic.

- [spk_source_url()] gains `open_options`, `a_srs`, `t_srs`, `layer` and `encoding`. A
  non-spatial CSV carrying coordinate columns can now become a point layer
  (`-oo X_POSSIBLE_NAMES=`, `-a_srs`), a source that is not UTF-8 is fetched and
  re-encoded before conversion (GDAL's CSV driver has no encoding open option), and the
  layer name no longer has to be whatever the URL's file name happens to be.

- [spk_source_url()] creates the output GeoPackage when it does not exist, rather than
  requiring one to append to.

- **Behaviour change:** [spk_source_url()]'s `query` is no longer passed through
  `shQuote()`. `system2()` with an argument vector does not go through a shell, so the
  quotes were reaching `-where` literally and the filter is unlikely to have worked. A
  caller who compensated by pre-quoting their query should remove that quoting.

# spacehakr 0.2.0

- Add [spk_source_url()] and [spk_source_bcdata()], which fetch layers into a
  GeoPackage from an arbitrary URL and from the BC Data Catalogue respectively.
  Sourcing data from public endpoints is what a reader needs to regenerate a
  report's inputs, so these belong in a public package.

  [spk_source_url()] reads through GDAL's `/vsicurl/` virtual filesystem and takes an
  optional SQL `query` applied as `-where`. It subsumes a separate CSV-only fetcher
  that was byte-equivalent to it with the filter omitted, so there is one entry point
  rather than two.

  `bcdata` joins `Imports` for [spk_source_bcdata()].

- Adopt the two STAC articles from `ngr`. Both demonstrate `spk_stac_calc()`, so
  they follow the function here rather than documenting a deprecated shim on ngr's
  site. They live in `vignettes/articles/` — pkgdown builds them, `R CMD build`
  ignores them. As true vignettes they would have to build on all five check
  runners against the live Planetary Computer API.
- Exclude `.git` from the build. In a `git worktree` checkout `.git` is a *file* holding an absolute developer path, and `R CMD build` ships it (it is only excluded when it is a directory).

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
