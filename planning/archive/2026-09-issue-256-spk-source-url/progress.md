# Progress — spk_source_url() fixes (rfp#256)

## Session 2026-09-02

- Plan-mode exploration — phases approved by user.
- Created branch `256-spk-source-url-fixes` off main.
- Scaffolded PWF baseline with approved phases.
- Next: Phase 1 — fail loudly.
- Phases 1-6 landed in one branch.
- Test fixture bug caught during Phase 5: `file(open = "wb", encoding = "UTF-16LE")`
  does not re-encode on write, so the first fixture was secretly ASCII and could not
  reach the failure mode. Replaced with `iconv(toRaw = TRUE)` + `writeBin`; verified the
  bytes are null-interleaved before trusting the test.
- Restore-the-bug run three times: drop the status check -> FAIL 3; drop the `-oo`
  expansion -> FAIL 3; reinstate `shQuote(query)` -> FAIL 1. Restored -> PASS 34, 0 skips.
- `devtools::check()` 0 errors / 0 warnings / 1 pre-existing NOTE (`spk_odm.Rd`).
- Next: PR.
