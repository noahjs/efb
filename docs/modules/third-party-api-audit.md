# Third-Party API Audit
## Live-Polled External Data Sources

[Back to Core Specification](../EFB_Product_Specification_v1.md)

---

This document catalogs every external third-party API call the EFB backend makes at runtime. The goal is to identify data that is currently fetched live on every user request and should instead be cached server-side in the database (or on disk) before launch, to reduce latency, improve reliability, and avoid rate-limiting.

The mobile app does **not** call any external APIs directly — all external data flows through the NestJS backend.

---

## Summary

| Provider | Live Calls | Current Cache | Launch Priority |
|----------|-----------|---------------|-----------------|
| Aviation Weather Center (AWC) | 12 endpoints | In-memory only (5m–1h TTL) | HIGH — most frequent |
| National Weather Service (NWS) | 2 endpoints | In-memory only (5m–24h TTL) | MEDIUM |
| FAA NOTAM Search | 1 endpoint | In-memory only (30m TTL) | HIGH — slow upstream |
| FAA TFR (tfr.faa.gov) | 3 endpoints | In-memory only (15m TTL) | HIGH — user-facing map |
| Storm Prediction Center (SPC) | 1 endpoint | In-memory only (30m TTL) | LOW |
| Windy (Point Forecast API) | 3 endpoints (point, route, grid) | In-memory (30m TTL) | HIGH — winds aloft |
| Leidos Flight Filing | 5 endpoints | None (real-time) | N/A — must be live |
| FAA Procedures (d-TPP) | 1 endpoint (on-demand) | Disk (per-cycle) | OK as-is |
| FAA NASR / Registry | 2 endpoints | Disk (seed pipeline) | OK as-is |

---

## HIGH-FREQUENCY: Called On Every Map Pan / Airport View

These are the most critical to move to server-side storage. Every map pan or airport detail view triggers these.

### 1. Bulk METARs (Bounding Box)

| | |
|---|---|
| **What** | All current METAR observations within the visible map area |
| **Source** | `GET https://aviationweather.gov/api/data/metar?bbox=...&format=json&hours=3` |
| **Code** | `api/src/weather/weather.service.ts:115` |
| **Trigger** | Map pan/zoom (flight category dots, METAR overlays) |
| **Frequency** | Every map movement (debounced 300ms) |
| **Current cache** | In-memory, 5-min TTL per bbox string |
| **Problem** | Each unique bbox generates a new cache key. Panning by 1 pixel = cache miss. AWC gets hammered. |
| **Recommendation** | Poll AWC every 5 min for full CONUS METARs, store in DB. Serve map queries from DB with spatial index. |

### 2. Single-Station METAR

| | |
|---|---|
| **What** | Current METAR for a specific airport |
| **Source** | `GET https://aviationweather.gov/api/data/metar?ids={ICAO}&format=json&hours=3` |
| **Code** | `api/src/weather/weather.service.ts:61` |
| **Trigger** | Airport detail view, weather briefing |
| **Frequency** | Every airport detail open |
| **Current cache** | In-memory, 5-min TTL keyed by ICAO |
| **Recommendation** | Same as above — if all METARs are in DB, serve from there. |

### 3. TAF Forecast

| | |
|---|---|
| **What** | Terminal Aerodrome Forecast for an airport |
| **Source** | `GET https://aviationweather.gov/api/data/taf?ids={ICAO}&format=json` |
| **Code** | `api/src/weather/weather.service.ts:85` |
| **Trigger** | Airport detail view |
| **Frequency** | Every airport detail open; also searches up to 20 nearby stations as fallback |
| **Current cache** | In-memory, 5-min TTL keyed by ICAO |
| **Recommendation** | Poll AWC every 5 min for all TAFs, store in DB. TAFs are issued every 6h so 5-min refresh is fine. |

### 4. NOTAMs

| | |
|---|---|
| **What** | Active NOTAMs for an airport + 10nm radius |
| **Source** | `POST https://notams.aim.faa.gov/notamSearch/search` (form-urlencoded) |
| **Code** | `api/src/weather/weather.service.ts:587` |
| **Trigger** | Airport detail view |
| **Frequency** | Every airport detail open |
| **Current cache** | In-memory, 30-min TTL keyed by FAA identifier |
| **Problem** | FAA NOTAM API is slow (needs 30s timeout), unreliable, requires browser-like headers. |
| **Recommendation** | Background job to poll NOTAMs for airports in the DB every 30 min. Store in DB. Serve instantly to clients. |

