# Progress — spk_source_url() virtual filesystem selection (#23)

## Session 2026-09-04

- Plan-mode exploration — phases approved by user
- Two API decisions settled with the user before planning:
  - `vsi` enum (`"curl"` / `"curl_streaming"`, `match.arg`) over a free-form
    `vsi_prefix` string, so a typo fails at the R boundary rather than as an opaque
    ogr2ogr `Unable to open datasource`
  - abort when `layer` is NULL and a URL carries a query string, rather than writing a
    layer named after the whole query string
- Created branch `23-spk-source-url-vsi-streaming` off main
- Scaffolded PWF baseline from issue #23 with approved phases
- Next: Phase 1 — tests first

- Confirmed the premise live on GDAL 3.13.0 against a second BCGW layer: `/vsicurl/`
  exits 1 with no file, `/vsicurl_streaming/` exits 0 with Feature Count 1, plain `curl`
  200/417,978 bytes as positive control. Found the issue's stated cause is wrong — the
  endpoint 404s on HEAD and ignores Range, and carries no `cache-control` header at all.
- Phases 1-3 landed. Four injected faults all caught (FAIL 3 / 1 / 3 / 3), restored PASS 55.
- Departed from the plan on one point: `match.arg()` replaced with an explicit check.
  It partial-matched a typo through to a live network call, and its message names neither
  the argument nor the value.
- Next: Phase 4 documentation and NEWS.
- Live end-to-end check found `spk_source_url()` silently succeeding on any URL with `&`
  — `system2()` runs args through `sh`. Fixed with `shQuote()` at the invocation boundary.
  This also showed v0.3.0's removal of `shQuote(query)` rested on inverted reasoning.
- Plan review + two `/code-check` rounds. Round 1: four findings, all real, all fixed
  (windows-runner `printf` tests, a surviving stale comment, an `@details` heading that
  swallowed unrelated prose, a mislabelled premise test). Round 2: clean.
- Issue #23 body corrected — it attributed the failure to a `cache-control` header the
  endpoint does not send; the measured cause is a 404 on HEAD and an ignored `Range`.
- Final: suite FAIL 0 | PASS 196, lint 0, check 1 pre-existing NOTE.
