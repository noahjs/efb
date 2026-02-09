# Maps: Aeronautical Layer
## EFB Design Document

[← Back to Maps Module](maps.md)

---

The Aeronautical layer is a vector-based map overlay that renders airspace boundaries, airways, navaids, fixes/waypoints, and ATC boundaries directly on the map. Unlike raster chart layers (VFR Sectional, IFR Enroute), the aeronautical layer is data-driven — drawn from FAA NASR data stored in our database and rendered as GeoJSON on the Mapbox map.

## 1. Layer Picker Integration

### Position in Layer Picker
The "Aeronautical" option sits **above** the base layer list in the left column of the layer picker, separated by a divider. It is a toggle (on/off) independent of the base layer selection. When active, vector aeronautical data is drawn on top of whatever base layer is selected.

```
┌──────────────────┬──────────────────┐
│  ☑ Aeronautical  │  Overlays...     │
│  ───────────────  │                  │
│  ○ VFR Sectional │                  │
│  ● Satellite     │                  │
│  ○ Street        │                  │
└──────────────────┴──────────────────┘
```

### Sidebar Aero Controls
When the aeronautical layer is active, the left sidebar gains a vertical stack of icon buttons (matching the ForeFlight sidebar). Each icon toggles a sub-category of aeronautical data. The icons from top to bottom:

| Icon | Category | What it controls |
|------|----------|-----------------|
| Gear/Filter | Aeronautical Settings | Opens the full Aeronautical Settings panel |
| Target/Eye | Airspace visibility | Master toggle for all airspace polygons |
| Triangle | Waypoints/Fixes | Toggle waypoint symbols on map |
| Shield | Special Use Airspace | Toggle MOA, Restricted, Prohibited areas |
| Horizontal lines | Airways | Toggle airway lines (V-routes, J-routes) |
| Gate/Waypoint | Navaids | Toggle VOR, NDB, VORTAC symbols |
| Mountain | Terrain awareness | Terrain/obstacle awareness shading |
| Speed limit | Speed restrictions | Speed restriction areas (Class B/C) |

Below the icons, three mode selectors:
- **High IFR** — Emphasizes jet routes, high-altitude waypoints
- **Low IFR** — Emphasizes victor airways, low-altitude waypoints, MEAs
- **VFR** — Emphasizes VFR waypoints, landmarks, visual references

At the bottom: **"..."** overflow menu for additional settings.

---

## 2. Data Sources & Seeding

All data comes from the FAA NASR 28-day subscription, which we already download in our seed pipeline. The relevant files:

### 2a. Airspace Boundaries (Class B/C/D/E)
- **Source:** `Additional_Data/Shape_Files/Class_Airspace.shp` (5,608 polygons)
- **Format:** ESRI Shapefile with 3D polygons (NAD83/EPSG:4269)
- **Key fields:** `IDENT`, `NAME`, `CLASS` (B/C/D/E), `TYPE_CODE`, `UPPER_VAL`, `UPPER_UOM`, `LOWER_VAL`, `LOWER_UOM`, `LEVEL`, `MIL_CODE`
- **Seed approach:** Convert shapefile to GeoJSON at seed time using `ogr2ogr` or a Node shapefile parser (e.g. `shapefile` npm package). Store as rows in an `airspaces` table with a `geometry` column (PostGIS) or as a pre-built GeoJSON file served statically.

**Recommended: PostGIS approach.** Add the PostGIS extension, store polygons as `geometry(Polygon, 4326)`. This enables spatial queries (e.g. "which airspaces intersect this bounding box?") efficiently.

### 2b. Special Use Airspace (MOA, Restricted, Prohibited, Warning, Alert)
- **Source:** `Additional_Data/AIXM/SAA-AIXM_5_Schema/SaaSubscriberFile.zip` → `Saa_Sub_File.zip` (AIXM 5.1 XML)
- **Types:** Restricted (R-xxxx), Prohibited (P-xxxx), MOA, Warning (W-xxxx), Alert (A-xxxx), Training, Caution/Danger, TRA/TSA, Parachute areas, ADIZ
- **Key data:** Polygon boundaries, altitude limits, activation schedule, NOTAM-based activation
- **Seed approach:** Parse AIXM XML, extract polygon coordinates and metadata. Store in same `airspaces` table with `type` discriminator.

