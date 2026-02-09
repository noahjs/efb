# Turbulence Charts (GTG) — Implementation Design
## EFB Product Specification

[← Back to Imagery Module](./imagery.md)

---

## Overview

Add Graphical Turbulence Guidance (GTG) charts to the imagery module. Unlike icing (CIP/FIP) which has simple static "latest" URLs, AWC serves GTG data only through date-stamped model-run URLs that require computing the current model cycle. This document captures the research findings and implementation approach.

---

## 1. Data Source Analysis

### What Works (Icing — for reference)
Icing charts are served as "latest" symlinks at stable URLs:
```
https://aviationweather.gov/data/products/icing/F{HH}_{product}_{level}_{param}.gif
```
- No date math required — always returns the most recent image
- Example: `F03_fip_max_prob.gif` → 200 OK

### What Doesn't Work for Turbulence
- `/data/products/turb/` → **404** (directory does not exist)
- `/data/products/turbulence/` → **403** (directory exists but files return 404)
- No "latest" symlinks exist for GTG products

### How AWC Serves Turbulence Internally

From reverse-engineering the AWC GFA JavaScript application (`app-UKJSieGB.js`, `map-lBx_S2zg.js`), turbulence uses the AWT (Aviation Weather Tiles) system with date-stamped model-run URLs.

**Three GTG model variants:**

| Model | URL Pattern | Round | Offset | Params | Format |
|-------|------------|-------|--------|--------|--------|
| `gtg` | `/data/awt/gtg/{date}/{date}{hour}f{fhr2}_gtg_{level}_{param}_m.png` | 1h | 4h | `mtw`, `cat`, `edp` | PNG |
| `gtg4` | `/data/awt/gtg4/{date}/{date}{hour}f{fhr3}_gtg4_{level}_{param}_m.png` | 1h | 4h | `cit`, `edp`, `mtw`, `cat` | PNG |
| `gtgn` | `/data/awt/gtgn/{date}_{hour}{minute}_F00_gtgn_{level}_{param}.gif` | 15min | 15min | `total` | GIF |

Where:
- `{date}` = `YYYYMMDD`
- `{hour}` = `HH` (model run hour, UTC)
- `{minute}` = `MM` (for gtgn only)
- `{fhr2}` / `{fhr3}` = forecast hour, zero-padded to 2 or 3 digits
- `{level}` = altitude level code (same as icing: `max`, `100`–`300` in flight levels)
- `{param}` = turbulence parameter
- `round` = model run frequency (how often a new cycle starts)
- `offset` = hours after model run time before data is available

**Turbulence parameters:**

| Code | Description | User-Facing Label |
|------|-------------|-------------------|
| `cat` | Clear Air Turbulence | CAT |
| `mtw` | Mountain Wave Turbulence | Mountain Wave |
| `edp` | Eddy Dissipation Parameter | Combined (EDR) |
| `cit` | Convectively Induced Turbulence | Convective |
| `total` | Total (GTG-N analysis only) | Total |

**Altitude levels** (same codes as icing):
`max`, `030`, `060`, `090`, `120`, `150`, `180`, `210`, `240`, `270`, `300`

**Forecast hours:**
- GTG: 0–18h in 1h steps (but >6h rounds to 3h intervals)
- GTG4: 0–18h in 1h steps (but >6h rounds to 3h intervals)
- GTG-N: Analysis only (F00), updated every 15 minutes

### AWC GFA Tab Mapping

The GFA Turbulence tab exposes these product selections:
- **GTG (All/Combined)**: `prodType: "gtg"` → model `gtg`, param `edp`
- **GTG CAT**: `prodType: "gtgcat"` → model `gtg`, param `cat`
- **GTG Mountain Wave**: `prodType: "gtgmw"` → model `gtg`, param `mtw`
- **LLWS (Low Level Wind Shear)**: Separate product, not GTG

---

## 2. Implementation Approach

### Option A: Model Run Discovery (Recommended)

The backend calculates the most recent available model run and constructs the URL.

**Algorithm:**
1. Current UTC time minus `offset` hours = approximate latest run
2. Round down to nearest `round` interval
3. Try fetching the image at that run time
4. If 404, try the previous run (subtract `round` hours)
5. Cache the discovered "current run time" for 15 minutes to avoid repeated discovery

**Backend method:**
```typescript
async getTurbulenceChart(
  param: string,      // 'cat' | 'mtw' | 'edp'
  level: string,      // 'max' | '030' | ... | '300'
  forecastHour: number // 0-18
): Promise<Buffer | null> {
  // Try last few model runs until we find one that works
  const now = new Date();
  for (let offset = 4; offset <= 8; offset++) {
    const runTime = new Date(now.getTime() - offset * 3600000);
    const date = formatDate(runTime);  // YYYYMMDD
    const hour = formatHour(runTime);  // HH
    const fhr = String(forecastHour).padStart(2, '0');

    const url = `${AWC_BASE}/data/awt/gtg/${date}/${date}${hour}f${fhr}_gtg_${level}_${param}_m.png`;
    const buffer = await tryFetch(url);
    if (buffer) return buffer;
  }
  return null;
}
```

**Pros:** Direct image fetch, simple viewer (reuse icing viewer pattern)
**Cons:** Model run discovery adds latency on first request; URL pattern may change

### Option B: WMS Tile Proxy

Proxy the AWC tile layer as map tiles, similar to how the GFA web app renders turbulence.

