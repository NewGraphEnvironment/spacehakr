# Findings — spk_source_url() virtual filesystem selection (#23)

## Issue context

## Problem

`spk_source_url()` reads every streaming source through `/vsicurl/`
(`.spk_source_resolve()` returns `paste0("/vsicurl/", url)` unless `encoding` is
supplied). That works for a URL ending in a recognisable file, and fails for a **service
endpoint with a query string** — which is how a WFS `GetFeature` request is addressed.

Measured 2026-09-04, GDAL 3.13.3 on macOS, against a BC Geographic Warehouse WFS
returning GeoJSON:

```
ogr2ogr -f GPKG out.gpkg "/vsicurl/https://openmaps.gov.bc.ca/geo/pub/<LAYER>/ows?service=WFS&version=2.0.0&request=GetFeature&typeName=pub%3A<LAYER>&outputFormat=application%2Fjson&srsName=EPSG%3A3005&CQL_FILTER=..."
#> ERROR 1: Unable to open datasource `/vsicurl/https://...' with the following drivers.
```

The same URL fetches fine over plain HTTP — `curl` returns HTTP 200 and 143,569 bytes of
valid GeoJSON, 1 feature — so the request is correct and the failure is in how GDAL is
asked to open it.

## What actually fixes it

Only the streaming virtual filesystem:

| attempt | result |
|---|---|
| `/vsicurl/<url>` | `ERROR 1: Unable to open datasource` |
| `/vsicurl/<url>` + `-if GeoJSON` | same error — forcing the input driver does **not** help |
| `GeoJSON:/vsicurl/<url>` | same error |
| **`/vsicurl_streaming/<url>`** | **works — Feature Count: 1** |

`/vsicurl/` wants range requests and a sniffable extension; this endpoint sends
`cache-control: private, no-store` and has no extension, so the probe fails.
`/vsicurl_streaming/` reads sequentially and does not need either.

## Why the existing escape hatch does not cover it

`encoding` is the only argument that avoids `/vsicurl/` — supplying it downloads to a
temp file first. But encoding is a statement about the source's character set, not about
its transport. Setting a bogus encoding to force a download would be a lie in config that
the next reader has to decode.

## Proposed solution

An explicit way to choose the virtual filesystem, defaulting to today's behaviour so
nothing changes for existing callers. Either:

1. a `vsi` argument (`"curl"` default, `"curl_streaming"`), or
2. auto-select `/vsicurl_streaming/` when the URL carries a query string, since that is
   the case `/vsicurl/` reliably cannot open

(1) is the smaller, more honest change — (2) infers intent from URL shape and would
surprise someone whose query-string URL works fine today.

## Context

Found while wiring `spk_source_url()` into a config-driven layer catalog, where a source
is described by a row rather than by arguments. Sources that supply `encoding` work today,
because that path downloads to a temp file first and never touches `/vsicurl/`. A WFS
endpoint has no encoding to declare, so it takes the streaming path and cannot be
expressed at all until this lands.




## Premise confirmed independently (2026-09-04, GDAL 3.13.0, macOS)

The issue measured this on GDAL 3.13.3. Re-measured here on 3.13.0 against a different
BCGW layer, so the result is not specific to one layer or one patch release.

URL: `https://openmaps.gov.bc.ca/geo/pub/WHSE_BASEMAPPING.FWA_WATERSHED_GROUPS_POLY/ows?service=WFS&version=2.0.0&request=GetFeature&typeName=pub%3A...&outputFormat=application%2Fjson&srsName=EPSG%3A3005&count=1`

| attempt | exit | result |
|---|---|---|
| plain `curl` (positive control) | 0 | HTTP 200, 417,978 bytes of valid GeoJSON |
| `ogr2ogr /vsicurl/<url>` | **1** | `ERROR 1: Unable to open datasource`, no file written |
| `ogr2ogr /vsicurl_streaming/<url>` | **0** | clean stderr, Feature Count 1, Multi Polygon |

