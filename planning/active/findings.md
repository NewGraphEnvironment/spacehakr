# Findings — spk_source_url() fixes (rfp#256)

## Starting point

`spk_source_url()` landed in this package via #20 (released in `v0.2.0`) as a **pure
relocation** from another package. Its defects were carried across deliberately so the
move contained no behaviour change and stayed bisectable. This issue is the follow-up.

## The five defects, located

| # | Defect | Where |
|---|---|---|
| 1 | `system2()` return never checked | `R/spk_source_url.R:50` |
| 2 | No `-oo` / `-a_srs` / `-t_srs` | `.spk_source_url_args()` |
| 3 | Source encoding assumed UTF-8 | — (no code path exists) |
| 4 | Layer name not overridable | `R/spk_source_url.R:71` |
| 5 | `chk::chk_file(path_gpkg)` blocks creating a GeoPackage | `R/spk_source_url.R:38` |

Defect 1 is the one that reaches every caller: `stdout = TRUE, stderr = TRUE` captures
both streams into a value that is then discarded, so the diagnostic explaining a failure
is collected and thrown away, and a layer that was never written looks exactly like one
that was.

## A sixth, not in the issue

`shQuote(query)` at `.spk_source_url_args()`. `system2()` with an `args` vector does not
invoke a shell, so the quotes reach ogr2ogr's `-where` literally. `query` has probably
never worked. Fixed here because this work rewrites that builder; called out because it
is a behaviour change rather than a pure addition.

## Constraints from the destination

- **No test in this package touches the network.** That rules out the issue's suggested
  404 test as written. Stubbing `system2()` to return non-zero exercises the same branch
  offline and deterministically.
- `cli::cli_abort()` with a bare interpolated string. No `c(x =, i =)` bullet vectors
  appear anywhere in `R/`.
- `chk::` namespaced, flat block at the top of the body.
- `httr2` is already in Imports and is the pattern `spk_geoserv_dlv()` uses for fetching.
- `R CMD check` runs on five runners; none is guaranteed to carry the GDAL CLI, so
  anything that shells out needs `skip_if(!nzchar(Sys.which("ogr2ogr")))`.

## Why encoding forces a local file

GDAL's CSV driver has no general encoding open option, so a UTF-16LE source cannot be
fixed with `-oo`. It has to be fetched and re-encoded before `ogr2ogr` sees it, which
means the `/vsicurl/` streaming path cannot serve this case.

Useful side effect: that local-source path makes an **offline** end-to-end test possible
for the first time — a fixture written to disk, converted, and read by real ogr2ogr, with
no network.
