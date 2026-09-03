# Task: spk_source_url() — fail loudly, coordinate CSVs, non-UTF-8 sources (rfp#256)


## Context

`spk_source_url()` was adopted into spacehakr from a private package earlier today
(#20, shipped in `v0.2.0`) as a **pure relocation** — its known defects travelled with
it deliberately, so the move stayed bisectable. This is the follow-up that fixes them.

The driver is ECCC CABIN open data (Canadian Aquatic Biomonitoring Network) — site and
benthic-invertebrate records published as CSV at stable public URLs. Exactly what this
function is for, and it cannot ingest them today: they are UTF-16LE, carry Latitude /
Longitude columns rather than geometry, and the layer name embeds a date range that
moves when the publisher rolls the file.

Tracked in rfp#256. Project context stays there; the work below stands on its own.

Five defects, all in `R/spk_source_url.R`:

| # | Defect | Current line |
|---|---|---|
| 1 | `system2()` return never checked — failure is indistinguishable from success | `:50` |
| 2 | No way to pass `-oo` / `-a_srs` / `-t_srs`, so a coordinate CSV lands with no geometry | `.spk_source_url_args()` |
| 3 | Source encoding assumed UTF-8; the CABIN CSVs are UTF-16LE | — |
| 4 | Layer name derived from the URL, not overridable | `:71` |
| 5 | `chk::chk_file(path_gpkg)` — cannot create a GeoPackage | `:38` |

## Target signature

```r
spk_source_url(path_gpkg, urls, query = NULL, layer = NULL,
               open_options = NULL, a_srs = NULL, t_srs = NULL, encoding = NULL)
```

Every new argument maps to one acceptance criterion. `NULL` defaults preserve today's
behaviour except where the issue says it must change.

## Decisions taken while planning

1. **`layer` is `NULL` or the same length as `urls`.** Recycling a length-1 name across
   several URLs would silently overwrite one layer repeatedly.
2. **Encoding conversion downloads first, then converts, then hands `ogr2ogr` a local
   file.** GDAL's CSV driver has no general encoding open option, so `/vsicurl/`
   streaming cannot work here. Download via `httr2` (already in Imports, and the
   pattern `spk_geoserv_dlv()` already uses). Only when `encoding` is non-`NULL`;
   otherwise `/vsicurl/` streaming stays the default.
3. **`shQuote(query)` is fixed as part of this.** `system2()` with an `args` vector does
   not go through a shell, so the quotes currently reach `-where` literally. Not named
   in the issue, but it is a defect in the argument builder this work rewrites, and
   `query` is unlikely ever to have worked. Called out because it is a behaviour change.
4. **The failure-path test stubs `system2()`** rather than fetching a 404. The issue asks
   for a failure test; the standing bar here is that no test touches the network. A stub
   returning non-zero and writing canned stderr exercises the abort branch exactly, and
   deterministically.

## Phase 1 — Fail loudly

- [ ] Capture status: `stderr` to a temp file, `stdout = FALSE`, `on.exit(unlink(...))`
- [ ] On non-zero, `cli::cli_abort()` naming the URL and the tail of stderr — bare
      interpolated string, matching house style (no `c(x=, i=)` bullets anywhere in `R/`)
- [ ] Test: stub `system2()` to return 1 and write canned stderr; assert the abort
      message contains both the URL and the stderr tail
- [ ] Test: success path still returns `invisible(NULL)`

## Phase 2 — Create the GeoPackage if absent

- [ ] Replace `chk::chk_file(path_gpkg)` with a check that the *parent directory* exists
- [ ] `.spk_source_url_args()` gains `update =`; emit `-update -overwrite` only when the
      file already exists. `-update` against a missing file is an ogr2ogr error, and
      `-f GPKG` alone creates it
- [ ] Tests: argument vector with and without `-update`; a missing parent directory
      still errors with `class = "chk_error"`

## Phase 3 — Settable layer name

- [ ] `layer = NULL` keeps `file_path_sans_ext(basename(url))`
- [ ] Validate: `NULL`, or character the same length as `urls`; `cli::cli_abort()` on a
      length mismatch
- [ ] Tests: default derivation unchanged; supplied name reaches `-nln`; length mismatch
      aborts

## Phase 4 — Open options and CRS

- [ ] `open_options` — character vector of `KEY=VALUE`, expanded to a repeated `-oo` per
      element (`c(rbind("-oo", open_options))`)
- [ ] `a_srs` (assign, for a CSV carrying no CRS) and `t_srs` (reproject) as separate
      arguments — the issue names both and they are not interchangeable
- [ ] Fix `shQuote(query)` per decision 3
- [ ] Tests: argument-vector equality for the CABIN shape
      (`-oo X_POSSIBLE_NAMES=Longitude -oo Y_POSSIBLE_NAMES=Latitude
      -oo KEEP_GEOM_COLUMNS=NO -a_srs EPSG:4326`); each option absent when `NULL`;
      `-where` receives the unquoted query

## Phase 5 — Non-UTF-8 sources

- [ ] `encoding = NULL` (default) streams through `/vsicurl/` exactly as now
- [ ] When supplied: fetch to a temp file with `httr2`, re-encode to UTF-8, hand
      `ogr2ogr` the local path. `on.exit()` cleanup for both temp files
- [ ] Factor the source resolution so `.spk_source_url_args()` takes an
      already-resolved `source` — either `/vsicurl/<url>` or a local path — which keeps
      it pure and testable
- [ ] Test with a **locally written UTF-16LE fixture**, no network: convert it, assert
      the result reads back as UTF-8 with the expected header
- [ ] Guarded end-to-end test (`skip_if(!nzchar(Sys.which("ogr2ogr")))`) converting that
      fixture into a real GeoPackage layer — now possible offline, because this phase
      introduces the local-source path

## Phase 6 — Docs, NEWS, and the bilingual-header note

- [ ] `@param` for every new argument; a worked `@examples` block for the coordinate-CSV
      case, using a neutral public dataset — no internal buckets or project paths
- [ ] `@details` note on bilingual slash-separated headers (`Site/Site`, `Year/Année`)
      and what `ogr2ogr` makes of the slashes and accents. Verify rather than assert —
      it is a general shape of Canadian federal open data, not one publisher's quirk
- [ ] NEWS entry, fledge style (`- ` prefix, `[spk_source_url()]` bracket refs)
- [ ] Note in NEWS that `query` behaviour changes with the `shQuote` fix

## Verification

- [ ] `devtools::test()` — no network access added; the suite's zero-network bar holds
- [ ] `devtools::check(vignettes = FALSE)` — 0 errors, 0 warnings. One pre-existing NOTE
      (`spk_odm.Rd` example line widths) is expected and unrelated
- [ ] `lintr::lint()` per changed file — 120-char limit
- [ ] **Restore the bug**, per phase: revert the status check → the stubbed-failure test
      must fail; drop `-oo` expansion → the argument test must fail. A test that cannot
      fail is not evidence
- [ ] Confirm each of the issue's six acceptance criteria has a test, and say which test
      covers which
- [ ] R-CMD-check green on all five runners

## Not in scope

- Pulling the CABIN tables into any downstream project — that is the issue's "once this
  lands" follow-on, and it happens in the private repo
- `spk_source_bcdata()`, untouched
- Any general local-file source API. Local paths appear only as an internal artifact of
  encoding conversion; `urls` remains the public contract