The positive control matters: without it, the `/vsicurl/` failure is indistinguishable
from a dead endpoint or a malformed URL.

### Why `/vsicurl/` fails — the issue's stated cause is not what is happening

The issue attributes it to `cache-control: private, no-store`. That header is **not
present** on this endpoint's response. Measured instead:

```
curl -sI  <url>   ->  404          # HEAD is not answered at all
curl -s -H "Range: bytes=0-99" <url>
                  ->  200, 417978 bytes   # Range ignored; not a 206
```

So `/vsicurl/` fails because its probe is a `HEAD` the server 404s, and its range requests
come back as full-body 200s rather than 206 partial content. `/vsicurl_streaming/` issues a
single sequential `GET` and needs neither.

This does not change the fix — `/vsicurl_streaming/` is still the answer — but it changes
what to tell someone deciding whether they need it. The predicate is "the endpoint does not
support HEAD or range requests", which is a property of service endpoints generally, not of
one cache header. Issue body updated to match.

## Layer-name defect reproduced live

The successful `/vsicurl_streaming/` run wrote its layer as:

```
ows?service=WFS&version=2.0.0&request=GetFeature&typeName=pub%3AWHSE_BASEMAPPING
```

GDAL derives that from the URL and truncates it. `spk_source_url()`'s own default
(`tools::file_path_sans_ext(basename(url))`) is worse — it keeps the entire query string,
measured:

```r
basename(u)
#> "ows?service=WFS&version=2.0.0&request=GetFeature&typeName=pub%3AWHSE_X&outputFormat=application%2Fjson&srsName=EPSG%3A3005"
```

This is not hypothetical and it is created by the feature being added, which is why the
Phase 3 guard is in scope rather than deferred.

## `system2()` does go through a shell — found by the live end-to-end check

The unit tests, the argument-builder tests and the raw `ogr2ogr` controls all passed while
`spk_source_url()` was **silently broken for the exact URL shape this issue is about**.
Running the finished function against the live endpoint is what exposed it:

```
default vsi   -> "returned normally", and the GeoPackage did not exist
```

`system2(command, args)` pastes `args` into a command string and runs it through `sh`,
shell-quoting only `command`. Measured:

```r
system2("echo", args = "a&b")
#> a
#> sh: b: command not found
```

So a WFS URL is split at every `&`. The fragments run as separate commands, and the last
one — `count=1` — is a variable assignment, which succeeds. `system2()` returns **0**, the
abort added in 0.3.0 never fires, and no file is written.

| case | status | file written | rows |
|---|---|---|---|
| `-where` raw (0.3.0 behaviour) | 2 | no | — |
| `-where` shell-quoted | 0 | yes | 1 |
| URL with `&` raw | **0** | **no** | — |
| URL with `&` shell-quoted | 0 | yes | 1 |

Two things follow.

**The v0.3.0 conclusion was wrong.** Its archive README records removing `shQuote(query)`
because "`system2()` with an argument vector does not go through a shell, so the quotes
were reaching `-where` literally". The comment asserting this sat in the code and was
carried into a test name. `-where` has been broken since — loudly, so it was survivable,
but the reasoning was inverted.

**`shQuote()` is safe here, measured rather than assumed.** It single-quotes normally and
switches the whole vector to double-quoting as soon as any element contains a single
quote, escaping `$` and backticks in that branch. A string carrying a single quote, `$`
and a backtick at once round-trips byte-identical. The test asserts that round-trip rather
than a quoting style, because the style is an implementation detail and the survival of
the bytes is the property.

Quoting is applied in `.spk_ogr2ogr()` rather than in `.spk_source_url_args()`, so the
argument vector stays comparable by equality in tests.

## Live end-to-end, after the fix

```
default vsi        -> aborted: ogr2ogr failed for <url>
vsi=curl_streaming -> layer "watershed_groups", 1 feature, EPSG 3005, MULTIPOLYGON,
                      0 empty geometries
layer omitted      -> aborted: `layer` is required when a URL carries a query string.
```
