# Task: spk_source_url() cannot open a service endpoint with a query string: /vsicurl/ fails where /vsicurl_streaming/ works (#23)

## Context

`spk_source_url()` reads every streaming source through `/vsicurl/`. That works for a URL
ending in a recognisable file and fails for a **service endpoint with a query string** —
which is how a WFS `GetFeature` request is addressed. `/vsicurl/` wants range requests and
a sniffable extension; a BCGW WFS endpoint sends `cache-control: private, no-store` and
has no extension, so the probe fails before the driver is ever tried. Forcing the driver
(`-if GeoJSON`, `GeoJSON:/vsicurl/…`) does not help. `/vsicurl_streaming/` reads
sequentially, needs neither, and works.

The only existing way to avoid `/vsicurl/` is to supply `encoding`, which downloads to a
temp file first. But `encoding` is a statement about a source's character set, not its
transport — setting a bogus one to force a download is a lie in config that the next
reader has to decode. This blocks a config-driven layer catalog, where a source is
described by a row rather than by arguments: a WFS endpoint has no encoding to declare and
so cannot be expressed at all.

Outcome: an explicit `vsi` argument defaulting to today's behaviour, so nothing changes for
existing callers and a WFS endpoint becomes expressible in one field.

## Files

| File | Change |
|---|---|
| `R/spk_source_url.R` | `vsi` argument, threaded into `.spk_source_resolve()`; cleanup-detection fix; layer guard; roxygen |
| `tests/testthat/test-spk_source_url.R` | New tests, extend the existing `/vsicurl/` pin |
| `NEWS.md` | One entry under a new heading |

`spk_stac_calc()` has a related `vsi_prefix` argument (`R/spk_stac_calc.R:171`). It is
**not** being changed — noted so a reviewer does not read the naming difference as an
oversight. Its argument is a raw prefix pasted into `terra::rast()`; this one is a
validated transport choice, and unifying them is a separate call.

## Phase 1: Tests first

- [x] `.spk_source_resolve()` returns `/vsicurl/<url>` when `vsi` is defaulted — extend the
      existing pin at `test-spk_source_url.R:197`, do not replace it
- [x] `.spk_source_resolve()` returns `/vsicurl_streaming/<url>` for `vsi = "curl_streaming"`
- [x] `spk_source_url()` rejects an unknown `vsi` value, naming the valid set
- [x] `spk_source_url()` aborts when `layer` is NULL and a URL carries a query string
- [x] `spk_source_url()` aborts when `encoding` is combined with a non-default `vsi`
- [x] `.spk_source_url_args()` passes a `/vsicurl_streaming/` source through unchanged as
      the final element

The WFS case itself is **not** end-to-end testable here: this package's standing bar is
that no test touches the network, and the check matrix has five runners with no guaranteed
GDAL CLI. The live confirmation is Phase 5 and lands in `findings.md`, not the suite.

## Phase 2: The `vsi` argument

- [x] `vsi = "curl"` in the signature, validated against `c("curl", "curl_streaming")`
      with an explicit `cli_abort`. **Changed from the plan's `match.arg()`:** match.arg
      partial-matches, so `"curl_stream"` was silently accepted and the call went on to
      shell out to a live URL; and its message reads `'arg' should be one of ...`, naming
      neither the argument nor the bad value — which was the entire reason for choosing an
      enumerated argument over a free-form prefix.
- [x] `.spk_source_resolve(url, encoding, vsi)` builds `paste0("/vsi", vsi, "/", url)`
- [x] Abort when `!is.null(encoding) && !identical(vsi, "curl")` — the two are competing
      statements about transport, and silently ignoring one is how the current
      encoding-as-transport-switch workaround came about. A default `vsi` alongside
      `encoding` stays legal, so no existing caller is affected.

**Fix the temp-file cleanup while here — the `vsi` argument forces it.** `spk_source_url()`
currently decides whether the resolver made a temp file by reconstructing the string it
would have returned:

```r
source <- .spk_source_resolve(url, encoding)
if (!identical(source, paste0("/vsicurl/", url))) {   # R/spk_source_url.R:117
  on.exit(unlink(source), add = TRUE)
}
```

With `vsi = "curl_streaming"` the resolved source is `/vsicurl_streaming/<url>`, which is
not identical to the reconstruction — so an `unlink()` gets registered against a virtual
path. Inert today, and wrong in the direction that stays quiet.

