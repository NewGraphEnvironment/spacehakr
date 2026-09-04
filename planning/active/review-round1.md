# Code check — round 1 (staged diff, #23)

Reviewed against `code-check.md`, `-shell.md`, `-r.md`, `-spatial.md`.
Local run of the changed test file: `FAIL 0 | WARN 0 | SKIP 0 | PASS 62`.

## Findings

### 1. **[bug]** `tests/testthat/test-spk_source_url.R:193`, `:202` — two new tests shell out to `printf` with no skip guard, on a matrix that includes `windows-latest`

```r
round_tripped <- system2("printf", c(shQuote("%s\n"), seen), stdout = TRUE)   # :193
system2("printf", c(shQuote("%s\n"), shQuote(nasty)), stdout = TRUE)          # :202
```

`.github/workflows/R-CMD-check.yaml` runs `{os: windows-latest, r: 'release'}`. Two
independent problems there, one certain and one likely:

- **Certain.** `shQuote()` is called with no `type`, and its first line is
  `if (missing(type) && .Platform$OS.type == "windows") type <- "cmd"`. So on the Windows
  runner both the code under test (`R/spk_source_url.R:273`) and the test's own round-trip
  produce **cmd-style** quoting, not `sh`. The test is named *"`.spk_ogr2ogr` shell-quotes
  every argument"* and its comment documents `sh` semantics; on that runner it asserts a
  different quoting scheme round-tripped through a different parser. It is not testing what
  it says it is.
- **Likely.** `printf` is not a Windows command; it exists only if an msys/Rtools `usr/bin`
  happens to be on `PATH`. Measured: `system2(<missing command>, stdout = TRUE)` **errors**
  — `Error: error in running command` — it does not warn and does not return empty. So an
  absent `printf` is an `R CMD check` failure on that runner, not a skip.

This is the only unguarded external-command dependency in the suite. Every other CLI test
in the package is guarded: `skip_no_ogr()` here, and
`test-spk_gdalwarp.R:38` (`skip_if(!nzchar(Sys.which("gdalwarp")))`). These two are the
exception.

Fix: add `testthat::skip_on_os("windows")` (or `skip_if(!nzchar(Sys.which("printf")))`) to
both, and pin the quoting scheme the test claims by asserting against
`shQuote(x, type = "sh")` explicitly rather than the platform default.

### 2. **[fragile]** `tests/testthat/test-spk_source_url.R:212-213` — the stale comment that caused the bug is still in the tree

```r
testthat::test_that(".spk_source_url_args passes query to -where unquoted", {
  ...
  # system2() with an args vector does not go through a shell, so shQuote()ing here
  # would reach ogr2ogr literally
```

This is verbatim the inverted reasoning that `NEWS.md`, `findings.md`, and the new roxygen
in `.spk_ogr2ogr()` all now say produced a silent failure. The diff corrected the same
sentence in `R/spk_source_url.R:385-386` and in the roxygen but left this copy behind.

It matters because it is the comment a future reader hits while looking at the `-where`
argument — the exact place from which `shQuote()` was removed in 0.3.0. Replace it with the
measured statement (`system2()` does go through `sh`; quoting happens in `.spk_ogr2ogr()`).

### 3. **[fragile]** `man/spk_source_url.Rd` — the new `# Reading a service endpoint` heading swallowed two unrelated paragraphs

The markdown heading was inserted in the **middle** of `@details`, so roxygen closed
`\details{}` at that point and everything after it fell into the new section. Verified in
the generated Rd: the bilingual-column-headers material — `Site/Site`, `Year/Année`, GDAL
field-name survival, `sf::st_read()` name mangling — now renders under
*"Reading a service endpoint"*.

None of that prose is about reading a service endpoint, and one of its claims (the file's
field name vs. the session's, and that a downstream SQL `query` must use the file's name)
is load-bearing enough that filing it under the wrong heading loses it.

Fix: move the `# Reading a service endpoint` block to the **end** of `@details`, or give the
trailing prose its own heading.

### 4. **[vacuous]** `tests/testthat/test-spk_source_url.R:199-206` — "shell metacharacters survive quoting" tests base R, not the package

