# spk_source_url(): fail loudly, coordinate CSVs, non-UTF-8 sources (rfp#256)

## Outcome

`spk_source_url()` arrived here as a pure relocation with its defects intact, so the move
carried no behaviour change. This closed them out. The exit status of `ogr2ogr` is now
checked and `stderr` written to a file rather than merged into a discarded value, so a
failed fetch aborts naming the URL instead of returning exactly what success returned.
Five arguments were added — `open_options`, `a_srs`, `t_srs`, `layer`, `encoding` — and
the GeoPackage is created when absent rather than required to exist. `a_srs` and `t_srs`
are deliberately separate: assigning a CRS to a source that has none and reprojecting one
that does are different operations, and conflating them would silently mangle one case.

One fix was not on the issue's list. `shQuote(query)` was removed: `system2()` with an
argument vector never invokes a shell, so the quotes were reaching `-where` literally and
the filter is unlikely to have ever worked. It is a behaviour change and is called out in
NEWS.

Two acceptance criteria were met differently than specified, both recorded on the issue.
The requested 404 failure test cannot run under this package's standing bar that no test
touches the network, so the failure path stubs `system2()` instead — same branch,
deterministic — backed by a real `ogr2ogr` failure against a missing local file. And the
bilingual-header question was answered rather than left open.

## What was learned

**A fixture can lie, and a green test is not evidence that it did not.** The first
UTF-16 fixture used `file(open = "wb", encoding = "UTF-16LE")`, which does *not* re-encode
on write. It wrote ASCII, so the conversion test passed against a file that never had the
problem it existed to prove. Caught only because the downstream end-to-end test produced a
0-row layer. Rebuilt with `iconv(toRaw = TRUE)` + `writeBin`, and the null-interleaved
bytes asserted before the test was trusted.

**Verify the layer you are actually claiming about.** The docs asserted that slashes and
accents survive into the GeoPackage. The first check read the layer back with
`sf::st_read()` and saw `Site.Site`, which nearly went into the docs as GDAL's behaviour —
it is R making syntactic column names. `ogrinfo` shows the GeoPackage holds `Site/Site`
and `Year/Année` exactly. Both halves matter, because a SQL `query` against such a layer
must use the file's name, not the session's.

## Measurement

- Test suite for this function: **34 passing, 0 skipped** locally (ogr2ogr present, so the
  end-to-end paths genuinely ran). Full package suite `FAIL 0 | PASS 167`.
- `devtools::check(vignettes = FALSE)`: **0 errors, 0 warnings, 1 note** — the note is
  pre-existing `spk_odm.Rd` example line widths, unrelated.
- Restore-the-bug, three injected faults, confirming the tests can fail:

  | Fault | Result |
  |---|---|
  | stop checking the exit status | `FAIL 3` |
  | drop the `-oo` expansion | `FAIL 3` |
  | reinstate `shQuote(query)` | `FAIL 1` |
  | restored | `FAIL 0 \| PASS 34` |

- Bilingual headers, measured against GDAL 3.x rather than assumed: in the GeoPackage
  `Site/Site` and `Year/Année` survive exactly; via `sf::st_read()` they become
  `Site.Site` and `Year.Année` — slash to dot, accent kept.

Closed by: PR #21, merged `5bff436`, released `v0.3.0` (`aab392e`)
