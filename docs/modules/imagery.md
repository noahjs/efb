# Imagery Module
## EFB Product Specification

[← Back to Core Specification](../EFB_Product_Specification_v1.md)

---

The Imagery module provides a browseable catalog of weather graphics and FAA terminal procedure plates. It gives pilots quick access to the full suite of NWS/AWC weather products (prog charts, icing, turbulence, satellite, radar, etc.) and FAA-published instrument approach plates, departure procedures, arrival procedures, and airport diagrams. This module is scoped to the USA (including Alaska and Pacific territories).

## Priority

**P0 — Core.** Weather imagery is essential for preflight planning and in-flight weather assessment. Plates are required for IFR operations.

## User Stories

### Weather Imagery
- As a pilot, I want to view current prog charts and surface analysis so I can understand the big-picture weather.
- As a pilot, I want to see convective outlooks and forecasts so I can plan around thunderstorm activity.
- As a pilot, I want to view icing and turbulence products at specific altitude bands so I can choose a safe cruise altitude.
- As a pilot, I want to view winds aloft graphics so I can pick the most fuel-efficient altitude.
- As a pilot, I want animated radar and satellite loops so I can see weather trends and movement.
- As a pilot, I want to browse graphical AIRMETs, SIGMETs, and CWAs so I can identify advisory areas.
- As a pilot, I want to view plotted PIREPs so I can see what other pilots are reporting.
- As a pilot, I want to see active TFRs on a map so I can avoid restricted airspace.
- As a pilot, I want to favorite frequently-used products so I can access them quickly.
- As a pilot, I want to view recent products so I can return to what I was just looking at.

### Skew-T / Route Weather Profile
- As a pilot, I want to view a Skew-T diagram for my departure and destination airports so I can understand the vertical atmospheric profile (cloud layers, freezing level, inversions).
- As a pilot, I want to see Skew-T soundings at multiple points along my planned route so I can identify hazards at my cruise altitude.
- As a pilot, I want a route weather cross-section showing cloud layers, freezing level, and turbulence potential along my flight path so I can pick the best altitude.

### Plates (Terminal Procedures)
- As a pilot, I want to view approach plates for my destination airport so I can brief the approach.
- As a pilot, I want to view SID and STAR charts so I can understand my departure and arrival routing.
- As a pilot, I want to view airport diagrams so I can navigate on the ground.
- As a pilot, I want to pinch-zoom and pan on plates for readability in the cockpit.
- As a pilot, I want to access plates from the airport details screen for quick reference.
- As a pilot, I want to geo-reference approach plates on the map so I can see my position relative to the procedure.

---

## 1. Navigation

Imagery occupies the **4th tab** in the bottom navigation bar.

