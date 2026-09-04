# Code check — round 2 (staged diff, #23)

Reviewed against `code-check.md`, `-shell.md`, `-r.md`, `-spatial.md`.
Working tree verified identical to the index before and after every probe (`git diff` empty).

## Clean

No issues found. Every round-1 fix verified correct and complete; nothing new introduced.

Measurements below, since a verdict with no evidence is a claim rather than a check.

---

## 1. Round-1 fix #3 — the `@details` / `\section{}` reorder is correct and complete

`man/spk_source_url.Rd`: `\details{}` now closes at line 1963 (end of the bilingual-column
prose) and `\section{Reading a service endpoint}{}` runs 1964–1992, before `\examples{}`.

- **Nothing left under the wrong heading.** The `Site/Site` / `Year/Année` material — the
  slash-and-accent survival claim and the load-bearing "a downstream SQL `query` must use
  the *file's* name, quoted" — is back inside `\details{}`.
- **Nothing dropped or duplicated.** Section content matches `R/spk_source_url.R:902-931`
  one-for-one; the service-endpoint text appears exactly once in the file.
- **Generated docs are current.** `devtools::document()` re-run: `man/spk_source_url.Rd`
  MD5 unchanged (`926570c8…`), no unexpected `Writing`/`Deleting` lines, `NAMESPACE`
  untouched — so no roxygen block rebound to the wrong object (`code-check-r.md`,
  "Inserting a helper between a roxygen block and its function").
- `@param vsi`'s "See *Reading a service endpoint* below" resolves: `\arguments{}` renders
  above `\details{}`/`\section{}`.
- `tools::Rd2ex()` parses the new example; the three `%` are correctly escaped as `\%`.
- `tools::checkRd()` non-ASCII notes: 6 at HEAD, 10 now. Same pre-existing class (em-dashes
  and `Année`), covered by `Encoding: UTF-8` in DESCRIPTION; standalone `checkRd` cannot see
  it. Not introduced, not a check failure.

## 2. Round-1 fix #1 — `skip_no_sh()` is correct, and no external command is left unguarded

```r
skip_no_sh <- function() {
  testthat::skip_on_os("windows")
  testthat::skip_if(!nzchar(Sys.which("printf")), "printf not on PATH")
}
```

Ordering is right: `skip_on_os()` fires first, so the `printf` PATH probe never gets to
decide the Windows case — which matters because an Rtools `usr/bin` on `PATH` would make
`Sys.which("printf")` non-empty there and let a cmd-quoted vector be compared against an
`sh` round-trip. `skip_on_os()` exists in testthat >= 3.0.0, matching the DESCRIPTION pin.

Both call sites are guarded, immediately:

| line | call | guard |
|---|---|---|
| 204 | `system2("printf", …)` | `skip_no_sh()` at 203 |
| 217 | `system2("printf", …)` | `skip_no_sh()` at 214 |

Suite-wide sweep for external commands (`system2(`, `system(`, `processx`, `Sys.which`)
across `tests/testthat/`: the only other reachers are `ogr2ogr` (all behind
`skip_no_ogr()`) and `test-spk_gdalwarp.R:41` (behind its own `Sys.which` guard at :38).
Nothing unguarded remains.

On Windows the mocked half of `.spk_ogr2ogr shell-quotes every argument` still executes
before the skip — it touches only `tempfile()`, a stubbed `system2` and `unlink()` on a
file that was never created. No error path there.

## 3. `shQuote(args)` in `.spk_ogr2ogr()` — production is right, and right *because* it omits `type`

`R/spk_source_url.R:273` deliberately calls `shQuote(args)` with no `type`. That is the
correct choice, not an oversight: `shQuote()`'s default is `"sh"` except on Windows where it
is `"cmd"`, which is the quoting `system2()` needs on that platform. `system2()` applies the
same platform default to the redirections it appends itself (`stderr = err` →
`2> '<tmp>'`), so the two agree. Pinning `type = "sh"` in production would be the bug.

Measured, cmd branch on the same vector — every element wrapped in `"` (so `&` is protected
under `cmd.exe`):

```
"\"-where\""  "\"code in ('ADMS')\""  "\"/vsicurl_streaming/https://…?service=WFS&count=1\""
```

The tests pin `type = "sh"` only where they round-trip through `sh`, and skip on Windows
anyway. The split between the two is correct.