### 2c. Airways
- **Source:** `CSV_Data/AWY_BASE.csv` (1,516 airways) + `CSV_Data/AWY_SEG_ALT.csv` (segment details)
- **Key fields:** `AWY_ID` (e.g. V97, J80), `AWY_LOCATION` (C=CONUS), segment FROM/TO points with lat/lng, MEA, MOCA, distances
- **Format:** Airways are sequences of connected waypoints/navaids. Each row in AWY_SEG_ALT is one segment.
- **Seed approach:** Store airway segments in an `airway_segments` table. Join to fixes/navaids for coordinates. Build LineString geometries at query time or pre-compute.

### 2d. ARTCC/FIR Boundaries
- **Source:** `CSV_Data/ARB_BASE.csv` (ARTCC centers) + `CSV_Data/ARB_SEG.csv` (2,687 boundary segments)
- **Key fields:** `LOCATION_ID` (e.g. ZDV), `ALTITUDE` (HIGH/LOW), `TYPE` (ARTCC), boundary point lat/lng sequence
- **Seed approach:** Group segments by LOCATION_ID + ALTITUDE, build polygon from sequential points. Store in `artcc_boundaries` table.

### 2e. Navaids (already seeded)
- **Source:** `CSV_Data/NAV_BASE.csv` — already imported into `navaids` table
- **Types:** VOR, VORTAC, VOR/DME, NDB, TACAN, DME
- **Rendering:** Different icon per type, with identifier and frequency label

### 2f. Fixes/Waypoints (already seeded)
- **Source:** `CSV_Data/FIX_BASE.csv` — already imported into `fixes` table
- **Rendering:** Small triangle or diamond marker with identifier label

---

## 3. Database Schema (New Tables)

### `airspaces`
```sql
CREATE TABLE airspaces (
  id            SERIAL PRIMARY KEY,
  identifier    VARCHAR(50) NOT NULL,     -- e.g. 'DEN', 'R-2601A'
  name          VARCHAR(200),
  class         VARCHAR(10),              -- 'B', 'C', 'D', 'E', or NULL for SUA
  type          VARCHAR(50) NOT NULL,     -- 'CLASS', 'RESTRICTED', 'PROHIBITED', 'MOA', 'WARNING', 'ALERT', 'PARACHUTE', 'ADIZ', etc.
  lower_alt     INTEGER,                  -- feet MSL (0 = surface)
  upper_alt     INTEGER,                  -- feet MSL
  lower_code    VARCHAR(20),              -- 'SFC', 'MSL', 'AGL'
  upper_code    VARCHAR(20),              -- 'MSL', 'FL'
  geometry      GEOMETRY(Polygon, 4326),  -- PostGIS polygon
  center_lat    FLOAT,                    -- centroid for quick bbox queries
  center_lng    FLOAT,
  military      BOOLEAN DEFAULT FALSE,
  schedule      TEXT                       -- activation schedule or NOTAM reference
);

CREATE INDEX idx_airspaces_geometry ON airspaces USING GIST (geometry);
CREATE INDEX idx_airspaces_class ON airspaces (class);
CREATE INDEX idx_airspaces_type ON airspaces (type);
```

### `airway_segments`
```sql
CREATE TABLE airway_segments (
  id              SERIAL PRIMARY KEY,
  airway_id       VARCHAR(20) NOT NULL,    -- e.g. 'V97', 'J80'
  sequence        INTEGER NOT NULL,
  from_fix        VARCHAR(20),
  to_fix          VARCHAR(20),
  from_lat        FLOAT,
  from_lng        FLOAT,
  to_lat          FLOAT,
  to_lng          FLOAT,
  min_enroute_alt INTEGER,                 -- MEA in feet
  moca            INTEGER,                 -- MOCA in feet
  distance_nm     FLOAT,
  airway_type     VARCHAR(10)              -- 'V' (victor/low), 'J' (jet/high), 'T' (RNAV low), 'Q' (RNAV high)
);

CREATE INDEX idx_airway_segments_airway ON airway_segments (airway_id);
```

### `artcc_boundaries`
```sql
CREATE TABLE artcc_boundaries (
  id            SERIAL PRIMARY KEY,
  artcc_id      VARCHAR(10) NOT NULL,     -- e.g. 'ZDV'
  name          VARCHAR(100),
  altitude      VARCHAR(10),              -- 'HIGH' or 'LOW'
  geometry      GEOMETRY(Polygon, 4326),
  center_lat    FLOAT,
  center_lng    FLOAT
);

CREATE INDEX idx_artcc_geometry ON artcc_boundaries USING GIST (geometry);
```

---

## 4. API Endpoints

### `GET /api/airspaces/bounds`
Returns airspaces intersecting a bounding box.
```
?minLat=39&maxLat=40&minLng=-105&maxLng=-104
&types=CLASS,RESTRICTED,MOA    (optional filter)
&classes=B,C,D                  (optional filter)
```
Response: GeoJSON FeatureCollection with airspace polygons and properties.