**Approach:** Backend acts as a WMS/tile proxy, translating requests into the AWT tile format and serving them to a Mapbox/Leaflet tile layer on the client.

**Pros:** Exact same rendering as AWC GFA
**Cons:** Much more complex; need to handle tile math, projection; higher bandwidth

### Option C: Progchart-Style API Discovery

Use the `/api/data/progchart` API pattern (which returns available files/timestamps) to discover current GTG availability.

**Investigation needed:** Check if a similar discovery endpoint exists for GTG products:
- `GET /api/data/turb?...` (not found in OpenAPI spec)
- May need to scrape or reverse-engineer the GFA app's data loading logic

**Pros:** No URL guessing
**Cons:** Endpoint may not exist; adds API dependency

### Recommendation

Start with **Option A** (model run discovery). It's the simplest to implement and follows the same pattern as icing. If the AWT URLs prove unreliable, fall back to Option C.

**Important caveat:** During testing (2026-02-09), AWT URLs for GTG returned 404 for all tested run times over 36 hours. This could indicate:
1. The AWT path structure has changed since the JS was compiled
2. GTG products were temporarily unavailable
3. The URL template requires additional parameters not captured in the JS

**Before implementing, verify** that GTG AWT URLs actually return images by:
- Checking in a browser with the AWC GFA turbulence tab open and inspecting network requests
- This will reveal the exact current URL pattern being used

---

## 3. Frontend Design

### Viewer Widget: `turbulence_viewer.dart`

Mirrors `icing_viewer.dart` with these selectors:

**Forecast hour selector** (bottom): `0HR`, `3HR`, `6HR`, `9HR`, `12HR`, `15HR`, `18HR`

**Altitude level selector** (scrollable row): Same as icing — `MAX`, `3K`, `6K`, `9K`, `12K`, `15K`, `18K`, `21K`, `24K`, `27K`

**Parameter toggle** (bottom): `Combined (EDR)` / `CAT` / `Mountain Wave`

**Valid time label**: Same UTC + local time display as icing

### Catalog Entry

```
TURBULENCE section:
  - Turbulence Forecast  (type: 'turbulence')
```

Single product that opens the viewer with all parameters togglable inline (like icing prob/sev toggle).

### Provider

```dart
class TurbulenceChartParams {
  final String param;       // 'edp', 'cat', 'mtw'
  final String level;       // 'max', '030', etc.
  final int forecastHour;   // 0-18
}

final turbulenceChartProvider = FutureProvider.family<Uint8List?, TurbulenceChartParams>(...);
```

---

## 4. API Design

### Endpoint

```
GET /api/imagery/turbulence/:param?level=max&forecastHour=0
```

- `:param` = `edp` (combined), `cat` (clear air), `mtw` (mountain wave)
- `level` query param, default `max`
- `forecastHour` query param, default `0`
- Response: `image/png`, Cache-Control 1800s

### Backend Service Method

```typescript
async getTurbulenceChart(param: string, level: string, forecastHour: number): Promise<Buffer | null>
```

- Uses model run discovery algorithm (Option A)
- Cache key: `turb:${param}:${level}:${fhr}:${runDate}${runHour}`
- Cache TTL: 30 minutes
- Falls back through last 4-5 model runs on miss

---

## 5. Pre-Implementation Checklist

Before writing code:

- [ ] **Verify AWT URLs work** by inspecting network requests in the AWC GFA turbulence tab in a browser's dev tools. Capture the exact URL pattern for a working image.
- [ ] **Confirm level codes** — icing uses `max`, `010`, `030`, etc. GTG may use different codes (possibly flight levels like `100`, `150`, `200`, `250`, `300` instead of `010`, `030`, etc.)
- [ ] **Test forecast hour availability** — confirm which forecast hours produce images (0, 1, 2, 3... or just 0, 3, 6, 9, 12, 15, 18)
- [ ] **Check if `_m` suffix is required** — the JS shows `_m.png` suffix on GTG URLs (likely means "map" variant)

---

## 6. Implementation Order

1. Verify AWT URLs via browser network inspection (pre-req)
2. Backend: `imagery.service.ts` — add `getTurbulenceChart()` with model run discovery + catalog entry
3. Backend: `imagery.controller.ts` — add `GET /imagery/turbulence/:param`
4. Frontend: `api_client.dart` — add `getTurbulenceChart()`
5. Frontend: `imagery_providers.dart` — add `TurbulenceChartParams` + provider
6. Frontend: Create `turbulence_viewer.dart` (clone icing_viewer, add 3-way param toggle)
7. Frontend: `app_router.dart` — add turbulence route
8. Frontend: `imagery_screen.dart` — handle turbulence type tap + icon

---

## 7. Related Files

| File | Role |
|------|------|
| `api/src/imagery/imagery.service.ts` | Backend service — add getTurbulenceChart() |
| `api/src/imagery/imagery.controller.ts` | API route — add GET /imagery/turbulence/:param |
| `mobile/lib/services/api_client.dart` | API client — add getTurbulenceChart() |
| `mobile/lib/features/imagery/imagery_providers.dart` | Riverpod provider |
| `mobile/lib/features/imagery/widgets/icing_viewer.dart` | Reference implementation (turbulence viewer follows same pattern) |
| `mobile/lib/features/imagery/widgets/turbulence_viewer.dart` | New widget to create |
| `mobile/lib/features/imagery/imagery_screen.dart` | Add turbulence type handling |
| `mobile/lib/core/router/app_router.dart` | Add turbulence route |