---

## MEDIUM-FREQUENCY: Called On Layer Toggle / Periodic Refresh

### 5. PIREPs (GeoJSON)

| | |
|---|---|
| **What** | Pilot weather reports with location, turbulence, icing |
| **Source** | `GET https://aviationweather.gov/api/data/pirep?format=geojson&bbox=...&age=2` |
| **Code** | `api/src/imagery/imagery.service.ts:474` |
| **Trigger** | PIREPs layer enabled on map |
| **Frequency** | On layer toggle + every bbox change |
| **Current cache** | In-memory, 10-min TTL |
| **Recommendation** | Poll every 5 min for full CONUS, store in DB with PostGIS point geometry. Serve spatial queries from DB. |

### 6. G-AIRMETs (GeoJSON)

| | |
|---|---|
| **What** | Graphical Airmen's Meteorological Information — areas of IFR, turbulence, icing, etc. |
| **Source** | `GET https://aviationweather.gov/api/data/gairmet?format=geojson` |
| **Code** | `api/src/imagery/imagery.service.ts:452` |
| **Trigger** | AIR/SIGMET layer enabled on map |
| **Frequency** | On layer toggle |
| **Current cache** | In-memory, 10-min TTL |
| **Recommendation** | Poll every 10 min, store GeoJSON in DB or Redis. Issued every 3 hours so refresh rate is generous. |

### 7. SIGMETs (GeoJSON)

| | |
|---|---|
| **What** | Significant Meteorological Information — convective, non-convective SIGMETs |
| **Source** | `GET https://aviationweather.gov/api/data/airsigmet?format=geojson` |
| **Code** | `api/src/imagery/imagery.service.ts:452` |
| **Trigger** | AIR/SIGMET layer enabled on map |
| **Frequency** | On layer toggle |
| **Current cache** | In-memory, 10-min TTL |
| **Recommendation** | Same polling strategy as G-AIRMETs. |

### 8. Center Weather Advisories (GeoJSON)

| | |
|---|---|
| **What** | CWAs from CWSU facilities |
| **Source** | `GET https://aviationweather.gov/api/data/cwa?format=geojson` |
| **Code** | `api/src/imagery/imagery.service.ts:452` |
| **Trigger** | AIR/SIGMET layer enabled on map |
| **Frequency** | On layer toggle |
| **Current cache** | In-memory, 10-min TTL |
| **Recommendation** | Same polling strategy as G-AIRMETs. |

### 9. TFR Polygons (WFS)

| | |
|---|---|
| **What** | Temporary Flight Restriction polygon boundaries |
| **Source** | `GET https://tfr.faa.gov/geoserver/TFR/ows?service=WFS&...` |
| **Code** | `api/src/imagery/imagery.service.ts:500` |
| **Trigger** | TFR layer enabled on map |
| **Frequency** | On layer toggle |
| **Current cache** | In-memory, 15-min TTL |
| **Problem** | FAA GeoServer can be slow (30s timeout). |
| **Recommendation** | Poll every 15 min, store polygons in PostGIS. Serve from DB. ~100 active TFRs typically. |

### 10. TFR Metadata List

| | |
|---|---|
| **What** | TFR summary info (notam_id, facility, state, type, description) |
| **Source** | `GET https://tfr.faa.gov/tfrapi/getTfrList` |
| **Code** | `api/src/imagery/imagery.service.ts:514` |
| **Trigger** | TFR layer enabled (parallel with WFS call) |
| **Frequency** | On layer toggle |
| **Current cache** | In-memory, 15-min TTL |
| **Recommendation** | Same polling strategy as TFR polygons. |

### 11. TFR Detail Text (HTML)

| | |
|---|---|
| **What** | Full TFR details (location, altitude, reason, effective dates) |
| **Source** | `GET https://tfr.faa.gov/tfrapi/getWebText?notamId=...` |
| **Code** | `api/src/imagery/imagery.service.ts:550` |
| **Trigger** | TFR detail view / map long-press on TFR |
| **Frequency** | Per TFR, batched 10 at a time |
| **Current cache** | None |
| **Recommendation** | Cache alongside TFR polygon data during background poll. |