### `GET /api/airways/bounds`
Returns airway segments within a bounding box.
```
?minLat=39&maxLat=40&minLng=-105&maxLng=-104
&types=V,J                      (optional: victor, jet, RNAV)
```
Response: GeoJSON FeatureCollection with LineString segments.

### `GET /api/navaids/bounds` (exists)
Already implemented — returns navaids within bounds.

### `GET /api/navaids/fixes/bounds` (exists)
Already implemented — returns fixes within bounds.

### `GET /api/artcc/bounds`
Returns ARTCC boundaries intersecting a bounding box.
Response: GeoJSON FeatureCollection with polygon boundaries.

---

## 5. Frontend Rendering

### Map Layers (Mapbox)
Each aeronautical feature category maps to one or more Mapbox source + layer pairs:

| Category | Source Type | Layer Type | Style |
|----------|-----------|------------|-------|
| Class B airspace | GeoJSON | fill + line | Blue fill (10% opacity), solid blue border (2px) |
| Class C airspace | GeoJSON | fill + line | Magenta fill (10% opacity), solid magenta border (2px) |
| Class D airspace | GeoJSON | fill + line | Blue dashed border (1.5px), no fill |
| Class E airspace | GeoJSON | fill + line | Magenta dashed border (1px), subtle fill |
| Restricted/Prohibited | GeoJSON | fill + line | Red hatched fill, red border |
| MOA | GeoJSON | fill + line | Pink/magenta hatched fill |
| Warning/Alert | GeoJSON | fill + line | Orange/yellow border |
| Victor airways | GeoJSON | line | Light blue lines (1px) |
| Jet airways | GeoJSON | line | Dark blue lines (1px) |
| ARTCC boundaries | GeoJSON | line | Gray dashed lines (1px) |
| Navaids | GeoJSON | symbol | Icon per type (VOR compass rose, NDB circle, etc.) |
| Fixes | GeoJSON | symbol | Small cyan triangle + identifier label |

### Data Loading Strategy
- Fetch aeronautical data on map bounds change (debounced, same pattern as airport dots)
- Cache aggressively — airspace boundaries don't change within a 28-day cycle
- At low zoom levels, only show Class B/C and major airways to avoid clutter
- Progressive detail: more features appear as user zooms in

### Frontend Providers (Riverpod)
```dart
// Airspace boundaries for current map bounds
final mapAirspacesProvider = FutureProvider.family<...>((ref, bounds) => ...);

// Airway segments for current map bounds
final mapAirwaysProvider = FutureProvider.family<...>((ref, bounds) => ...);

// Navaids in bounds (already exists)
// Fixes in bounds (already exists via navaids service)
```

---

## 6. Aeronautical Settings Panel

Opened from the gear icon in the aero sidebar. Slides down like existing settings panels. Full scrollable list of toggles organized by section:

### MAP DISPLAY SETTINGS
- Map Theme → Dark (nav)
- Terrain → Colored (nav)
- Cultural Elements → All (nav)
- Place Labels → toggle + text size slider

### AIRPORT SETTINGS
- Heliports → toggle (default OFF)
- Private Airports → toggle (default ON)
- Seaplane Bases → toggle (default OFF)
- Other Fields → toggle (default ON)
- Min. Rwy Length → picker (None, 2000', 3000', 4000', 5000')

### AIRSPACE SETTINGS
- Auto Highlight → toggle (highlight airspace near ownship altitude)
- Hide Airspace Above (FT) → picker (Show All, FL180, FL100, etc.)
- Activation by NOTAM → toggle
- Controlled Airspace → toggle (master)
  - TRSA → toggle (sub-item)
  - Class E → toggle (sub-item)
  - Mode C → toggle (sub-item)
- Special Use Airspace → toggle (master)
  - Prohibited & Restricted → toggle
  - MOA, Alert, & Training → toggle
  - Caution, Danger, & Warning → toggle
  - TRA & TSA → toggle
  - Parachute Areas (USA) → toggle
  - ADIZ → toggle
  - Other → toggle
- Worldwide Altitudes → toggle

### AIRWAY SETTINGS
- Airways → toggle (master)
  - Low → toggle (victor routes)
  - Helicopter → toggle
- (High airways shown only in High IFR mode)

### WAYPOINT SETTINGS
- Waypoints → toggle (master)
  - Fixes & RNAV → toggle
  - VFR Waypoints → toggle
  - VFR Helicopter Waypoints → toggle

