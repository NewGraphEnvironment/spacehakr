# Plan review — #23 (Plan agent, 2026-09-04)

Reviewed `task_plan.md` against issue #23 and the code, before implementation finished.
Recorded here because message delivery is not durable and a file is greppable later.

## Verified and acted on

| Finding | Verdict | Action |
|---|---|---|
| **GAP-1** `on.exit(unlink(source))` inside the loop late-binds to the last value, leaking every earlier temp file | **Confirmed by measurement** — 2 of 3 temp files survived the call | Fixed: accumulate into `tmp_files`, register `on.exit` once before the loop. Test added. |
| **AC-2 / GAP-6** the layer guard is a behaviour change, not a no-op for existing callers | Correct — a presigned-URL source with `layer = NULL` works today and now aborts | NEWS bullet relabelled `**Behaviour change:**` |
| **AC-4** NEWS heading precedent is `# spacehakr 0.2.0.9000 (development)` with a matching dev `DESCRIPTION` | Confirmed against `aab392e~1` | Heading and `DESCRIPTION` set to `0.3.0.9000` |
| **GAP-4** a WFS example collides with the existing `@seealso spk_geoserv_dlv()` | Correct — both fetch WFS | One sentence distinguishing them |
| **GAP-5** `@param vsi` implies streaming is strictly better | Correct, and the misreading that produces a bug report | Documented what sequential reading costs |
| **AS-1** the `?` guard is narrow; other URL shapes still derive poor names silently | Correct | Scope stated in the docs rather than implied |
| **GAP-3** three stale roxygen blocks beyond the two the plan named | Correct | All three updated |

## Findings already answered by the implementation

The review read the plan, not the finished code, so several findings were overtaken.

- **BL-1** (`!identical(vsi, "curl")` aborts every `encoding=` caller because the un-matched
  default is a length-2 vector) — real against the plan, moot against the code: `match.arg()`
  was dropped for a scalar `vsi = "curl"` default with an explicit check, for independent
  reasons. The failure the review predicted cannot occur.
- **BL-2** (guards must sit above the `Sys.which("ogr2ogr")` check) — already satisfied.
  Ordering is: `chk` → `vsi` validity → `layer` length → `encoding`/`vsi` → query-string →
  PATH → loop.
- **GAP-2** (nothing tests that `vsi` is threaded through `spk_source_url()` itself) — real
  against the plan. The test written is the stubbed end-to-end one the review asks for, and
  the fault injection confirmed it: ignoring `vsi` gives FAIL 3.
- **AC-1** (the cleanup fault row will not go red) — predicted `FAIL 0`; measured `FAIL 1`,
  because a cleanup test was written that the plan did not list.
- **AC-3** (`.spk_source_url_args()` passthrough test is vacuous) — correct, and that test
  was never written; the stubbed threading test replaced it.

## Noted, not acted on

- **SC-3** `tools::file_ext()` returns `""` for a query-string URL, so `encoding` + a query
  URL builds a temp file ending in a bare `.`. **Confirmed by measurement.** Pre-existing,
  unreachable from the new feature, and out of scope — but the docs are careful never to
  offer `encoding` as a workaround for a query-string URL, which is the path that would
  reach it.
- **SC-2** the consumer that motivates the issue lives in another repo, so this branch is a
  precondition rather than the whole outcome. Called out in the PR instead of silently
  claiming the outcome here.
- **SC-1** why not `spk_source_bcdata()` — it takes a catalogue record id rather than a URL,
  requires the GeoPackage to exist, and pushes down a bbox rather than an arbitrary filter.
  Answered in the PR body.
