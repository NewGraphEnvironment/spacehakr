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