### ATC BOUNDARY SETTINGS
- ATC Boundaries → toggle (master)
  - ARTCC/FIRs → toggle
  - ATC Sectors → toggle

### ORGANIZED TRACKS SETTINGS
- Show Organized Tracks → toggle (default OFF)

### GRID MORA/LSALT SETTINGS
- Grid MORA/LSALT (ft) → toggle (default OFF)

---

## 7. Implementation Phases

### Phase 1: Infrastructure
1. Add PostGIS extension to Postgres (docker-compose + TypeORM config)
2. Create `airspaces`, `airway_segments`, `artcc_boundaries` entities
3. Write seed scripts to parse shapefile + CSV data into new tables
4. Create API endpoints with spatial queries

### Phase 2: Frontend Layer System
1. Add "Aeronautical" toggle to layer picker (above base layers, with divider)
2. Create providers to fetch airspace/airway data by bounds
3. Render airspace polygons as Mapbox fill+line layers
4. Render airways as Mapbox line layers
5. Render navaids and fixes as Mapbox symbol layers (using existing data)

### Phase 3: Sidebar & Settings
1. Build aeronautical sidebar icon column (appears when aero layer active)
2. Build Aeronautical Settings panel (full scrollable settings sheet)
3. Wire toggle state to show/hide individual Mapbox layers
4. Persist settings locally (SharedPreferences)

### Phase 4: Polish
1. Zoom-dependent decluttering (hide detail at low zoom)
2. Altitude filtering (hide airspace above/below relevant altitude)
3. Airspace labels and altitude annotations
4. High IFR / Low IFR / VFR mode switching (changes which data emphasis)
5. Tap-to-inspect airspace (show name, altitudes, schedule)

---

## 8. Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Airspace storage | PostGIS geometry column | Enables `ST_Intersects` spatial queries for efficient bounds-based fetching |
| Shapefile parsing | `shapefile` npm package or `ogr2ogr` CLI | Both work; npm package avoids system dependency |
| SUA parsing | Custom AIXM XML parser | SAA data only available as AIXM 5.1 XML |
| Frontend rendering | Mapbox GeoJSON sources + layers | Consistent with existing airport/route rendering pattern |
| Settings persistence | SharedPreferences (Flutter) | Simple key-value storage for toggle states |
| Data refresh | Re-seed every 28 days (NASR cycle) | Same schedule as airport data |

---

## 9. Dependencies

- **PostGIS** — PostgreSQL extension for spatial queries (`CREATE EXTENSION postgis;`)
- **shapefile** (npm) — Parse ESRI shapefiles in Node.js (for seed script)
- **xml2js** or **fast-xml-parser** (npm) — Parse AIXM XML for SUA data
- No new Flutter dependencies needed (Mapbox SDK already supports GeoJSON layers)

---

## Implementation Status

### Built

**Backend:**
- `AirspacesModule` — `airspaces` table with PostGIS geometry. Seeded from FAA NASR shapefiles (Class B/C/D/E) and AIXM XML (MOA, Restricted, Prohibited). `GET /api/airspaces/bounds` endpoint with spatial queries.
- `AirwaysModule` — `airway_segments` table seeded from NASR CSV (AWY_BASE + AWY_SEG_ALT). Victor and Jet routes. `GET /api/airways/bounds` endpoint.
- `NavaidsModule` — `navaids` table seeded from NASR. `GET /api/navaids/bounds` endpoint. VOR, VORTAC, NDB, DME types.
- `FixesModule` — `fixes` table seeded from NASR. `GET /api/navaids/fixes/bounds` endpoint.

**Mobile:**
- Aeronautical toggle in layer picker (above base layers, with divider)
- Airspace polygons rendered as Mapbox fill+line layers, color-coded by class
- Airways rendered as Mapbox line layers
- Navaids rendered as Mapbox symbol layers with type icons
- Fixes rendered as Mapbox symbol layers with identifier labels
- Data fetched on map bounds change (debounced)
- Tap-to-inspect: bottom sheets for navaids and fixes with details and actions (Direct To, Add to Route)

### Not Started

| Feature | Notes |
|---------|-------|
| ARTCC/FIR Boundaries | NASR ARB data available, `artcc_boundaries` table not created |
| Aeronautical sidebar icon column | Full sidebar with sub-category toggles |
| Aeronautical Settings panel | Full scrollable settings sheet |
| High IFR / Low IFR / VFR mode switching | Mode-based data emphasis |
| Zoom-dependent decluttering | Progressive detail by zoom level |
| Altitude filtering | Hide airspace above/below relevant altitude |
| Airspace labels and altitude annotations | Display altitude ranges on airspace polygons |
