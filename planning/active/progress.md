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
