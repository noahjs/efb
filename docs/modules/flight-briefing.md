# Flight Briefing Module
## EFB Product Specification

[← Back to Core Specification](../EFB_Product_Specification_v1.md)

---

The Flight Briefing module provides a comprehensive, FAA-standard preflight briefing for a planned flight. It synthesizes weather, NOTAMs, TFRs, advisories, winds, and forecasts along the planned route into a single scrollable document — the digital equivalent of calling FSS for a Standard Briefing.

## Priority

**P0 — Core.** 14 CFR 91.103 requires pilots to become familiar with all available information concerning a flight. The briefing module is the primary way pilots satisfy this regulatory requirement.

## User Stories

- As a pilot, I want to view a comprehensive standard briefing for my planned flight so I can satisfy preflight action requirements.
- As a pilot, I want to see TFRs along my route with map visualizations so I know what restricted airspace to avoid.
- As a pilot, I want NOTAMs organized by departure, destination, enroute, and ARTCC so I can focus on what's relevant to each phase of flight.
- As a pilot, I want to see AIRMETs and SIGMETs along my route with polygons on a map so I can assess hazards.
- As a pilot, I want METARs and TAFs for airports along my route so I can assess current and forecast weather.
- As a pilot, I want to see winds aloft at my filed altitude and nearby altitudes so I can evaluate my altitude selection.
- As a pilot, I want a vertical cross-section chart along my route showing winds, turbulence, icing, and terrain so I can assess hazards at my cruise altitude.
- As a pilot, I want to toggle between plain text and decoded views for METARs, TAFs, and NOTAMs so I can read them however I prefer.
- As a pilot, I want to see which briefing items are active during my passing time so I can focus on what affects my flight.
- As a pilot, I want an unread counter so I can ensure I've reviewed every section before departure.

---

## 1. Entry Point

The briefing is accessed from the Flight Detail screen via a **"Briefing"** button. A flight must have at minimum a departure and destination airport set. The briefing is generated for the route, altitude, ETD, and ETE of the associated flight.

**Route:** `/flights/:flightId/briefing`

---

## 2. Layout

### 2.1 Three-Panel Layout (Tablet/Landscape)

| Panel | Width | Content |
|-------|-------|---------|
| **Navigation Sidebar** | ~240px fixed | Briefing summary header + collapsible section tree |
| **List Panel** | ~300px fixed | Items within the selected section |
| **Detail Panel** | Remaining | Full detail view of the selected item (map, text, chart) |

### 2.2 Mobile Layout (Phone/Portrait)

On narrow screens, collapse to a single-panel drill-down navigation:
1. Section list → 2. Item list → 3. Item detail (with back navigation)

### 2.3 Navigation Sidebar

**Briefing Summary Header** (pinned at top of sidebar):
- Route: `KDEN to KLAX`
- Altitude + Aircraft: `28,000' MSL in N980EK`
- ETD: `0310Z`
- ETE + ETA: `3h8m, ETA 0618Z`
- Unread sections counter (orange dot + count)

**Section Tree** — "STANDARD BRIEFING" label, then collapsible sections:

Each section shows:
- Icon (section-specific)
- Section name
- Orange dot indicator if section has unread items
- Chevron to expand/collapse subsections

---

## 3. Sections

The briefing follows the FAA Standard Briefing structure. Sections appear in this fixed order. Sections with no data are shown greyed out (not hidden) to confirm they were checked.

### 3.1 Adverse Conditions

The first and most critical section. Contains all hazards and restrictions along the route.

#### 3.1.1 Temporary Flight Restrictions (TFRs)

**Data Source:** FAA TFR GeoServer WFS (polygons) + TFR JSON API (metadata)
**Existing Backend:** `weather.service.ts` TFR endpoints, `api/src/weather/` TFR proxy
**Filter:** TFRs whose polygon intersects or is within a corridor (e.g., 50nm) of the flight route

