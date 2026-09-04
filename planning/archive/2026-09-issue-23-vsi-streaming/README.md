# spk_source_url(): choose the virtual filesystem (#23)

## Outcome

`spk_source_url()` gains `vsi`, selecting the GDAL virtual filesystem each URL is read
through — `"curl"` (default, unchanged behaviour) or `"curl_streaming"`. `/vsicurl/`
cannot open a service endpoint addressed by a query string, which is how a WFS
`GetFeature` request is written, so until now such a source could not be expressed at all.

The argument is validated explicitly rather than by `match.arg()`, which was the approved
plan. `match.arg` partial-matches, so a typo `"curl_stream"` was silently accepted and the
call went on to shell out to a live URL; and its message reads `'arg' should be one of ...`,
naming neither the argument nor the bad value — which was the entire reason the user chose
an enumerated argument over a free-form prefix string. The deviation is recorded on the
task plan rather than made quietly.

Two guards came with it: `layer` is now required when a URL carries a query string
(`basename()` of a `GetFeature` request is the whole query string), and `encoding` is
refused alongside a non-default `vsi`, since an encoded source is downloaded and never
reaches a virtual filesystem.

## What was learned

**The live end-to-end check is the one that found the real bug, and everything else passed
around it.** Unit tests, argument-builder tests and raw `ogr2ogr` controls were all green
while `spk_source_url()` was silently broken for the exact URL shape the issue is about.
Running the finished function against the endpoint reported *"returned normally"* with no
GeoPackage on disk.

`system2()` pastes its arguments into a command string and runs it through `sh`, quoting
only the command. So the URL split at every `&`, and the trailing `count=1` was read as a
successful variable assignment — status 0, nothing written, and the abort added in v0.3.0
never fired. It was also a command-injection vector.

**This makes v0.3.0's conclusion wrong, and the wrong reasoning had been copied into a
comment, a test name and a NEWS entry.** That release removed `shQuote(query)` because
"`system2()` with an argument vector does not go through a shell". It does. `-where` has
been broken since — loudly, so survivable. Round 1 of `/code-check` found the inverted
comment still sitting in the test file at the exact line the quoting was removed from,
after the same sentence had been corrected in two other places. A wrong claim propagates
into every artefact that quotes it, and fixing the code does not retract them.

**A markdown heading in `@details` captures everything after it.** Inserting
`# Reading a service endpoint` mid-block made roxygen file the unrelated bilingual-column
prose under it — including the load-bearing note that a downstream SQL `query` must use the
file's field name rather than the session's. Invisible in the source; visible only in the
generated `.Rd`.

**`on.exit()` inside a loop late-binds.** Every registration resolved to the last value of
`source`, so the final temp file was unlinked once per URL and the earlier ones leaked.
Raised by the plan review as a prediction, confirmed by measurement.

## Measurement

- `/vsicurl/` vs `/vsicurl_streaming/` on a BCGW WFS endpoint, GDAL 3.13.0, with a plain
  `curl` positive control (HTTP 200, 417,978 bytes): `/vsicurl/` exit **1**, no file;
  `/vsicurl_streaming/` exit **0**, Feature Count 1, MULTIPOLYGON, EPSG 3005.
- The issue's stated cause was wrong. No `cache-control` header is sent; `HEAD` returns
  **404** and a `Range` request is answered with a full-body **200**, not a 206. The
  predicate worth documenting is "supports neither HEAD nor range requests" — a property of
  service endpoints generally rather than of one header. Issue body corrected.
- Shell quoting, measured four ways: `-where` raw → status 2, no file; `-where` quoted →
  status 0, 1 row; URL with `&` raw → **status 0, no file**; URL with `&` quoted → status 0,
  1 row. Only the third is silent, and it is the one this issue walks into.
- Temp-file leak: **2 of 3** survived the call before the fix.
- Test suite **FAIL 0 | PASS 196**, up from 167. Lint 0, unchanged from baseline.
  `devtools::check(vignettes = FALSE)`: 0 errors, 0 warnings, 1 note — the pre-existing
  `spk_odm.Rd` example line widths, unrelated.
- Restore-the-bug, six injected faults, each confirming the tests can fail:

  | Fault | Result |
  |---|---|
  | `vsi` ignored, always `/vsicurl/` | FAIL 3 |
  | cleanup back to the `paste0()` reconstruction | FAIL 1 |
  | layer guard removed | FAIL 3 |
  | `encoding`/`vsi` exclusion removed | FAIL 3 |
  | `on.exit` back inside the loop | FAIL 1 |
  | `shQuote()` removed | FAIL 3 |
  | restored | PASS 63 |

## Evidence

- `findings.md` — the live measurements, both premise confirmations and the `system2()`
  diagnosis, with the commands that produced them.
- `review-23.md` — the concurrent Plan review, its findings and which were confirmed,
  overtaken, or noted-not-acted-on.
- `review-round1.md`, `review-round2.md` — `/code-check`. Round 1: four findings, all real,
  all fixed. Round 2: clean, having independently fault-injected both new guards and
  reproduced the "2 of 3 leaked" figure exactly.

## Wrong turns worth keeping

- The first `vsi` rejection test picked `"curl_stream"` as its invalid value. `match.arg`
  partial-matched it to `"curl_streaming"`, the call proceeded, and the test shelled out to
  the network — breaching the package's standing bar. That accident is what exposed the
  partial-matching problem and led to dropping `match.arg` entirely.
- The first shell-quoting assertion checked that every argument starts with `'`. It failed,
  and the instinct was that the fix was wrong. It was not: `shQuote()` switches the whole
  vector to double-quoting as soon as any element contains a single quote, escaping `$` and
  backticks. The assertion was rewritten to test the property that matters — the arguments
  survive shell parsing byte-identical — rather than the quoting style, which is an
  implementation detail.

- The mock-based tests passed locally and failed on **macos-latest and windows-latest**
  with `ogr2ogr is not on the PATH`. `spk_source_url()` checks `Sys.which("ogr2ogr")`
  before its loop, and stubbing `.spk_ogr2ogr()` does not bypass that guard — this machine
  simply has GDAL installed, which is what hid it. Reproduced locally by stripping GDAL
  from `PATH`, which turns a CI-only failure into a one-command check.

  The fix stubs the guard rather than adding `skip_no_ogr()`, because four of five runners
  have no `ogr2ogr` binary (`sf` pulls `libgdal-dev`, which does not ship it) and skipping
  would leave the fix with **no coverage at all** there. Verified that the choice is
  load-bearing: with GDAL absent, removing `shQuote()` still gives FAIL 2 and ignoring
  `vsi` still gives FAIL 3, so the mock twins genuinely guard the fix on those runners.

Closed by: PR #25 (branch `23-spk-source-url-vsi-streaming`)