### 12. Winds Aloft (Text)

| | |
|---|---|
| **What** | Winds & temperatures at flight levels (6h/12h/24h forecasts) |
| **Source** | `GET https://aviationweather.gov/api/data/windtemp?region=us&level=low&fcst=...` |
| **Code** | `api/src/weather/weather.service.ts:373` |
| **Trigger** | Airport detail view / flight planning |
| **Frequency** | Per airport, searches up to 50 nearby stations as fallback |
| **Current cache** | In-memory, 1-hour TTL per forecast period |
| **Recommendation** | Poll every hour, parse all stations, store in DB. Issued every 6 hours so hourly is fine. Also query `level=high` for FL240–FL530 winds. |

### 13. Windy Point Forecast API (Winds Aloft — All Altitudes)

| | |
|---|---|
| **What** | Wind direction/speed at 14 pressure levels (surface through FL440) for any lat/lon coordinate. Replaces/supplements AWC windtemp for route-level wind calculations and map wind overlay. |
| **Source** | `POST https://api.windy.com/api/point-forecast/v2` |
| **Code** | `api/src/windy/windy.service.ts` (new module) |
| **Trigger** | Flight planning (route wind calculation), altitude picker, winds aloft map overlay |
| **Frequency** | Per route calculation (~5-10 calls per flight plan); per map viewport for wind grid overlay |
| **Auth** | API key via `WINDY_API_KEY` env var |
| **Current cache** | In-memory, 30-min TTL per coordinate |
| **Pricing** | Free tier: 500 calls/day (randomized data, testing only). Professional: €990/year, 10,000 calls/day. |
| **Data format** | JSON with U/V wind component arrays per pressure level per timestamp. Converted to direction/speed in knots. |
| **Pressure levels** | surface, 1000h, 950h, 925h, 900h (~3,200ft), 850h (~5,000ft), 800h (~6,200ft), 700h (~10,000ft), 600h (~14,000ft), 500h (~FL180), 400h (~FL240), 300h (~FL300), 200h (~FL390), 150h (~FL440) |
| **Models** | `namConus` (US high-res, default), `gfs` (global fallback) |
| **Recommendation** | Cache aggressively (30 min). Limit grid queries to ~1° spacing. Use for route wind correction (groundspeed, fuel burn, ETE) and map wind barb overlay. |

---

## LOW-FREQUENCY: Imagery / Charts (Binary Files)

These serve static image files that change infrequently. Current caching is adequate but could be improved with disk caching for multi-instance deploys.

### 13. GFA Panels (PNG)

| | |
|---|---|
| **What** | Graphical Aviation Forecast — clouds/surface panels by region and forecast hour |
| **Source** | `GET https://aviationweather.gov/data/products/gfa/F{HH}_gfa_{type}_{region}.png` |
| **Code** | `api/src/imagery/imagery.service.ts:272` |
| **Current cache** | In-memory, 30-min TTL |
| **Recommendation** | Move to disk/S3 cache. ~120 image combinations (10 regions x 2 types x 6 hours). |

### 14. Prognostic Charts (GIF)

| | |
|---|---|
| **What** | Surface analysis and low-level prognostic charts |
| **Source** | `GET https://aviationweather.gov/data/products/progs/{filename}` |
| **Code** | `api/src/imagery/imagery.service.ts:304` |
| **Current cache** | In-memory, 30-min TTL |
| **Recommendation** | Move to disk/S3 cache. |

### 15. Icing Charts (GIF)

| | |
|---|---|
| **What** | Current Icing Probability & Forecast Icing Potential |
| **Source** | `GET https://aviationweather.gov/data/products/icing/F{HH}_{product}_{level}_{param}.gif` |
| **Code** | `api/src/imagery/imagery.service.ts:337` |
| **Current cache** | In-memory, 30-min TTL |
| **Recommendation** | Move to disk/S3 cache. |

### 16. Winds Aloft Charts (GIF)

| | |
|---|---|
| **What** | High-altitude wind/temperature charts |
| **Source** | `GET https://aviationweather.gov/data/products/fax/F{HH}_wind_{level}_{area}.gif` |
| **Code** | `api/src/imagery/imagery.service.ts:368` |
| **Current cache** | In-memory, 1-hour TTL |
| **Recommendation** | Move to disk/S3 cache. |