**List Panel** — Each TFR shows:
- NOTAM identifier (e.g., `ZLA 4/3635`)
- Effective dates
- Truncated description text
- **Active/Inactive during passing time** badge (red label showing the time window overlap with the flight's passing time at that point)

**Detail Panel:**
- Title: "Temporary Flight Restriction"
- NOTAM identifier
- Active time (full validity period)
- Active during passing time (highlighted in red, showing overlap with flight)
- **Map** showing TFR polygon (red outline) with flight route (magenta line)
- TFR icon badge (top-right corner)
- Raw NOTAM text (full text)

#### 3.1.2 Closed/Unsafe NOTAMs

**Data Source:** FAA NOTAM API — NOTAMs with keyword indicating runway/taxiway/airport closures
**Existing Backend:** `weather.service.ts` NOTAM endpoint
**Filter:** NOTAMs for departure and destination airports with closure/unsafe keywords

**List Panel** — Each NOTAM shows:
- Airport name and ICAO
- Truncated NOTAM text
- Effective dates

**Detail Panel:**
- Title: "Closed Or Unsafe NOTAMs" + airport ICAO
- Issuer (FAA 3-letter)
- Location (full airport name + ICAO)
- NOTAM text

#### 3.1.3 Convective SIGMETs

**Data Source:** AWC `airsigmet` API — type `convective`
**Existing Backend:** `imagery.service.ts` advisory endpoints
**Filter:** Convective SIGMETs whose polygon intersects the route corridor
**Display:** Same pattern as AIRMETs (list + map + raw text). Greyed out if none active.

#### 3.1.4 SIGMETs

**Data Source:** AWC `airsigmet` API — type `sigmet`
**Existing Backend:** `imagery.service.ts` advisory endpoints
**Filter:** SIGMETs whose polygon intersects the route corridor
**Display:** Same pattern as AIRMETs. Greyed out if none active.

#### 3.1.5 AIRMETs (expandable subsections)

**Data Source:** AWC `airsigmet` API — type `airmet`
**Existing Backend:** `imagery.service.ts` advisory endpoints
**Filter:** AIRMETs whose polygon intersects the route corridor

**Subsections** (each is its own nav item):
- **IFR** — IFR conditions (low ceilings, visibility)
- **Mountain Obscuration** — Mountain obscuration by clouds/precip
- **Icing** — Icing conditions with severity, top, base, freezing level
- **Turbulence Low** — Low-level turbulence (below FL180)
- **Turbulence High** — High-level turbulence (FL180+)
- **Low Level Wind Shear** — LLWS advisories
- **Other** — Other AIRMETs (e.g., HighSurfaceWinds)

**List Panel** — Each AIRMET shows:
- Hazard type (e.g., "Mountain Obscuration", "Icing")
- Valid period
- Issue time, severity, cause
- Truncated raw text
- **Active/Inactive during passing time** badge (red):
  - "ACTIVE DURING PASSING TIME" + time window
  - "INACTIVE DURING PASSING TIME" + time window
  - "ACTIVE NEAR PASSING TIME" + time window

**Detail Panel:**
- Title: Hazard type name
- Hazard type icon (top-right) — snowflake for icing, mountain for mtn obsc, chevrons for turbulence, triangle for wind
- Active time (full validity period)
- Active during passing time label (red, right column)
- **Map** showing AIRMET polygon (red outline) with flight route (magenta line), with ETA waypoint labels along route
- **Raw Text** showing: Valid, Issued, Severity, Top, Base, Due to (cause)

#### 3.1.6 Urgent PIREPs

**Data Source:** AWC `pirep` API — urgency `UUA`
**Existing Backend:** `weather.service.ts` PIREP endpoint
**Filter:** Urgent PIREPs within a corridor of the route

**List Panel** — Each PIREP shows:
- Type badge: `UUA`
- Raw PIREP text
- Translated summary (Location, Time, Altitude, A/C Type, Turbulence/Icing, Remarks)

**Detail Panel:**
- Title: "Urgent PIREP"
- Raw text header
- Weather icon (top-right)
- **Map** showing PIREP location pin on flight route
- **Translated** section: parsed fields (Location, Time, Altitude, A/C Type, Turbulence, Remarks)
- "SHOW RAW TEXT" toggle link

---

### 3.2 Synopsis

**Data Source:** AWC/NWS Surface Analysis Chart image
**Existing Backend:** `imagery.service.ts` product proxy (GFA products)
**New Endpoint Needed:** None — reuse existing imagery product proxy for surface analysis chart

**List Panel** — Single item: "Surface Analysis Chart"

**Detail Panel:**
- Title: "Surface Analysis Chart"
- Info icon (top-right)
- Full NWS Surface Analysis image showing fronts, pressure systems, precipitation
- Valid time + update time shown on the chart itself

---

### 3.3 Current Weather (expandable)

#### 3.3.1 METARs

**Data Source:** AWC `metar` API
**Existing Backend:** `weather.service.ts` METAR endpoint
**Data Needed:** METARs for departure, destination, alternate(s), and airports/weather stations along the route

**Detail Panel (full-width):**
- Title: "METARs"
- **Plain Text toggle** (top-right) — ON/OFF switch between raw and decoded
- **Map** showing flight route (magenta line) with colored dots at each station:
  - Green = VFR
  - Blue = MVFR
  - Red = IFR
  - Magenta = LIFR
  - Grey with `?` = Unknown/AUTO with no flight category
- **Station Table** grouped by:
  - **DEPARTURE** — departure airport METAR
  - **ROUTE** — stations along the route (nearest airports/weather stations)
  - **DESTINATION** — destination airport METAR
- Each row: `[Flight Cat dot] [Category] [Station ID] [Obs Time] [Raw METAR text]`

**Route Station Selection Logic:**
- Query airports/weather stations within a corridor (e.g., 25nm either side) of the route
- Sample at regular intervals along the route (roughly every 50-100nm)
- Include any airport that is a waypoint in the route string
- Sort in route order (departure → destination)

#### 3.3.2 PIREPs (all, not just urgent)

**Data Source:** AWC `pirep` API — both `UA` and `UUA`
**Existing Backend:** `weather.service.ts` PIREP endpoint
**Filter:** PIREPs within a corridor of the route

**List Panel** — Each PIREP shows:
- Translated summary (bold): Location, Time, Altitude, A/C Type, Turbulence, Sky Condition
- Raw PIREP text (smaller, below)

**Detail Panel:**
- Title: "PIREP"
- Raw text header
- Weather icon (top-right)
- **Map** showing PIREP location pin on flight route
- **Translated** section with parsed fields
- "SHOW RAW TEXT" toggle

---

### 3.4 Forecasts (expandable)

#### 3.4.1 Cloud Coverage (GFA)

**Data Source:** AWC Graphical Forecasts for Aviation (GFA) — Cloud product
**Existing Backend:** `imagery.service.ts` GFA product proxy
**Products:** Cloud coverage forecast images by region and valid time

**List Panel** — Items organized by region + time:
- Central 0300z, 0600z, 0900z
- Northcentral 0300z, 0600z, 0900z
- Southwest 0300z, 0600z, 0900z
- West 0300z, 0600z, 0900z
- CONUS 0300z, 0600z, 0900z

**Region Selection Logic:** Include regions the route passes through, plus CONUS overview.

**Detail Panel:**
- Title: Region + time (e.g., "Central 0300z")
- Cloud icon (top-right)
- Full GFA cloud forecast image
- Legend: Cloud coverage symbols (FEW, SCT, BKN, OVC) and base MSL

#### 3.4.2 Vis, Sfc Winds & Precip (GFA)

**Data Source:** AWC GFA — Surface product
**Existing Backend:** `imagery.service.ts` GFA product proxy
**Display:** Same region/time structure as Cloud Coverage

**Detail Panel:**
- Title: Region + time
- Wind icon (top-right)
- Full GFA surface forecast image
- Legend: Obscurations, weather, visibility (SM), surface winds/gusts, thunderstorm probability, AIRMET overlays

#### 3.4.3 TAFs

**Data Source:** AWC `taf` API
**Existing Backend:** `weather.service.ts` TAF endpoint
**Data Needed:** TAFs for departure, destination, alternate(s), and TAF-reporting airports along the route

**Detail Panel (full-width):**
- Title: "TAFs"
- **Plain Text toggle** (top-right)
- **Map** with colored dots along route (same flight category coloring as METARs, based on forecast conditions)
- **TAF listing** per station, route order:
  - Station header: `[Flight Cat dot] [Category] [Station ID bold] [TAF text]`
  - **Current period badge** (green pill with time, e.g., "0310Z") highlighting which forecast group is active at ETD
  - Each `FM`/`BECMG`/`TEMPO` line: `[Flight Cat dot] [Category] [Forecast text]`

#### 3.4.4 Wind Chart

**Data Source:** NCEP wind data via Open-Meteo API or AWC winds aloft
**Existing Backend:** `windy.service.ts` wind grid endpoint
**New Work Needed:** Server-side wind chart image generation, OR client-side rendering of wind barbs on a map tile

**Detail Panel:**
- Title: "Wind Chart"
- Height label (e.g., `FL 280`) + Valid time
- **Map/Chart** showing:
  - Wind barbs at grid points covering the route region
  - Temperature values at each grid point
  - Flight route overlaid (blue line with waypoint labels: `KDEN`, `700-KLAX`, `600-KLAX`, etc.)
- Data attribution: "Data by NCEP"

#### 3.4.5 Vertical Cross Section Chart

**Data Source:** NCEP wind/temperature data + AWC turbulence (GTG/EDR) + icing (CIP/FIP) products + SRTM terrain
**Existing Backend:** `windy.service.ts` (winds), elevation service (terrain)
**New Work Needed:** This is a **complex chart** that must be generated server-side or rendered client-side. It combines multiple data layers.

**Detail Panel:**
- Title: "Vertical Cross Section Chart"
- **Chart** with:
  - **Y-axis:** Altitude (FL40 to FL400+, in 4000ft increments)
  - **X-axis:** Waypoints along route (KDEN, 700-KLAX, 600-KLAX, ... KLAX) with distance/ETA labels
  - **Wind barbs** at each altitude/waypoint intersection showing direction and speed
  - **Temperature values** (°C) at each grid point, negative if not prefixed with `+`
  - **Flight path** (blue solid line) at the filed cruise altitude
  - **Tropopause** (red dashed line) across the top
  - **Terrain profile** (green/olive filled area from bottom)
  - **Turbulence EDR** overlay (color gradient: 0.0 through 1.0, green→yellow→red)
  - **Icing severity** overlay (icons: light→moderate→severe→extreme)
- **Legend** at bottom:
  - Turbulence EDR color scale
  - Icing severity icon scale
  - Line styles: Flight Path (blue solid), Tropopause (red dashed), Terrain (green fill)
- Data attribution: "Data by NCEP"

#### 3.4.6 Winds Aloft Table

**Data Source:** AWC winds aloft text products + Open-Meteo point forecast
**Existing Backend:** `weather.service.ts` winds aloft endpoint, `windy.service.ts` point forecast
**Data Needed:** Wind direction, speed, and temperature at multiple altitudes for each waypoint along the route

**Detail Panel:**
- Title: "Winds Aloft Table"
- **Toggle** (top-right): "ONLY ALTITUDES WITHIN 4,000FT" — ON/OFF to filter to ±4000ft of filed altitude
- **Table:**
  - **Columns:** Altitude levels (e.g., 24000, 26000, **28000 "Filed"**, 30000, 32000)
    - Filed altitude column highlighted in blue
    - Column sub-headers show offset from filed altitude (e.g., `-4000 FT`, `-2000 FT`, `Filed`, `2000 FT`, `4000 FT`)
  - **Rows:** Waypoints along route in order (KDEN, 700-KLAX, 600-KLAX, 500-KLAX, ... KLAX)
    - Waypoint labels use distance-from-destination format (e.g., `700-KLAX` = 700nm from KLAX)
  - **Cell values:** `Direction° Speed kts Temp°C` (e.g., `260° 74kts -38°C`)
  - Filed altitude column cells highlighted with blue background

---

### 3.5 NOTAMs (expandable)

**Data Source:** FAA NOTAM API (`POST notams.aim.faa.gov/notamSearch/search`)
**Existing Backend:** `weather.service.ts` NOTAM endpoint (caches 30min)

All NOTAM subsections share a common display pattern:
- **Plain Text toggle** (top-right) — switches between decoded and raw NOTAM format
- NOTAMs grouped by category within each subsection
- Each NOTAM shows: Issuing facility, NOTAM number, and text

#### 3.5.1 Departure NOTAMs

**Query:** NOTAMs for departure airport identifier
**Categories displayed:**
- **Navigation** — ILS, VOR, localizer out of service/unmonitored
- **Communication** — COM/NAV frequency changes or outages
- **Service** — Services (SMR, ATIS, radar) outages
- **Obstruction Within 10 NM** — Cranes, towers, rigs near the airport with height AGL, coordinates, lit/flagged status

#### 3.5.2 Destination NOTAMs

**Query:** NOTAMs for destination airport identifier
**Categories:** Same as Departure (Navigation, Communication, Service, Obstruction Within 10 NM)

#### 3.5.3 Alternate 1 / Alternate 2 NOTAMs

**Query:** NOTAMs for alternate airport identifier(s) if specified on the flight
**Categories:** Same as Departure. Greyed out in nav if no alternate specified.

#### 3.5.4 Enroute NOTAMs (expandable)

**Query:** NOTAMs for airports, navaids, and fixes along the route, plus airports within a corridor of the route
**Subsections:**

| Subsection | Description | NOTAM Keywords |
|------------|-------------|----------------|
| **Navigation** | VOR, VORTAC, DME, ILS out of service or unmonitored along route | NAV |
| **Communication** | COM remote outlets, frequencies affected | COM |
| **SVC** | Tower closures, radar/SSR, weather broadcast systems, ATIS | SVC |
| **Airspace** | Airspace modifications, UAS activity areas, aerobatic areas | AIRSPACE |
| **Special Use Airspace** | MOAs, restricted areas, prohibited areas status changes | SUA |
| **Rwy/Twy/Apron/AD/FDC** | SID/STAR/approach amendments (FDC NOTAMs), runway/taxiway closures at enroute airports, ODP changes | RWY, TWY, APRON, AD, FDC |
| **Other/Unverified** | Obstruction NOTAMs, catch-all for uncategorized NOTAMs | OBST, other |

#### 3.5.5 ARTCC NOTAMs

**Query:** NOTAMs for ARTCC facilities the route passes through (e.g., KZDV, KZLA)
**Identification:** Determine which ARTCCs the route traverses using ARTCC boundary data (already seeded in DB)
**Content:** COM outlet outages, weather broadcast system status, airspace activations, military route activations

---

## 4. Cross-Cutting Features

### 4.1 Passing Time Calculation

A critical feature that makes the briefing actionable: for each hazard along the route, calculate when the flight will pass through or near it.

**Logic:**
1. From the flight's route, ETD, and groundspeed per leg (already computed by CalculateService), determine the time the aircraft will be at each point along the route.
2. For each TFR, AIRMET, SIGMET — intersect the advisory's polygon with the route corridor.
3. Compute the time window when the aircraft will be within or near the advisory area.
4. Compare that window against the advisory's validity period.
5. Label as:
   - **ACTIVE DURING PASSING TIME** — advisory is valid when the flight passes through
   - **INACTIVE DURING PASSING TIME** — advisory expires before or starts after the flight passes
   - **ACTIVE NEAR PASSING TIME** — advisory is valid near (within ~30 min) the flight's passing

### 4.2 Unread Tracking

- Each section in the sidebar shows an orange dot if it contains items the user hasn't viewed.
- The header shows a total unread count (e.g., "24 unread sections").
- Selecting a section marks it as read.
- Counter decrements as the user reviews each section.
- Stored per-briefing in local state (not persisted to server).

### 4.3 Section Navigation

- **NEXT: [Section Name]** footer at the bottom of the detail panel allows sequential reading through the entire briefing.
- **Previous/Next arrows** (`<` `>`) flank the NEXT label.
- Clicking navigates to the next section in briefing order.
- "Return to Beginning" shown on the last section.

### 4.4 Plain Text Toggle

Available on METARs, TAFs, and all NOTAM sections:
- **OFF** (default): Show decoded/translated presentation
- **ON**: Show raw FAA text exactly as published

### 4.5 Map Visualization

Many sections include a map showing the item's geographic context:
- **Flight route** always shown as a magenta/pink line
- **Waypoint labels** along the route with ETA times (e.g., `0358Z`, `0419Z`)
- **Advisory polygons** shown as red outlines
- **TFR polygons** shown as red outlines with TFR icon badge
- **PIREP locations** shown as point markers
- **METAR/TAF stations** shown as colored dots (flight category colors)
- Map is interactive (pan/zoom) using Mapbox

---

## 5. Data Requirements Summary

### 5.1 New Backend Endpoint

A single aggregated briefing endpoint that fetches all data for a flight:

```
GET /api/flights/:flightId/briefing
```

**Response structure:**
```json
{
  "flight": { /* flight summary: route, altitude, ETD, ETE, ETA, aircraft */ },
  "adverseConditions": {
    "tfrs": [ /* TFRs along route with polygons */ ],
    "closedUnsafeNotams": [ /* closure NOTAMs for dep/dest */ ],
    "convectiveSigmets": [ /* convective SIGMETs along route */ ],
    "sigmets": [ /* SIGMETs along route */ ],
    "airmets": {
      "ifr": [],
      "mountainObscuration": [],
      "icing": [],
      "turbulenceLow": [],
      "turbulenceHigh": [],
      "lowLevelWindShear": [],
      "other": []
    },
    "urgentPireps": [ /* UUA PIREPs along route */ ]
  },
  "synopsis": {
    "surfaceAnalysisUrl": "string"
  },
  "currentWeather": {
    "metars": [ /* METARs for dep, route, dest stations */ ],
    "pireps": [ /* all PIREPs along route */ ]
  },
  "forecasts": {
    "gfaCloudProducts": [ /* GFA cloud URLs by region/time */ ],
    "gfaSurfaceProducts": [ /* GFA surface URLs by region/time */ ],
    "tafs": [ /* TAFs for dep, route, dest stations */ ],
    "windsAloftTable": {
      "waypoints": [ /* waypoint labels */ ],
      "altitudes": [ /* altitude columns */ ],
      "filedAltitude": 28000,
      "data": [ /* direction/speed/temp per waypoint per altitude */ ]
    }
  },
  "notams": {
    "departure": { /* categorized NOTAMs */ },
    "destination": { /* categorized NOTAMs */ },
    "alternate1": { /* categorized NOTAMs or null */ },
    "alternate2": { /* categorized NOTAMs or null */ },
    "enroute": {
      "navigation": [],
      "communication": [],
      "svc": [],
      "airspace": [],
      "specialUseAirspace": [],
      "rwyTwyApronAdFdc": [],
      "otherUnverified": []
    },
    "artcc": []
  }
}
```

### 5.2 Existing Data Sources (Already Integrated)

| Data | Backend Location | Status |
|------|-----------------|--------|
| METARs | `weather.service.ts` | Ready — AWC API, 5-min cache |
| TAFs | `weather.service.ts` | Ready — AWC API, 5-min cache |
| NOTAMs | `weather.service.ts` | Ready — FAA NOTAM API, 30-min cache |
| PIREPs | `weather.service.ts` / `imagery.service.ts` | Ready — AWC API |
| AIRMETs/SIGMETs | `imagery.service.ts` | Ready — AWC GeoJSON API |
| TFRs | `weather.service.ts` | Ready — FAA GeoServer WFS + JSON API |
| Winds Aloft | `weather.service.ts` + `windy.service.ts` | Ready — AWC + Open-Meteo |
| Wind Grid Data | `windy.service.ts` | Ready — Open-Meteo GFS |
| GFA Products | `imagery.service.ts` | Ready — AWC static images |
| Surface Analysis | `imagery.service.ts` | Ready — AWC/NWS static image |
| Route Calculation | `calculate.service.ts` | Ready — distance, ETE, waypoints, groundspeed per leg |
| ARTCC Boundaries | DB (seeded from CIFP) | Ready — can determine which ARTCCs a route passes through |
| Terrain Elevation | `windy.service.ts` elevation | Ready — SRTM data |

### 5.3 New Work Required

| Component | Description | Complexity |
|-----------|-------------|------------|
| **Briefing Aggregation Service** | New `BriefingService` that orchestrates parallel fetches of all data sources for a flight, applies route corridor filtering, computes passing times, categorizes NOTAMs | High |
| **Route Corridor Geometry** | Utility to compute a polygon corridor (e.g., 50nm buffer) around the route for spatial filtering of advisories/TFRs/PIREPs | Medium |
| **Passing Time Calculator** | Given route waypoints with ETAs + advisory polygon, compute when the flight intersects the advisory area | Medium |
| **NOTAM Categorizer** | Parse NOTAM keyword field to bucket into Navigation, Communication, SVC, Airspace, etc. | Medium |
| **ARTCC Route Lookup** | Given a route's waypoints, determine which ARTCC boundaries are crossed | Low |
| **Wind Chart Rendering** | Server-side or client-side rendering of wind barbs + temperatures on a map at a given altitude | High |
| **Vertical Cross Section Rendering** | Chart combining winds, turbulence EDR, icing severity, terrain, and flight path along the route | Very High |
| **Winds Aloft Table Generator** | Fetch winds at multiple altitudes for each waypoint along the route | Medium |
| **GFA Region Selector** | Determine which GFA regions (Central, Southwest, West, etc.) the route passes through | Low |
| **Flutter Briefing UI** | Three-panel layout with section tree, list panel, detail panel, maps, charts | Very High |

---

## 6. Implementation Phases

### Phase 1 — Core Briefing (MVP)
Text-heavy sections that can be built with existing data:
- Briefing layout (sidebar + list + detail)
- NOTAMs (Departure, Destination, Enroute, ARTCC) with categorization
- METARs with route map and flight category dots
- TAFs with route map
- TFRs with map polygons
- Synopsis (Surface Analysis Chart image)
- Unread tracking + sequential navigation

### Phase 2 — Advisories & Winds
- AIRMETs (all subtypes) with map polygons and passing time
- SIGMETs and Convective SIGMETs
- Closed/Unsafe NOTAMs
- PIREPs (all + urgent) with map
- Winds Aloft Table
- GFA Cloud Coverage and Surface products
- Passing time calculations

### Phase 3 — Advanced Charts
- Wind Chart (wind barbs on map at altitude)
- Vertical Cross Section Chart (multi-layer composite)
- Plain Text toggle for all supported sections
- Alternate 1/2 NOTAMs

---

## 7. Mobile Adaptation Notes

On mobile (phone-sized screens), the three-panel layout must adapt:

- **Sidebar** becomes a collapsible bottom sheet or slide-out drawer
- **List + Detail** use push navigation (list → detail with back button)
- Maps should be full-width and at least 250pt tall
- Charts (Wind Chart, Vertical Cross Section) should support landscape rotation for readability
- The "NEXT" sequential navigation becomes especially important on mobile for guided reading

---

## 8. Screenshots Reference

ForeFlight briefing screenshots are stored in `docs/screenshots/flight-briefing/` for visual reference during implementation.