- [x] Replace with `if (!is.null(encoding))`. The encoding branch is the only one that
      writes a temp file, and it is knowable before the resolver runs.

## Phase 3: Layer-name guard

Measured, GDAL 3.13.0 / R on this machine: `basename()` of a WFS `GetFeature` URL is the
entire query string, and `file_path_sans_ext()` leaves it intact. The derived layer name is
`ows?service=WFS&version=2.0.0&request=GetFeature&typeName=…`.

- [x] When `layer` is NULL and a URL contains `?`, abort naming the URL and asking for
      `layer`. Checked in the same pre-flight block as the existing length check, before
      any `ogr2ogr` runs — not per-iteration after the first layer has been written.

## Phase 4: Documentation

- [x] `@param vsi` — what each value means and *when* to reach for streaming: a service
      endpoint with a query string, a source with no extension, a `no-store` cache header
- [x] Amend the description and `@details`, which currently state `/vsicurl/` as the only
      streaming path (`R/spk_source_url.R:6`, `:28`)
- [x] A runnable-shaped `\dontrun{}` example using a WFS endpoint with `layer` supplied
- [x] `devtools::document()`, reading its output for unexpected `.Rd` writes
- [x] `NEWS.md` entry under a new `# spacehakr 0.3.0.9000` heading. Version bump and tag
      are `/gh-pr-merge`'s release bookkeeping, not this branch.

## Phase 5: Verification

- [x] **Confirm the premise live** before believing any of this. The whole change is worth
      nothing if `/vsicurl_streaming/` does not actually fix it, and the issue's
      measurement is GDAL 3.13.3 where this machine has 3.13.0:

      ```bash
      ogr2ogr -f GPKG /tmp/a.gpkg "/vsicurl/<wfs-url>"            # expect: Unable to open
      ogr2ogr -f GPKG /tmp/b.gpkg "/vsicurl_streaming/<wfs-url>"  # expect: a layer
      ogrinfo -so /tmp/b.gpkg                                     # expect: Feature Count >= 1
      ```

      Then the same through `spk_source_url(vsi = "curl_streaming")`. Both results into
      `findings.md` with the GDAL version — a positive control alongside the failure, so a
      broken probe cannot read as a confirmed diagnosis.

- [x] **Restore the bug, three faults, confirm the tests go red** — the pattern the #256
      archive used. Record the FAIL counts:

      | Fault injected | Expect |
      |---|---|
      | `vsi` ignored, always `/vsicurl/` | FAIL 3 |
      | cleanup check back to the `paste0()` reconstruction | FAIL 1 |
      | layer guard removed | FAIL 3 |
      | encoding/`vsi` mutual exclusion removed | FAIL 3 |
      | restored | PASS 55 |

- [x] `Rscript -e 'devtools::test()' 2>&1 | grep -E "(FAIL|ERROR|PASS)" | tail -5`
- [x] `lintr::lint_package()` — diff against the `HEAD` baseline for the touched file
      rather than reading the raw count
- [x] `devtools::check(vignettes = FALSE)` — expect the pre-existing `spk_odm.Rd` line-width
      note and nothing new
- [x] `/code-check` on the staged diff (2 rounds: 4 findings fixed, then clean)

## Validation

- [x] Tests pass
- [x] `/code-check` clean
- [x] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion, README carrying the Measurement and Evidence
      sections

## Unplanned work that verification forced

- [x] **`system2()` shell-quoting.** The live end-to-end check found `spk_source_url()`
      silently returning success and writing nothing for any URL containing `&` — every
      service endpoint, which is the whole point of this issue. `system2()` runs its
      arguments through `sh`; the URL split at each `&` and the trailing `count=1` was a
      successful variable assignment, so status was 0. Fixed by quoting at the invocation
      boundary. This also restores `query`, whose `shQuote()` was removed in 0.3.0 on
      reasoning that measurement contradicts. Fault-injected: FAIL 2.
- [x] **Multi-URL temp-file leak.** `on.exit()` registered inside the loop late-binds to
      the last `source`; 2 of 3 temp files leaked. Raised by the plan review, confirmed by
      measurement, fixed and pinned. Fault-injected: FAIL 1.