### 17. Convective Outlook (GIF)

| | |
|---|---|
| **What** | SPC Day 1-3 convective outlook products |
| **Source** | `GET https://www.spc.noaa.gov/products/outlook/{filename}` |
| **Code** | `api/src/imagery/imagery.service.ts:407` |
| **Current cache** | In-memory, 30-min TTL |
| **Recommendation** | Move to disk/S3 cache. |

---

## NWS FORECAST: Per-Airport

### 18. NWS Grid Point Lookup

| | |
|---|---|
| **What** | Maps lat/lon to NWS forecast grid coordinates |
| **Source** | `GET https://api.weather.gov/points/{lat},{lon}` |
| **Code** | `api/src/weather/weather.service.ts:654` |
| **Current cache** | In-memory, 24-hour TTL |
| **Recommendation** | Store grid mappings in DB. Grid points are static — cache permanently per airport. |

### 19. NWS 7-Day Forecast

| | |
|---|---|
| **What** | Standard 7-day weather forecast for an airport's location |
| **Source** | `GET https://api.weather.gov/gridpoints/{gridId}/{gridX},{gridY}/forecast` |
| **Code** | `api/src/weather/weather.service.ts:229` |
| **Current cache** | In-memory, 5-min TTL |
| **Recommendation** | Cache in DB with 30-min TTL. NWS forecasts update every 1-2 hours. |

---

## REAL-TIME / NO CACHE NEEDED

These are transactional or one-time operations that must remain live.

### 20–24. Leidos Flight Plan Filing

| Endpoint | URL |
|----------|-----|
| File | `POST https://lmfsweb.afss.com/Website/rest/flightplan/file` |
| Amend | `POST https://lmfsweb.afss.com/Website/rest/flightplan/amend` |
| Cancel | `POST https://lmfsweb.afss.com/Website/rest/flightplan/cancel` |
| Close | `POST https://lmfsweb.afss.com/Website/rest/flightplan/close` |
| Status | `GET https://lmfsweb.afss.com/Website/rest/flightplan/status` |

**Code:** `api/src/filing/leidos.service.ts`
**Auth:** HTTP Basic Auth (vendor credentials from env vars)
**Mock:** Default mock service active unless `FILING_USE_MOCK=false`

No caching needed — these are real-time transactional operations.

---

## ALREADY CACHED ON DISK (Seed Pipeline)

These run as admin jobs, not live user requests. No changes needed.

| Data | Source | Storage |
|------|--------|---------|
| FAA NASR (airports, navaids, fixes, airways) | `nfdc.faa.gov/webContent/28DaySub/...` | PostgreSQL (seeded) |
| FAA Aircraft Registry | `registry.faa.gov/database/ReleasableAircraft.zip` | PostgreSQL (seeded) |
| FAA d-TPP Procedure Metadata | `aeronav.faa.gov/d-tpp/{cycle}/xml_data/...` | PostgreSQL (seeded) |
| Procedure PDFs | `aeronav.faa.gov/d-tpp/{cycle}/{pdf}` | Disk (on-demand download, cached per cycle) |

---

## AWC API Limits (Tested Feb 2026)

The Aviation Weather Center API has a **hard cap of 400 results** per request for METARs and PIREPs. This means you cannot pull all ~2,550 US METAR stations in a single call. TAFs, G-AIRMETs, SIGMETs, and CWAs do NOT have this cap.

| Data Type | CONUS Count | Cap? | Single-Call? |
|-----------|-------------|------|-------------|
| METARs | ~2,550 stations | 400/request | No — need tiled bbox requests |
| TAFs | ~750 stations | No cap observed | Yes — single CONUS bbox works |
| PIREPs | Varies (~200-500 active) | 400/request | Usually yes, may need tiling during busy periods |
| G-AIRMETs | ~40-60 features | No cap | Yes |
| SIGMETs | ~0-10 features | No cap | Yes |
| CWAs | ~0-5 features | No cap | Yes |
| TFRs | ~50-100 features | 300 maxFeatures (configurable) | Yes |

### METAR Polling Strategy: Per-State with Station IDs