**Bottom Nav Order:**
1. Airports
2. Maps
3. Flights
4. **Imagery** (icon: chart/graph line — matching ForeFlight's imagery icon)
5. More

ScratchPads moves to the More screen.

**Routes:**
- `/imagery` — Weather imagery catalog (default: USA product list)
- `/imagery/product/:productId` — Individual weather product viewer
- `/imagery/favorites` — Favorited products
- `/imagery/recents` — Recently viewed products
- `/imagery/skewt` — Airport Skew-T viewer (search/select location)
- `/imagery/skewt/route` — Route Skew-T profile (requires active flight plan)
- `/imagery/route-xsection` — Route weather cross-section (requires active flight plan)
- `/imagery/plates/:airportId` — Plates list for an airport
- `/imagery/plates/:airportId/:plateId` — Individual plate viewer

---

## 2. Screens — Weather Imagery

### 2.1 Product Catalog Screen (`/imagery`)

The primary screen displays a sectioned list of weather products for the USA.

**App Bar:**
- Title: "Imagery" (center)
- Favorites/Recents toggle button (top-right) — star icon with clock, toggles between favorites and recents lists

**Segmented Control** (below app bar):
- **Weather** | **Plates**
- Selects between weather imagery catalog and plates airport search

**Product List (Weather selected):**

Scrollable list organized by section headers. Each row shows the product name with a chevron for drill-in. Tapping a row opens the product viewer.

#### Sections and Products

**NATIONAL**

| Product | Data Source | Description |
|---------|------------|-------------|
| Featured | AWC curated | Curated highlights — surface analysis, current radar, satellite |

**CONUS WEATHER**

| Product | Data Source | Description |
|---------|------------|-------------|
| Prog Charts | WPC via AWC `/graphics/` | Surface analysis + prognostic charts (6, 12, 18, 24, 30, 36, 48, 60 HR, Day 3-7) |
| 6 HR Qty of Precipitation | WPC/NDFD | 6-hour quantitative precipitation forecast |
| 12 HR Prob of Precipitation | WPC/NDFD | 12-hour probability of precipitation |
| Outlook (SIGWX) | AWC SigWx Low Level | Significant weather chart, SFC–FL240 CONUS |
| Convective Outlooks | SPC MapServer (GeoJSON) | SPC categorical convective outlook (Day 1, 2, 3) with tornado/hail/wind probabilities |
| SPC Mesoscale Discussions | SPC MapServer (GeoJSON) | Active mesoscale discussions — short-term severe weather focus areas |
| 4-8 HR Convective Fcst | AWC `/api/data/tcf?format=geojson` | 4–8 hour convective forecast polygons |
| 10-30 HR Convective Fcst | AWC TCF/ETCF | 10–30 hour extended convective forecast graphic |

**GRAPHICAL AVIATION FORECASTS (GFA)**

Cloud and surface forecast panels for CONUS and 9 regional areas. Each item opens a time-series viewer with forecast hours (3, 6, 9, 12, 15, 18 HR).

| Product | Region Code | Data Source |
|---------|-------------|-------------|
| CONUS Cloud | `us` | AWC GFA PNG: `F{HH}_gfa_clouds_us.png` (verified working) |
| CONUS Surface | `us` | AWC GFA PNG: `F{HH}_gfa_sfc_us.png` (verified working) |
| Northeast Cloud / Surface | `ne` | AWC GFA PNG |
| East Cloud / Surface | `e` | AWC GFA PNG |
| Southeast Cloud / Surface | `se` | AWC GFA PNG |
| North Central Cloud / Surface | `nc` | AWC GFA PNG |
| Central Cloud / Surface | `c` | AWC GFA PNG |
| South Central Cloud / Surface | `sc` | AWC GFA PNG |
| Northwest Cloud / Surface | `nw` | AWC GFA PNG |
| West Cloud / Surface | `w` | AWC GFA PNG |
| Southwest Cloud / Surface | `sw` | AWC GFA PNG |

**WINDS ALOFT**

| Product | Altitude Band | Data Source |
|---------|---------------|-------------|
| Surface (10 m AGL) | Surface | AWC fax charts (`/data/products/fax/`) |
| 1,000 ft – 3,000 ft | Low | AWC fax charts |
| 6,000 ft – 14,000 ft | Mid | AWC fax charts |
| FL180 – FL300 | High | AWC fax charts |
| FL340 – FL520 | Very High | AWC fax charts |

**ADVISORIES**

| Product | Data Source | Description |
|---------|------------|-------------|
| Graphical AIRMETs | AWC `/api/data/gairmet?format=geojson` | G-AIRMET polygons (Sierra/Tango/Zulu) plotted on map. Verified: returns ~33 features with IFR, MTN_OBSC, TURB, LLWS, ICE, FZLVL hazards |
| SIGMETs | AWC `/api/data/airsigmet?format=geojson` | Active convective and non-convective SIGMETs as polygons |
| Center Weather Advisories | AWC `/api/data/cwa?format=geojson` | CWSU-issued short-term advisories (thunderstorms, turbulence, icing, IFR, precipitation) |
| TFRs | FAA TFR feed + FAA ArcGIS Open Data | Active and upcoming Temporary Flight Restrictions as shaded polygons with effective times and altitudes |

**ICING**

| Product | Data Source | Description |
|---------|------------|-------------|
| Lowest Freezing Level | AWC CIP via Decision Support Graphics | Current freezing level analysis |
| Freezing Level Analysis | AWC CIP via Decision Support Graphics | Freezing level contours |
| Icing Probability Analysis | AWC CIP via Decision Support Graphics | Current icing probability by altitude |
| Icing Severity Analysis | AWC CIP via Decision Support Graphics | Current icing severity by altitude |
| Icing Severity w/ SLD | AWC CIP via Decision Support Graphics | Supercooled large droplet icing analysis |
| Icing Severity Fcst | AWC FIP via Decision Support Graphics | Forecast icing severity (1–18 HR) |

> **Note:** The legacy `/data/products/icing/` directory returns 403 Forbidden. Icing images must be sourced via the AWC Decision Support Graphics page (`/graphics/`) which generates direct image URLs, or via the WIFS API (requires free API key).

**TURBULENCE**

Clear Air Turbulence (CAT), Mountain Wave Turbulence (MTW), and combined (All) at three altitude bands:

| Product | Type | Altitude Band | Data Source |
|---------|------|---------------|-------------|
| 1,000 ft – 12,000 ft (CAT) | CAT | Low | AWC GTG via Decision Support Graphics |
| 15,000 ft – FL300 (CAT) | CAT | Mid | AWC GTG via Decision Support Graphics |
| FL360 – FL420 (CAT) | CAT | High | AWC GTG via Decision Support Graphics |
| 1,000 ft – 12,000 ft (MTW) | MTW | Low | AWC GTG via Decision Support Graphics |
| 15,000 ft – FL300 (MTW) | MTW | Mid | AWC GTG via Decision Support Graphics |
| FL360 – FL420 (MTW) | MTW | High | AWC GTG via Decision Support Graphics |
| 1,000 ft – 12,000 ft (All) | All | Low | AWC GTG via Decision Support Graphics |
| 15,000 ft – FL300 (All) | All | Mid | AWC GTG via Decision Support Graphics |
| FL360 – FL420 (All) | All | High | AWC GTG via Decision Support Graphics |

> **Note:** The legacy `/data/products/turb/` directory returns 404. Turbulence images must be sourced via the AWC Decision Support Graphics page (`/graphics/`), or via the WIFS API (requires free API key) for gridded GRIB data.

**SATELLITE**

| Product | Data Source | Description |
|---------|------------|-------------|
| Visible | nowCOAST WMS `goes_visible_imagery` | GOES Band 2 visible imagery, 0.5km resolution, 5-min updates |
| Infrared | nowCOAST WMS `goes_longwave_imagery` | GOES Band 14 longwave IR imagery, 2km resolution, 5-min updates |
| Water Vapor | nowCOAST WMS `goes_water_vapor_imagery` | GOES Band 8 water vapor imagery, 2km resolution, 5-min updates |

**DOPPLER RADAR**

| Product | Data Source | Description |
|---------|------------|-------------|
| NEXRAD Composite | NOAA MRMS MapServer (primary) | 1km base reflectivity, updated every 5 min. CONUS, Alaska, Hawaii, Caribbean coverage |
| Animated Radar Loop | RainViewer API (animation) | Animated radar loop with 13 frames at 10-min intervals. Simpler tile API for smooth animation |

**PILOT WEATHER REPORTS**

| Product | Data Source | Description |
|---------|------------|-------------|
| PIREPs | AWC `/api/data/pirep?format=geojson` | Plotted pilot reports on CONUS map. Requires `bbox` or `id`+`distance` params. Returns turbulence, icing, sky conditions by altitude |

**SKEW-T / SOUNDINGS**

| Product | Data Source | Description |
|---------|------------|-------------|
| Airport Skew-T | Open-Meteo API (primary) | Skew-T/Log-P diagram for a single airport/location. 44 pressure levels with temperature, dewpoint, wind, cloud cover, geopotential height |
| Route Skew-T Profile | Open-Meteo API (primary) | Skew-T diagrams generated at multiple waypoints along the active flight plan route (inspired by [FlyTheWeather.com](https://www.flytheweather.com/)) |
| Route Weather Cross-Section | Open-Meteo API (primary) | Vertical cross-section along the planned route showing cloud layers, freezing level, turbulence potential, and winds — synthesized from model sounding data |

**ALASKA & PACIFIC**

| Product | Data Source | Description |
|---------|------------|-------------|
| Alaska | AWC Alaska-specific products | Alaska aviation weather summary |
| Alaska (Winds Aloft) 3,000 ft – 15,000 ft | AWC | Alaska winds aloft, low/mid |
| Alaska (Winds Aloft) FL180 – FL520 | AWC | Alaska winds aloft, high |
| Pacific | AWC Pacific products | Pacific region weather summary |

---

### 2.2 Product Viewer Screen (`/imagery/product/:productId`)

Full-screen image viewer for a selected weather product.

**App Bar:**
- Back button (left) — returns to catalog
- Product title (center) — e.g., "Prog Charts", "CONUS Cloud"
- Favorite toggle (right) — star icon, filled when favorited

**Body:**

The viewer adapts its layout based on the product type:

#### A. Thumbnail Grid (for multi-frame products like Prog Charts)

Products with multiple forecast hours display as a scrollable grid of thumbnail images, each labeled with its valid time or forecast period.

- 3-column grid of thumbnail previews
- Each thumbnail labeled: "Latest Surface Analysis", "6 HR (Updated at ~1400Z and 0200Z)", etc.
- Tap a thumbnail to view full-screen

**Full-screen sub-viewer:**
- Pinch-to-zoom and pan
- Swipe left/right to advance through frames
- Frame indicator dots or timestamp label at bottom
- Share button (export image)
- Tap to toggle chrome visibility

#### B. Single Image with Time Steps (for GFA, icing, turbulence)

Products with forecast time steps display a single large image with a time-step selector.

- Large image view (fills screen width, maintains aspect ratio)
- Pinch-to-zoom and pan
- **Time step bar** (bottom) — horizontal scrollable row of forecast hour buttons: `3HR`, `6HR`, `9HR`, `12HR`, `15HR`, `18HR`
- Active time step highlighted
- Product valid time displayed below image: "Valid: 08 Feb 2026 1800Z"
- Auto-advances through time steps when play button is pressed (animation mode)

#### C. Animated Loop (for radar, satellite)

Animated products display with playback controls.

- Full-bleed image/tile display
- **Playback controls** (bottom overlay):
  - Play/Pause button
  - Timeline scrubber showing frame timestamps
  - Speed selector: 1x, 2x, 4x
  - Loop duration: 1 HR, 2 HR, 4 HR
- Frame timestamp displayed: "08 Feb 2026 2145Z"
- Pinch-to-zoom for regional detail

#### D. Map Overlay (for G-AIRMETs, SIGMETs, CWAs, TFRs, PIREPs, SPC Outlooks)

GeoJSON-based products display on an interactive map.

- Base map (simple streets or light gray) with product overlay
- G-AIRMETs: colored polygons by hazard type (IFR=purple, MTN OBSCN=brown, Turbulence=orange, Icing=blue, etc.)
- SIGMETs: red/yellow outlined polygons with hazard labels
- CWAs: orange dashed polygons with hazard type labels
- TFRs: red (active) / yellow (upcoming) shaded polygons with altitude range labels
- SPC Outlooks: categorical risk shading (Marginal/Slight/Enhanced/Moderate/High) with probability contours
- PIREPs: point markers with altitude and report type icons
- **Filter bar** (top): hazard type toggles, altitude filter, forecast hour selector
- Tap a feature for detail popup (hazard type, altitude range, valid times, raw text)

#### E. Skew-T Viewer (for airport and route soundings)

Skew-T/Log-P diagrams rendered from model sounding data.

**Airport Skew-T (single location):**
- Search bar to select an airport or tap any point on a mini-map
- Renders a standard Skew-T/Log-P diagram: temperature (red), dewpoint (blue), wind barbs on right margin
- Pressure (mb) on Y-axis, temperature on skewed X-axis
- Key derived values displayed: freezing level, LCL, cloud bases/tops, CAPE, wind shear indicators
- Forecast hour selector: current analysis, +1, +3, +6, +12, +18 HR
- Pinch-to-zoom for detail on specific altitude bands

**Route Skew-T Profile (requires active flight plan):**
- Interactive map at top showing the route with numbered waypoints (departure, intermediate, arrival)
- Scrollable vertical list of Skew-T diagrams below, one per waypoint (every ~50–100nm along route)
- Tap a waypoint on the map to scroll to its Skew-T; scroll to a Skew-T to highlight the corresponding waypoint
- Each Skew-T labeled with waypoint identifier and distance from departure
- Forecast hours aligned to estimated time of arrival at each point

**Route Weather Cross-Section:**
- Full-width vertical cross-section diagram: X-axis = distance along route (with waypoint labels), Y-axis = altitude (SFC to FL450)
- Color-filled layers showing: cloud coverage (gray shading), icing potential (blue), turbulence potential (orange/red), freezing level (dashed cyan line)
- Planned altitude shown as a magenta horizontal line
- Wind barbs at regular intervals along the route at multiple altitudes
- Horizontal scroll for long routes; pinch-to-zoom vertically for altitude detail

---

### 2.3 Favorites Screen (`/imagery/favorites`)

Quick-access list of favorited weather products.

- Same list format as catalog but filtered to starred products
- Drag to reorder
- Empty state: "Star products to add them to your favorites"

### 2.4 Recents Screen (`/imagery/recents`)

Recently viewed products in reverse chronological order.

- List showing product name, category, and last viewed timestamp
- Tap to re-open product viewer
- Maximum 50 recent items, auto-pruned
- "Clear Recents" button in app bar

---

## 3. Screens — Plates (Terminal Procedures)

### 3.1 Plates Airport Search (`/imagery` with Plates segment selected)

**Segmented Control:** Weather | **Plates** (Plates active)

**Search Bar:**
- Prominent search field: "Search airport identifier or name"
- Auto-suggest as user types (same search as Airports module)

**Recent Airports:**
- List of recently viewed plate airports with identifier and name
- Tap to view plates for that airport

**From Flight Plan:**
- If an active flight plan exists, show departure, destination, and alternate airports as quick-access cards at the top

### 3.2 Airport Plates List (`/imagery/plates/:airportId`)

Grouped list of all terminal procedures for the selected airport.

**App Bar:**
- Back button (left)
- Airport identifier and name (center) — e.g., "KAPA — Centennial"
- Map overlay button (right) — opens geo-referenced plate on the Maps tab

**Section Groups:**

| Section | Contents | Source |
|---------|----------|--------|
| **AIRPORT DIAGRAM** | Airport/taxi diagram (FAA d-TPP) | FAA Digital-TPP |
| **DEPARTURE PROCEDURES** | ODP (Obstacle Departure Procedures), SIDs (Standard Instrument Departures) | FAA Digital-TPP |
| **ARRIVAL PROCEDURES** | STARs (Standard Terminal Arrival Routes) | FAA Digital-TPP |
| **APPROACH PROCEDURES** | ILS, LOC, RNAV (GPS), VOR, NDB, Visual approaches | FAA Digital-TPP |

Each row displays:
- Procedure name (e.g., "ILS or LOC Rwy 35R")
- Amendment date
- Chevron for drill-in

### 3.3 Plate Viewer (`/imagery/plates/:airportId/:plateId`)

Full-screen plate viewer optimized for cockpit readability.

**Top Toolbar (left to right):**
- **Close** button — returns to plates list
- **Settings** gear — brightness, invert colors (night mode)
- **Night mode** toggle — inverts plate colors for dark cockpit
- **Copy** — copy plate to a separate tab/window for side-by-side
- **Share** — export/print plate
- **Geo-overlay** — toggle geo-referenced overlay on map

**Plate Display:**
- Full-screen rendering of the FAA procedure PDF
- Pinch-to-zoom with smooth scaling (no pixelation at reasonable zoom levels)
- Pan/scroll to view different sections of the plate
- Double-tap to zoom to fit width
- Procedure name displayed below toolbar: "ILS or LOC Rwy 35R"

**NOTAMs Badge:**
- If there are active NOTAMs affecting this procedure, display a red badge on the plate (e.g., "5 NOTAMs") near the top
- Tap badge to view relevant NOTAMs

**Bottom Info Bar** (when in-flight):
- Distance Next, ETE Dest, Groundspeed, GPS Altitude, Track
- Same persistent data bar as the Maps module

---

## 4. Data Sources & API Design

### 4.1 Endpoint Verification Status (as of 2026-02-08)

All primary endpoints have been verified live:

| Endpoint | Status | Notes |
|----------|--------|-------|
| AWC GFA static PNGs (`/data/products/gfa/F{HH}_gfa_{type}_{region}.png`) | **Working** | Returns valid PNG images |
| AWC G-AIRMET API (`/api/data/gairmet?format=geojson`) | **Working** | ~33 features with SIERRA/TANGO/ZULU products |
| AWC SIGMET API (`/api/data/airsigmet?format=geojson`) | **Working** | Polygons with hazard, severity, altitude |
| AWC PIREP API (`/api/data/pirep?format=geojson`) | **Working** | Requires `bbox` or `id+distance` params; returns 400 without them |
| AWC CWA API (`/api/data/cwa?format=geojson`) | **Working** | Hazards: ts, turb, ice, ifr, pcpn |
| AWC TCF API (`/api/data/tcf?format=geojson`) | **Working** | Convective forecast polygons; empty when no convection forecast |
| RainViewer API (`api.rainviewer.com/public/weather-maps.json`) | **Working** | v2.0, 13 radar frames at 10-min intervals |
| NOAA MRMS MapServer | **Working** | 1km base reflectivity, ArcGIS REST + WMS |
| nowCOAST Satellite WMS | **Working** | 9 layers including visible (0.5km), IR (2km), water vapor (2km) |
| Open-Meteo pressure-level API | **Working** | 44 pressure levels, all needed Skew-T variables |
| FAA d-TPP downloads | **Working** | Current cycle 2602 available |
| AWC OpenAPI spec (`/data/schema/openapi.yaml`) | **Working** | Full endpoint documentation |
| AWC `/data/products/icing/` | **403 Forbidden** | Directory blocked; use Decision Support Graphics (`/graphics/`) |
| AWC `/data/products/turb/` | **404 Not Found** | Removed; use Decision Support Graphics (`/graphics/`) |

### 4.2 Weather Imagery Backend

The backend proxies and caches weather imagery to reduce client-side complexity and improve performance.

**New Module:** `ImageryModule` in the NestJS API.

#### Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `GET /api/imagery/catalog` | GET | Returns the full product catalog structure (sections, products, metadata) |
| `GET /api/imagery/product/:productId` | GET | Returns metadata for a product (available frames, valid times, URLs) |
| `GET /api/imagery/product/:productId/image` | GET | Proxies the weather image (with caching). Query params: `frame`, `forecastHour`, `region` |
| `GET /api/imagery/gfa/:type/:region` | GET | Proxies GFA images. Params: type=`clouds`\|`sfc`, region code, forecastHour |
| `GET /api/imagery/radar/tiles/:z/:x/:y` | GET | Proxies radar tiles (NOAA MRMS primary, RainViewer for animation) |
| `GET /api/imagery/radar/timestamps` | GET | Returns available radar frame timestamps for animation |
| `GET /api/imagery/satellite/:band/tiles/:z/:x/:y` | GET | Proxies satellite tiles from nowCOAST WMS. Bands: `visible`, `infrared`, `watervapor` |
| `GET /api/imagery/advisories/gairmets` | GET | Proxies G-AIRMET GeoJSON from AWC |
| `GET /api/imagery/advisories/sigmets` | GET | Proxies SIGMET GeoJSON from AWC |
| `GET /api/imagery/advisories/cwas` | GET | Proxies CWA GeoJSON from AWC |
| `GET /api/imagery/tfrs` | GET | Returns active TFRs as GeoJSON (from FAA TFR feed / ArcGIS Open Data) |
| `GET /api/imagery/pireps` | GET | Proxies PIREP GeoJSON from AWC. Query params: `bbox` (required), `age` (hours) |
| `GET /api/imagery/spc/outlooks` | GET | Proxies SPC convective outlooks as GeoJSON from NWS MapServer |
| `GET /api/imagery/spc/discussions` | GET | Proxies SPC mesoscale discussions as GeoJSON from NWS MapServer |
| `GET /api/imagery/sounding` | GET | Returns model sounding data for a lat/lon point via Open-Meteo. Query params: `lat`, `lon`, `model` (gfs_seamless\|hrrr\|gfs), `forecastHours` |
| `GET /api/imagery/route-soundings` | GET | Returns soundings at multiple points along a route. Query params: `waypoints` (JSON array of lat/lon), `model`, `forecastHours` |

#### Caching Strategy

| Product Type | Cache TTL | Rationale |
|-------------|-----------|-----------|
| Prog Charts | 60 min | Updated every 6 hours |
| GFA (Cloud/Surface) | 30 min | Updated hourly |
| Icing/Turbulence images | 30 min | Updated hourly |
| Winds Aloft graphics | 60 min | Updated every 6 hours |
| Convective Outlooks (SPC) | 15 min | Updated frequently during active weather |
| Convective Forecasts (TCF) | 15 min | Updated as conditions change |
| Radar tiles (MRMS) | 5 min | Updated every 5 min |
| Radar animation frames (RainViewer) | 5 min | Updated every 10 min |
| Satellite tiles | 10 min | Updated every 5–15 min |
| G-AIRMETs/SIGMETs/CWAs | 10 min | Updated as issued |
| TFRs | 15 min | Generally static; new TFRs are infrequent |
| PIREPs | 10 min | Filed continuously |
| Model Soundings (Open-Meteo) | 60 min | Model updates hourly (HRRR) or 6-hourly (GFS) |

### 4.3 Upstream Data Sources (Verified)

| Category | Primary Source | URL Pattern | Format | Status |
|----------|---------------|-------------|--------|--------|
| GFA panels | AWC static images | `https://aviationweather.gov/data/products/gfa/F{HH}_gfa_{type}_{region}.png` | PNG | Verified |
| Prog Charts | AWC Decision Support Graphics | `https://aviationweather.gov/graphics/` (follow image URLs) | GIF/PNG | Verified |
| SigWx charts | AWC Fax/SigWx | `https://aviationweather.gov/data/products/fax/` | GIF | Active |
| Icing (CIP/FIP) | AWC Decision Support Graphics | `https://aviationweather.gov/graphics/` (select Icing product) | GIF/PNG | Verified (legacy `/data/products/icing/` returns 403) |
| Turbulence (GTG) | AWC Decision Support Graphics | `https://aviationweather.gov/graphics/` (select Turbulence product) | GIF/PNG | Verified (legacy `/data/products/turb/` returns 404) |
| Icing/Turb (alt) | WIFS API | `https://aviationweather.gov/wifs/api/collections/{collection}/items/{item}` | GRIB | Requires free API key |
| Winds Aloft graphics | AWC fax charts | `https://aviationweather.gov/fax/` | GIF | Active |
| SPC Convective Outlooks | NWS MapServer | `https://mapservices.weather.noaa.gov/vector/rest/services/outlooks/SPC_wx_outlks/MapServer` | GeoJSON | Verified |
| SPC Mesoscale Discussions | NWS MapServer | `https://mapservices.weather.noaa.gov/vector/rest/services/outlooks/spc_mesoscale_discussion/MapServer` | GeoJSON | Verified |
| Convective Forecast (TCF) | AWC Data API | `https://aviationweather.gov/api/data/tcf?format=geojson` | GeoJSON | Verified |
| Radar (US primary) | NOAA MRMS MapServer | `https://mapservices.weather.noaa.gov/eventdriven/rest/services/radar/radar_base_reflectivity/MapServer` | WMS tiles | Verified (1km, 5-min updates) |
| Radar (animation) | RainViewer API | `https://api.rainviewer.com/public/weather-maps.json` → tile URLs | PNG tiles | Verified (13 frames, 10-min intervals) |
| Radar (alt) | Iowa State Mesonet | `https://mesonet.agron.iastate.edu/cache/tile.py/1.0.0/ridge::.../{z}/{x}/{y}.png` | PNG tiles | Active |
| Satellite | nowCOAST WMS | `https://nowcoast.noaa.gov/geoserver/satellite/wms` (layers: `goes_visible_imagery`, `goes_longwave_imagery`, `goes_water_vapor_imagery`) | PNG (WMS) | Verified (0.5-2km, 5-min) |
| Satellite (alt) | NOAA STAR CDN | `https://cdn.star.nesdis.noaa.gov/GOES19/ABI/CONUS/{BAND}/` | GIF | Active |
| G-AIRMETs | AWC Data API | `https://aviationweather.gov/api/data/gairmet?format=geojson` | GeoJSON | Verified |
| SIGMETs | AWC Data API | `https://aviationweather.gov/api/data/airsigmet?format=geojson` | GeoJSON | Verified |
| CWAs | AWC Data API | `https://aviationweather.gov/api/data/cwa?format=geojson` | GeoJSON | Verified |
| PIREPs | AWC Data API | `https://aviationweather.gov/api/data/pirep?format=geojson&bbox=20,-130,55,-60&age=2` | GeoJSON | Verified (requires bbox or id+distance) |
| TFRs | FAA TFR feed | `https://tfr.faa.gov/save_pages/detail_{NOTAM_ID}.xml` | XML/AIXM | Active |
| TFRs (alt) | FAA ArcGIS Open Data | `https://adds-faa.opendata.arcgis.com/` | GeoJSON | Active |
| Model Soundings (primary) | Open-Meteo API | `https://api.open-meteo.com/v1/gfs?latitude={lat}&longitude={lon}&hourly=temperature_{level}hPa,dew_point_{level}hPa,wind_speed_{level}hPa,wind_direction_{level}hPa,geopotential_height_{level}hPa,cloud_cover_{level}hPa` | JSON | Verified (44 pressure levels) |
| Model Soundings (alt) | NOAA NOMADS (RAP/HRRR) | `https://nomads.ncep.noaa.gov/dods/hrrr/` | GRIB2 | Active (requires server-side GRIB processing) |

### 4.4 AWC API Reference

Full AWC Data API (no auth required, 100 req/min rate limit, max 400 entries/response):

```
Base: https://aviationweather.gov/api/data
Spec: https://aviationweather.gov/data/schema/openapi.yaml

GET /metar        - METARs (format: raw|decoded|json|geojson|xml)
GET /taf          - TAFs (format: raw|json|geojson|xml)
GET /pirep        - PIREPs (requires bbox or id+distance)
GET /airsigmet    - SIGMETs/AIRMETs (hazard: conv|turb|ice|ifr)
GET /gairmet      - G-AIRMETs (product: sierra|tango|zulu, fore: 0|3|6|9|12)
GET /cwa          - Center Weather Advisories (hazard: ts|turb|ice|ifr|pcpn)
GET /tcf          - Convective Forecasts
GET /windtemp     - Winds/Temps aloft text (region, level: low|high, fcst: 06|12|24)
GET /stationinfo  - Station metadata
GET /airport      - Airport information
GET /airmet       - Alaska AIRMETs only
```

### 4.5 Open-Meteo API Details (Skew-T Data)

Open-Meteo provides the simplest path to Skew-T sounding data — JSON response, no GRIB processing, 44 pressure levels.

**Available pressure levels (hPa):** 1000, 975, 950, 925, 900, 875, 850, 825, 800, 775, 750, 725, 700, 675, 650, 625, 600, 575, 550, 525, 500, 475, 450, 425, 400, 375, 350, 325, 300, 275, 250, 225, 200, 175, 150, 125, 100, 70, 50, 40, 30, 20, 15, 10

**Variables at each level:** `temperature`, `dew_point`, `relative_humidity`, `cloud_cover`, `wind_speed`, `wind_direction`, `geopotential_height`, `vertical_velocity`

**Model options:** `gfs_seamless` (auto-blends HRRR 3km for US + GFS globally — recommended), `hrrr` (3km CONUS, hourly), `gfs` (13km global, 6-hourly)

**Licensing:**
- Free for non-commercial use: No API key, 10,000 calls/day limit
- Commercial use: Starts at $29/month for 1M API calls (CC BY 4.0 attribution required)
- Self-hosting option: Open-source, can run own instance processing raw NOAA data

### 4.6 Plates Data Source

| Data | Source | Format | Update Cycle |
|------|--------|--------|-------------|
| Terminal Procedures (d-TPP) | FAA AeroNav (`aeronav.faa.gov`) | PDF (one per procedure) | 28-day AIRAC cycle |
| d-TPP Metadata | `d-TPP_Metafile.xml` (inside DDTPPE zip) | XML → parsed to JSON | 28-day AIRAC cycle |
| Geo-referencing data | FAA CIFP (ARINC 424) + community georef tools | Coordinate pairs per plate | 28-day AIRAC cycle |

#### d-TPP Download Details

**ZIP downloads (~4-5 GB total across 5 files):**
```
https://aeronav.faa.gov/upload_313-d/terminal/DDTPPA_{YYMMDD}.zip  (~1.0 GB — procedure PDFs, part 1)
https://aeronav.faa.gov/upload_313-d/terminal/DDTPPB_{YYMMDD}.zip  (~1.0 GB — procedure PDFs, part 2)
https://aeronav.faa.gov/upload_313-d/terminal/DDTPPC_{YYMMDD}.zip  (~1.0 GB — procedure PDFs, part 3)
https://aeronav.faa.gov/upload_313-d/terminal/DDTPPD_{YYMMDD}.zip  (~1.0 GB — procedure PDFs, part 4)
https://aeronav.faa.gov/upload_313-d/terminal/DDTPPE_{YYMMDD}.zip  (~130 MB — change notice + XML metafile)
```
Where `{YYMMDD}` is the cycle effective date (e.g., `260122` for Jan 22, 2026).

**Individual plate URL pattern:**
```
https://aeronav.faa.gov/d-tpp/{YYMM}/{pdf_name}
```
Example: `https://aeronav.faa.gov/d-tpp/2602/00961AD.PDF`

Next edition files are available 20 days before the effective date. Approximately 17,000 individual PDFs per cycle.

#### d-TPP_Metafile.xml Structure

```xml
<digital_tpp cycle="2602" from_edate="0122" to_edate="0219">
  <state_code ID="CO">
    <city_name volume="SC-2">
      <airport_name apt_ident="APA" military="N">
        <record>
          <chartseq>10100</chartseq>
          <chart_code>IAP</chart_code>            <!-- IAP, DP, STAR, AD, CVFP -->
          <chart_name>ILS OR LOC RWY 35R</chart_name>
          <useraction>C</useraction>               <!-- A=Added, C=Changed, D=Deleted -->
          <pdf_name>00961IL35R.PDF</pdf_name>
          <faanfd18>...</faanfd18>
          <copter>N</copter>
        </record>
      </airport_name>
    </city_name>
  </state_code>
</digital_tpp>
```

Field definitions: `https://aeronav.faa.gov/dtpp/Metafile_XML_Definitions.pdf`

#### Geo-Referencing Approach

FAA does **not** provide geo-referenced approach plates directly. Options:

1. **CIFP cross-reference**: FAA CIFP (free, `https://www.faa.gov/air_traffic/flight_info/aeronav/digital_products/cifp/`) provides ARINC 424 waypoint coordinates for every procedure. Cross-reference waypoint positions with plate features to compute ground control points.
2. **Community tools**: [GeoReferencePlates](https://github.com/jlmcgraw/GeoReferencePlates) uses OCR + CIFP database matching to extract georeferencing control points from plate PDFs.
3. **Airport reference points + runway endpoints**: Known positions from NASR data provide anchor points for plate registration.

#### Plates Pipeline

1. **Download**: Fetch DDTPPA-E ZIPs from FAA every 28 days (or proxy individual PDFs via `aeronav.faa.gov/d-tpp/{cycle}/{filename}`)
2. **Parse catalog**: Extract procedure metadata from `d-TPP_Metafile.xml` into SQLite — maps airport → procedure list with PDF filenames, chart codes, amendment status
3. **Store/Proxy**: Either store PDFs locally (`data/plates/{cycle}/{airport_id}/{filename}.pdf`) or proxy on-demand from FAA URLs with aggressive caching
4. **Serve**: Backend serves plates via API endpoints
5. **Client rendering**: Flutter renders PDFs using a PDF viewer widget with zoom/pan support

#### Plates API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `GET /api/plates/:airportId` | GET | Returns procedure list for an airport (name, type, filename, amendment date) |
| `GET /api/plates/:airportId/:filename` | GET | Serves the PDF file for a specific procedure |
| `GET /api/plates/cycle` | GET | Returns current and next cycle effective dates |
| `POST /api/admin/plates/update` | POST | Admin trigger to download and process a new d-TPP cycle |

---

## 5. Data Model

### FavoriteProduct (local storage)

| Field | Type | Description |
|-------|------|-------------|
| `productId` | String | Unique product identifier (e.g., `gfa_clouds_us`, `icing_severity`) |
| `displayName` | String | Human-readable name |
| `category` | String | Section name (e.g., "CONUS Weather", "Icing") |
| `sortOrder` | int | User-defined display order |
| `addedAt` | DateTime | When favorited |

### RecentProduct (local storage)

| Field | Type | Description |
|-------|------|-------------|
| `productId` | String | Unique product identifier |
| `displayName` | String | Human-readable name |
| `category` | String | Section name |
| `viewedAt` | DateTime | Last viewed timestamp |

### Plate (from backend API)

| Field | Type | Description |
|-------|------|-------------|
| `airportId` | String | FAA airport identifier (e.g., `APA`) |
| `procedureName` | String | Full procedure name (e.g., "ILS or LOC Rwy 35R") |
| `procedureType` | Enum | `airport_diagram`, `departure`, `arrival`, `approach`, `cvfp` |
| `chartCode` | String | FAA chart code: `AD`, `DP`, `STAR`, `IAP`, `CVFP` |
| `filename` | String | PDF filename in d-TPP |
| `amendmentDate` | String | Chart amendment date |
| `cycle` | String | AIRAC cycle identifier (e.g., `2602`) |

---

## 6. Client Architecture (Flutter)

### Feature Directory

```
lib/features/imagery/
  imagery_screen.dart                  # Main screen with Weather/Plates segments
  widgets/
    weather_catalog.dart               # Sectioned product list
    product_viewer.dart                # Full-screen image viewer
    thumbnail_grid_viewer.dart         # Multi-frame thumbnail grid (prog charts)
    time_step_viewer.dart              # Single image with forecast hour selector (GFA)
    animated_loop_viewer.dart          # Radar/satellite animation player
    map_overlay_viewer.dart            # GeoJSON advisory/PIREP/TFR/SPC map viewer
    favorites_list.dart                # Favorited products list
    recents_list.dart                  # Recently viewed products list
    plates_search.dart                 # Airport search for plates
    plates_list.dart                   # Procedure list for an airport
    plate_viewer.dart                  # Full-screen PDF plate viewer
    skewt_viewer.dart                  # Skew-T/Log-P diagram renderer
    skewt_painter.dart                 # CustomPainter for Skew-T chart
    route_soundings_viewer.dart        # Multi-waypoint Skew-T scroll view
    route_cross_section.dart           # Route weather cross-section diagram
    route_cross_section_painter.dart   # CustomPainter for cross-section
```

### State Management (Riverpod)

```dart
// Product catalog — static structure, loaded once
final imageryCatalogProvider = FutureProvider<ImageryCatalog>((ref) async { ... });

// Product frames/metadata — loaded when a product is opened
final productFramesProvider = FutureProvider.family<ProductFrames, String>((ref, productId) async { ... });

// Favorites — persisted locally
final imageryFavoritesProvider = StateNotifierProvider<FavoritesNotifier, List<FavoriteProduct>>((ref) { ... });

// Recents — persisted locally
final imageryRecentsProvider = StateNotifierProvider<RecentsNotifier, List<RecentProduct>>((ref) { ... });

// Plates for an airport
final airportPlatesProvider = FutureProvider.family<List<Plate>, String>((ref, airportId) async { ... });

// Radar animation timestamps
final radarTimestampsProvider = FutureProvider<List<RadarFrame>>((ref) async { ... });

// Skew-T sounding for a location
final soundingProvider = FutureProvider.family<SoundingData, SoundingRequest>((ref, request) async { ... });

// Route soundings — depends on active flight plan
final routeSoundingsProvider = FutureProvider<List<SoundingData>>((ref) async { ... });
```

---

## 7. Design Notes

- **Dark theme** consistent with cockpit UI — all viewers use dark backgrounds
- Product catalog uses section headers styled with `AppColors.primary` text on `AppColors.surface` background (matching the blue section headers in reference screenshots)
- List rows use `AppColors.card` background with `AppColors.divider` separators and trailing chevron icons
- Image viewers default to dark background with the weather graphic displayed at native resolution
- Plates viewer supports **night mode** (color inversion) for cockpit readability
- Thumbnail grid uses 3-column layout with generous padding for touch targets
- Animated loops show a semi-transparent playback control overlay that auto-hides after 3 seconds of inactivity
- Favorites star icon uses filled/outline state (`Icons.star` / `Icons.star_border`)
- TFR polygons use red fill (active) / yellow fill (upcoming) with semi-transparency
- SPC outlook map uses standard categorical risk colors: green (Marginal), yellow (Slight), orange (Enhanced), red (Moderate), magenta (High)

---

## 8. Offline Considerations

### Weather Imagery
- Weather imagery is **online-only** — products are time-sensitive and require fresh data
- Last-viewed images can be cached locally for brief offline access (cache images for up to 2 hours)
- Show "Last updated: {timestamp}" and stale data warning when displaying cached content offline

### Plates
- Plates are **available offline** after download
- Full d-TPP cycle is ~4-5 GB — offer selective download by state, region, or airport list
- Download manager in Settings/More allows users to pre-download plates for planned airports
- Auto-download plates for airports in active flight plans
- Show cycle effective dates prominently; warn when approaching cycle expiration
- Alternative: proxy individual PDFs from FAA on-demand with local caching (avoids bulk download)

---

## 9. Integration Points

| Integration | Description |
|-------------|-------------|
| **Airport Details → Plates** | "Procedures" section in airport details links directly to the plates list for that airport |
| **Flight Planning → Plates** | Flight plan departure/destination airports provide quick-access to relevant SIDs, STARs, approaches |
| **Maps → Plate Overlay** | Geo-referenced plates can be displayed as semi-transparent overlays on the moving map |
| **Maps → Weather Layers** | Radar and satellite from Imagery module share the same tile infrastructure as Maps weather overlays |
| **Maps → TFR Overlay** | TFR polygons from Imagery module can be rendered as a Maps overlay layer |
| **Flight Planning → Weather Imagery** | Graphical briefing pulls relevant imagery for the planned route |
| **Flight Planning → Skew-T / Route Profile** | Active flight plan feeds waypoints to the route Skew-T and cross-section viewers. Forecast hours aligned to ETAs at each waypoint |

---

## 10. Future Enhancements

- International regions (Canada, Caribbean, Europe) with region-appropriate weather products
- MOS (Model Output Statistics) forecasts for 2,100+ US airports — extends beyond TAF coverage
- FAA Weather Cameras (500+ cameras across 24 states, 10-min updates from `weathercams.faa.gov`)
- Lightning overlay (GOES-R GLM data from NCEI SWDI web services — free, Western Hemisphere coverage)
- Cloud tops/bases separate overlay layers
- Precipitation type overlay (snow, rain, freezing rain)
- Future radar nowcast (extrapolated radar predictions)
- Custom product collections / briefing templates
- Side-by-side plate comparison
- Plate annotation (draw/mark on plates during briefing)
- Push notifications for significant weather updates (convective SIGMETs, etc.)
- Download individual weather products for offline preflight briefing
- Synthetic approach plate overlay with ownship position in real-time
- Space weather status indicator (SWPC D-RAP for HF comm disruption awareness)

---

## Implementation Status

### Built

**Backend (ImageryModule):**
- `GET /api/imagery/gfa/:type/:region` — Proxies GFA static PNGs from AWC with caching
- `GET /api/imagery/advisories` — Proxies G-AIRMET, SIGMET, CWA GeoJSON from AWC
- `GET /api/imagery/pireps` — Proxies PIREP GeoJSON from AWC (requires bbox)
- In-memory caching per product type (GFA 30min, advisories 10min, PIREPs 10min)

**Mobile (Imagery tab — 4th bottom nav tab):**
- `imagery_screen.dart` — Main screen with product catalog
- `gfa_viewer.dart` — GFA cloud/surface viewer with region picker and forecast hour selector (3–18 HR)
- `advisory_viewer.dart` — Interactive map viewer for G-AIRMETs, SIGMETs, CWAs with colored polygons by hazard type, tap-for-detail, filter bar
- `pirep_viewer.dart` — PIREP list/map viewer

**Routing:** `/imagery`, `/imagery/gfa`, `/imagery/advisories`, `/imagery/pireps`

### Not Started

**Weather Imagery Products:**
- Prog Charts (thumbnail grid viewer)
- Convective Outlooks / SPC Mesoscale Discussions
- Convective Forecasts (TCF)
- Winds Aloft graphics
- Icing products (CIP/FIP) — must use Decision Support Graphics, legacy URLs blocked
- Turbulence products (GTG) — must use Decision Support Graphics
- Radar animation (MRMS / RainViewer) — data sources verified
- Satellite (nowCOAST WMS) — data sources verified
- Skew-T / Soundings (Open-Meteo API verified)
- Route weather cross-section
- Favorites / Recents system
- Full product catalog with all sections

**Plates:**
- Airport plates search
- Plates list per airport
- PDF plate viewer
- d-TPP download and catalog parsing
- Geo-referenced plate overlay on map