It calls `shQuote()` and `system2()` directly and touches no spacehakr function. It passes
identically whether or not `.spk_ogr2ogr()` quotes anything — remove the `shQuote()` from
`R/spk_source_url.R:273` and this test stays green.

That is legitimate as a *premise* assertion about base R (and worth keeping), but its name
reads as coverage of the fix and it is not. The real guard is
`.spk_ogr2ogr shell-quotes every argument` at `:167`. Worth one comment saying which is
which, so the next person does not delete the guard and keep the premise.

## Checked and clean — the four items raised in the brief

**`shQuote(args)` is correct and complete.** Nothing reaches the shell unquoted. `system2()`
appends its own redirections *after* the args and `shQuote`s their targets itself
(`stdout = FALSE` → `>/dev/null`, `stderr = err` → `2> '<tmp>'`), so the `err` path is
covered. Measured round-trip through `sh` of a vector holding `'`, `$`, backtick, `"` and
`\`: byte-identical. The double-quote fallback branch — which fires for the **whole vector**
as soon as any one element contains `'`, exactly as the test comment says — escapes
`" $ ` \`, and `!` is inert because `system()` runs a non-interactive `sh -c`. Zero-length
and empty-string elements both round-trip.

**`tmp_files` accumulation is correct on every path.** Ordering in the loop is
resolve → accumulate → invoke, so an abort inside `.spk_ogr2ogr()` on URL *n* still has
URLs 1..*n* registered. Nothing is created before the registration point, so there is no
window. Nothing is added unless `encoding` is non-`NULL`, which is precisely the branch
whose resolver returns a `tempfile()` — so `unlink()` can never be handed a `/vsi…` path.
`unlink(character(0))` returns 0 silently (measured), so the no-encoding case is a clean
no-op. A mid-loop failure inside `.spk_source_resolve()` is covered by that function's own
`on.exit(unlink(raw_file))`.

**The query-string guard's predicate is right.** `grepl("?", urls, fixed = TRUE)` is a
literal match, not a regex quantifier. It is scoped to `is.null(layer)`, evaluated over
**all** urls before the loop and before the `Sys.which("ogr2ogr")` check, so it cannot abort
after a layer has already been written — and `the layer guard fires before any ogr2ogr runs`
pins that. I could not construct a false abort: any URL carrying `?` yields a junk derived
name, so refusing it is right in every case, not just the WFS one.

**The `encoding` / `vsi` exclusion is correct.** `!identical(vsi, "curl")` is safe because
`chk::chk_string(vsi)` and the explicit membership check both run first, so by that line
`vsi` is a length-1, non-`NA` character in `{"curl", "curl_streaming"}`. The Plan review's
BL-1 (a length-2 unmatched `match.arg()` default aborting every `encoding =` caller) cannot
occur against this code, and `spk_source_url allows encoding with the default vsi` pins the
non-firing direction.

Two further notes, neither a finding:

- The pre-fix code was a **command-injection** vector, not merely a correctness bug: a URL
  or `query` reaching `sh` unquoted would execute `;`/`` ` ``/`$()` in caller-supplied text.
  `shQuote()` closes it. Worth stating in the PR body — it is the strongest argument for the
  change and NEWS currently frames it only as a silent failure.
- Every `skip_no_ogr()` test — including `an ampersand in a source URL does not silently
  succeed`, the end-to-end proof of the fix — will almost certainly skip on all five
  runners, since `sf`'s system requirements pull `libgdal-dev`, which does not ship the
  `ogr2ogr` binary (`gdal-bin` does). That is the accepted tradeoff and it is correctly
  mitigated by the mock-based twin at `:167`, which does run. Flagging only so the skip
  count is not read as coverage.

`NEWS.md` claims spot-checked and accurate: `system2()` does go through `sh` (measured —
a missing command reports `sh: <cmd>: command not found`); the `-where` regression dates
from 0.3.0's removal of `shQuote(query)`, and the pre-0.3.0 form did work; the `%` in the
new `@examples` WFS URL is correctly escaped as `\%` in the generated Rd.