`.spk_source_url_args()` staying unquoted is fine — nothing else calls it, and every path
into `system2()` goes through `.spk_ogr2ogr()`.

## 4. No assertion that cannot fail — both new guards fault-injected

| injection | result |
|---|---|
| `args = shQuote(args)` → `args = args` in `R/spk_source_url.R:273` | **FAIL 2** — `.spk_ogr2ogr shell-quotes every argument` (round-trip diverges on all six elements) and `an ampersand in a source URL does not silently succeed` (`sh: -c: line 0: syntax error near unexpected token '('`, status 2) |
| `tmp_files <- c(…)` → `on.exit(unlink(source))` back inside the loop | **FAIL 1** — `sum(file.exists(made))` is `2`, not `0`. Reproduces the "2 of 3 leaked" figure exactly |

Restored after each; `git diff` empty.

`premise: shQuote survives shell metacharacters` is now correctly labelled and is still a
real assertion — it fails if base R's quoting stops round-tripping. Its comment names the
guard that covers the fix, so the two will not be confused for one another.

Baseline: `devtools::test()` → `FAIL 0 | WARN 1 | SKIP 2 | PASS 195`. The single WARN is at
`test-spk_stac_calc.R:209`, untouched by this diff. Changed file alone: `PASS 62 | SKIP 0`.

## 5. NEWS.md — every claim measured, all accurate

| claim | measured |
|---|---|
| `system2("echo", args = "a&b")` prints `a`, reports `sh: b: command not found` | ✅ verbatim |
| a `&`-bearing URL ending `count=1` returns **status 0 having written nothing** | ✅ status `0`, empty stderr, no output file — the trailing assignment is the last command in the `&`-separated list |
| a `-where` clause with quotes and spaces dies with a shell syntax error | ✅ status `2`; the emitted string is `'ogr2ogr' -f GPKG … -where code in ('ADMS') … >/dev/null 2> '…'` passed to `sh -c` |
| the 0.3.0 note said `shQuote()` was removed because `system2()` "does not go through a shell" | ✅ quoted verbatim from `NEWS.md` |
| **command injection** — a `;`, backtick or `$()` in a caller-supplied `urls`/`query` would have executed | ✅ substantiated by that same `sh -c` string: the whole command is parsed by `sh`, so nothing about the claim is speculative. The NEWS wording correctly scopes it to config- or catalogue-sourced values |
| `on.exit` leak "measured at 2 of 3" | ✅ reproduced exactly by fault injection |
| `/vsicurl/` HEAD-404 / full-body-200 against BCGW WFS, GDAL 3.13.0 | not re-verified — no test may touch the network; recorded as measured in `findings.md` |

"any URL containing `&`, which is every service endpoint" is mild rhetoric (a single-param
query has no `&`, and a bare `?` survives sh globbing unmatched), but the technical scoping
to `&` is correct and the sentence is not load-bearing.

## 6. Other checks, all clean

- **`.Rbuildignore` carries `^planning$`** — the two new `planning/active/review-*.md` files
  do not ship in the tarball (`code-check-r.md`, "`R CMD build` ships every top-level
  directory").
- **lintr**: 0 lints on `R/spk_source_url.R` and `tests/testthat/test-spk_source_url.R`.
- **`unlink(character(0))`** returns `0` silently — the no-encoding path is a clean no-op.
- **`grepl("?", NA, fixed = TRUE)`** returns `FALSE`, not `NA`, so an `NA` in `urls` cannot
  make the layer guard abort with an `NA` in its message.
- **`shQuote()` double-quote fallback** (fires for the whole vector once any element carries
  a `'`) escapes `" $ \` \`; a vector holding `'`, `$` and a backtick round-trips
  byte-identical through `sh`. Empty strings round-trip; `character(0)` yields
  `character(0)`.
- `https://example.com` → derived layer `example`, as the new section states.

## One observation, not a finding

On `windows-latest` the sole assertion in `.spk_ogr2ogr shell-quotes every argument` sits
*after* `skip_no_sh()`, so that runner contributes no coverage of the quoting fix. The other
four runners do cover it (measured: FAIL 2 on removal), and the production path there uses
cmd quoting, which an `sh` round-trip could not validate anyway. If a platform-independent
guard is ever wanted, `expect_equal(seen, shQuote(raw))` placed before the skip would run
everywhere. Not required; nothing is broken.
