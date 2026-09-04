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