The AWC API accepts comma-separated station IDs via the `ids` parameter (e.g. `?ids=KDEN,KAPA,KBJC`). This lets us **query by state** using the ICAO identifiers already in our airports DB — no bbox tiling needed.

**Why per-state is better than bbox tiling:**
- Deterministic — each call always fetches the same stations
- Debuggable — if a state fails, you know exactly which one and can retry
- No cap issues — the largest state (AK, 239 stations) is well under the 400 limit
- No missed stations — bbox tiling can miss edge cases; IDs are explicit

**Station counts by state (top 10):**

| State | ICAO Stations | URL Length |
|-------|--------------|------------|
| AK | 239 | 1,194 chars |
| TX | 184 | 919 chars |
| CA | 156 | 779 chars |
| FL | 100 | 499 chars |
| MN | 95 | 474 chars |
| GA | 79 | 394 chars |
| IA | 75 | 374 chars |
| MI | 72 | 359 chars |
| NC | 71 | 354 chars |
| WI | 67 | ~335 chars |

All 58 states/territories are under the 400 cap. All URL lengths are under 1,500 chars (safe for query strings). The 11 smallest entries (DC, DE, RI, VT, PR, VI, GU, AS, MP, and 2 misc) have <10 stations each and can be bundled into a single call.

```
Polling load (5-min refresh):
  - 47 main state calls + 1 bundled small territories = 48 calls per refresh
  - Calls per day:      ~13,800
  - Data per refresh:   ~900 KB (~2,590 stations x ~350 bytes each)
  - Bandwidth per day:  ~250 MB
  - All calls can run in parallel
```

**Station list source:** The `airports` table in PostgreSQL, filtered to rows with a non-null `icao_identifier`. This list is static between NASR 28-day seed cycles, so it can be loaded once at poller startup.

**Note:** Not every ICAO airport in the DB has an active METAR — of TX's 184 ICAO airports, ~165 returned observations. The API simply returns nothing for stations without current data, so extra IDs are harmless.

---

## Launch Recommendations

### Phase 1: Background Polling Jobs (Biggest Impact)

Create background cron jobs that poll and store data server-side. Clients query our DB instead of proxying to third parties.

| Job | Source | Bulk Strategy | Interval | Calls/Day | Storage |
|-----|--------|--------------|----------|-----------|---------|
| METAR Poller | AWC `/metar` | 48 calls by state (IDs from DB) | Every 5 min | ~13,800 | `metars` table with lat/lon index |
| TAF Poller | AWC `/taf` | 1 CONUS bbox (no cap) | Every 5 min | 288 | `tafs` table |
| PIREP Poller | AWC `/pirep` | 1 CONUS bbox (usually under cap) | Every 5 min | 288 | `pireps` table with lat/lon index |
| Advisory Poller | AWC `/gairmet` + `/airsigmet` + `/cwa` | 3 calls, no bbox needed | Every 10 min | 432 | `advisories` table with GeoJSON geometry |
| TFR Poller | FAA WFS + `/getTfrList` + `/getWebText` | 2 calls + batch detail | Every 15 min | ~200 | `tfrs` table with GeoJSON geometry |
| Winds Aloft Poller | AWC `/windtemp` | 3 calls (6h/12h/24h forecasts) | Every 1 hour | 72 | `winds_aloft` table |
| NOTAM Poller | FAA NOTAM API | Per-airport POST (slow, 30s timeout) | Every 30 min | Scales with airports | `notams` table |

**Total estimated API calls per day: ~15,000** (mostly METARs)

**NOTAM caveat:** The FAA NOTAM API does not support bulk/bbox queries — it requires one POST per airport identifier. Polling all ~2,700 ICAO airports every 30 min = ~130K calls/day with 30s timeouts. Options:
1. Only poll NOTAMs for airports the user is actively viewing (current approach)
2. Poll a curated list of ~500 major airports on a schedule, fetch others on-demand
3. Wait for a better FAA NOTAM API (the current one is notoriously unreliable)

### Phase 2: Disk/S3 Cache for Images

Move binary chart images from in-memory to disk or S3 with appropriate TTLs. ~120 GFA images, ~20 prog charts, ~50 icing charts.

### Phase 3: NWS Grid Caching

Pre-compute and store NWS grid point mappings for all ~2,700 ICAO airports in the DB (grid points are static, only need to compute once). Cache forecasts with 30-min TTL.
