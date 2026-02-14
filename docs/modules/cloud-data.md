# HRRR Weather Data Pipeline — Implementation Design
## EFB Product Specification

[← Back to Imagery Module](./imagery.md)

---

## Overview

A unified pipeline that ingests HRRR (High-Resolution Rapid Refresh) model data directly from NOAA, processing it into map tiles and grid point values for multiple weather products. One GRIB2 download per cycle produces:

| Product | Map Tiles | Grid Values | Replaces |
|---------|-----------|-------------|----------|
| **Cloud coverage** (by altitude) | Yes | Yes | New capability |
| **Forecast flight category** (ceiling + visibility) | Yes | Yes | New capability |
| **Winds aloft** (by altitude) | No (arrows, not areas) | Yes | Open-Meteo (keep both for comparison) |
| **Temperature** (by altitude) | No | Yes | Open-Meteo (keep both for comparison) |

The existing `WindGridPoller` (Open-Meteo) remains active for comparison. Once HRRR wind data is validated against Open-Meteo, the Open-Meteo poller can be retired.

---

## Priority

**P1 — High.** Cloud coverage at altitude is the primary driver. Winds/temperature/ceiling come essentially free from the same GRIB2 files.

## User Stories

### Cloud Coverage
- As a pilot, I want to see cloud coverage at my planned cruise altitude on the map so I can evaluate whether I'll be in IMC.
- As a pilot, I want to slide between altitudes to find a clear altitude for my route.
- As a pilot, I want to see forecasted cloud coverage along my route at each waypoint so I can brief expected conditions.
- As a pilot, I want a route cross-section view showing cloud layers at all altitudes along my flight path so I can pick the best altitude.

### Forecast Flight Category
- As a pilot, I want to see a map overlay showing forecast IFR/MVFR/VFR areas so I can plan my departure time.
- As a pilot, I want to see the predicted ceiling and visibility at my destination at my ETA so I can evaluate whether I'll need an alternate.

### Winds & Temperature
- As a pilot, I want HRRR-resolution (3 km) winds aloft data for more accurate flight planning than the current GFS-based winds.
- As a pilot, I want forecast temperature at altitude for icing assessment and performance planning.

---

## 1. Data Source: NOAA HRRR

### Why Direct GRIB Ingestion

Cloud coverage requires **area visualization** (filled map overlays), not point data. Since server-side GRIB2 processing is required for tile rendering, we extract all useful variables in the same pass — clouds, wind, temperature, ceiling, and visibility. This eliminates the Open-Meteo dependency (aggressive 429 rate limiting, ScrapingBee proxy cost) while providing higher resolution (3 km vs blended).

### HRRR Model Summary

| Attribute | Value |
|-----------|-------|
| Resolution | 3 km (1799 × 1059 grid) |
| Domain | CONUS |
| Cycles | Every hour (24/day), init times 00z–23z |
| Forecast range | F00–F18 (standard), F00–F48 (at 00/06/12/18z) |
| S3 availability | ~45–90 min after init time |
| S3 bucket | `noaa-hrrr-bdp-pds` (public, us-east-1, no auth) |
| Surface file size | ~150 MB per forecast hour (`wrfsfcf`) |
| Pressure file size | ~400 MB per forecast hour (`wrfprsf`) |

### Variables to Extract

#### From `wrfsfcf` (2D surface file)

| Variable | Level | Description | Used For |
|----------|-------|-------------|----------|
| `TCDC` | entire atmosphere | Total cloud cover (%) | Cloud tiles + grid |
| `LCDC` | low cloud layer | Low cloud cover, SFC–6,500 ft (%) | Cloud tiles + grid |
| `MCDC` | middle cloud layer | Mid cloud cover, 6,500–20,000 ft (%) | Cloud tiles + grid |
| `HCDC` | high cloud layer | High cloud cover, 20,000+ ft (%) | Cloud tiles + grid |
| `HGT` | cloud ceiling | Cloud ceiling height (gpm) | Flight category tiles + grid |
| `HGT` | cloud base | Cloud base height (gpm) | Grid |
| `HGT` | cloud top | Cloud top height (gpm) | Grid |
| `VIS` | surface | Visibility (m) | Flight category tiles + grid |
| `UGRD` | 10 m above ground | U-component of wind (m/s) | Grid (surface wind) |
| `VGRD` | 10 m above ground | V-component of wind (m/s) | Grid (surface wind) |
| `TMP` | 2 m above ground | Surface temperature (K) | Grid |
| `GUST` | surface | Wind gust (m/s) | Grid |

#### From `wrfprsf` (3D pressure-level file)

Extract at pressure levels: **1000, 925, 850, 700, 500, 400, 300, 250, 200 hPa**

| Variable | Description | Used For |
|----------|-------------|----------|
| `TCDC` | Cloud cover at pressure level (%) | Cloud tiles + grid |
| `UGRD` | U-component of wind (m/s) | Grid (winds aloft) |
| `VGRD` | V-component of wind (m/s) | Grid (winds aloft) |
| `TMP` | Temperature (K) | Grid (temp aloft) |

### Pressure Level → Altitude Mapping

Reuses existing `WINDS.LEVEL_ALTITUDES` from `constants.ts`:

| Pressure (hPa) | Approx Altitude (ft MSL) |
|-----------------|--------------------------|
| 1000 | 360 |
| 925 | 2,500 |
| 850 | 5,000 |
| 700 | 10,000 |
| 500 | 18,000 |
| 400 | 24,000 |
| 300 | 30,000 |
| 250 | 34,000 |
| 200 | 39,000 |

### Download Strategy: S3 Byte-Range Reads

Every HRRR GRIB2 file on S3 has a companion `.idx` index file listing each GRIB message with its byte offset. We parse the `.idx` to identify just the variables we need, then do HTTP Range requests to download only those records.

**Index file format:**
```
1:0:d=2026021312:REFC:entire atmosphere:1 hour fcst:
...
112:79645435:d=2026021312:TCDC:boundary layer cloud layer:1 hour fcst:
113:80290340:d=2026021312:LCDC:low cloud layer:1 hour fcst:
114:81043487:d=2026021312:MCDC:middle cloud layer:1 hour fcst:
115:81419870:d=2026021312:HCDC:high cloud layer:1 hour fcst:
116:81802041:d=2026021312:TCDC:entire atmosphere:1 hour fcst:
117:82562953:d=2026021312:HGT:cloud ceiling:1 hour fcst:
```

**Byte-range extraction** downloads only the needed GRIB messages:
```bash
# Download just cloud variables from wrfsfcf (~8 MB instead of 150 MB)
curl -o cloud_vars.grib2 --range 79645435-88400000 \
  https://noaa-hrrr-bdp-pds.s3.amazonaws.com/hrrr.20260213/conus/hrrr.t12z.wrfsfcf01.grib2
```

**Estimated download sizes per forecast hour:**

| File | Full Size | After byte-range extraction |
|------|-----------|----------------------------|
| `wrfsfcf` (clouds, ceiling, vis, sfc wind) | ~150 MB | ~15 MB |
| `wrfprsf` (pressure-level cloud, wind, temp) | ~400 MB | ~40 MB |
| **Total per forecast hour** | **~550 MB** | **~55 MB** |
| **Total for 6 forecast hours** | **~3.3 GB** | **~330 MB** |

---

## 2. Processing Pipeline

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│  HrrrPoller (NestJS, runs every 60 min)                                 │
│                                                                         │
│  STAGE 1: DISCOVERY                                                     │
│  ├── Determine latest HRRR cycle on S3 (current UTC hour - 2)          │
│  ├── Check .idx file exists for wrfsfcf + wrfprsf                      │
│  ├── Create HrrrCycle record: status='discovered'                      │
│  └── Skip if this init_time already has a cycle record                 │
│                                                                         │
│  STAGE 2: DOWNLOAD                           cycle.status='downloading' │
│  ├── Update: download_started_at, download_total=6                     │
│  ├── For each forecast hour (F01–F06):                                 │
│  │   ├── Download wrfsfcf .idx → parse byte ranges                     │
│  │   ├── Download wrfprsf .idx → parse byte ranges                     │
│  │   ├── Byte-range GET from S3 (~55 MB per hour)                      │
│  │   ├── On success: download_completed++, download_bytes += size      │
│  │   └── On failure: download_failed++, last_error = msg               │
│  └── Update: download_completed_at                                     │
│                                                                         │
│  STAGE 3: PROCESSING                         cycle.status='processing' │
│  ├── Update: process_started_at, process_total=6                       │
│  ├── For each forecast hour:                                           │
│  │   ├── Invoke process-hrrr.py via child_process.execFile()           │
│  │   ├── Python decodes GRIB2, outputs grid JSON to stdout             │
│  │   ├── On success: process_completed++                               │
│  │   └── On failure: process_failed++, last_error = msg                │
│  └── Update: process_completed_at                                      │
│                                                                         │
│  STAGE 4: GRID INGEST                        cycle.status='ingesting'  │
│  ├── For each forecast hour's grid JSON:                               │
│  │   ├── Bulk insert into a_hrrr_surface (9,720 rows total)           │
│  │   ├── Bulk insert into a_hrrr_pressure (87,480 rows total)         │
│  │   └── Update: ingest_surface_rows, ingest_pressure_rows            │
│  └── Update: ingest_completed_at                                       │
│                                                                         │
│  STAGE 5: TILE GENERATION              cycle.status='generating_tiles' │
│  ├── Update: tiles_started_at                                          │
│  ├── For each forecast hour:                                           │
│  │   ├── Invoke process-hrrr.py --tiles (or second pass)               │
│  │   ├── Writes PNGs to data/hrrr/tiles/{init_time}/...               │
│  │   ├── Insert HrrrTileMeta rows for each product/level              │
│  │   ├── On success: tiles_completed++, tiles_count += count           │
│  │   └── On failure: tiles_failed++                                    │
│  └── Update: tiles_completed_at                                        │
│                                                                         │
│  STAGE 6: ACTIVATION                         cycle.status='active'     │
│  ├── In a single transaction:                                          │
│  │   ├── Old cycle: is_active=false, status='superseded'               │
│  │   └── New cycle: is_active=true, status='active', activated_at=now  │
│  ├── Update DataSource record (last_completed_at, records_updated)     │
│  └── Calculate total_duration_ms                                       │
│                                                                         │
│  STAGE 7: CLEANUP (background, after activation)                       │
│  ├── Delete a_hrrr_surface rows where init_time is superseded >3h     │
│  ├── Delete a_hrrr_pressure rows where init_time is superseded >3h    │
│  ├── Delete a_hrrr_tile_meta rows for superseded cycles               │
│  └── Delete tile directories for superseded cycles                     │
└─────────────────────────────────────────────────────────────────────────┘
```

### Admin Dashboard Integration

Register as a DataSource in the scheduler (alongside existing pollers):

```typescript
{ key: 'hrrr_poll', name: 'HRRR Weather Pipeline (NOAA S3)', interval_seconds: 3600 }
```

The `DataSource` record shows high-level status (idle/running/failed) in the existing admin dashboard. For detailed pipeline visibility, the admin dashboard queries `HrrrCycle` records:

```
GET /api/admin/hrrr/cycles          # List recent cycles with pipeline stage status
GET /api/admin/hrrr/cycles/:init    # Detailed status for a specific cycle
```

**Admin dashboard panel shows:**

| Field | Source | Example |
|-------|--------|---------|
| Current active cycle | `HrrrCycle.is_active = true` | `2026-02-13T12:00Z` |
| Pipeline stage | `HrrrCycle.status` | `generating_tiles` |
| Download progress | `download_completed / download_total` | `6/6 (142 MB)` |
| Processing progress | `process_completed / process_total` | `4/6` |
| Grid rows written | `ingest_surface_rows + ingest_pressure_rows` | `97,200` |
| Tiles generated | `tiles_completed / tiles_total` | `54/60 (118,432 files)` |
| Pipeline duration | `total_duration_ms` | `7m 23s` |
| Last error | `last_error` | `null` |
| Errors this cycle | `total_errors` | `0` |
| Activated at | `activated_at` | `2026-02-13T13:52Z` |

**Failure visibility:** If any stage fails, the cycle stays at that stage with `status='failed'`. The admin dashboard highlights failed cycles. The next poll creates a new cycle for the next available HRRR init time — it doesn't retry the failed cycle (the data is already stale). The previous active cycle continues serving.

### Python Processor (`scripts/process-hrrr.py`)

Node.js has no viable GRIB2 library. The processor is a Python script invoked via `child_process.execFile()`. It handles all GRIB2 decoding, tile rendering, and grid extraction in a single pass.

**Inputs (CLI args):**
- Path to downloaded wrfsfcf GRIB2 file
- Path to downloaded wrfprsf GRIB2 file
- Output tile directory
- Grid spacing (default 1.0°)
- CONUS bounds (24–50°N, 125–66°W)
- Zoom levels (2–8)

**Outputs:**
1. PNG tiles written to disk (cloud and flight category overlays)
2. Grid values as JSON printed to stdout (Node reads via child process)

**Processing steps:**
1. Open GRIB2 files with `cfgrib` / `xarray`
2. **Cloud tiles** — For each cloud level (low/mid/high/total + pressure levels):
   - Reproject to Web Mercator (EPSG:3857) via GDAL
   - Apply cloud color ramp (white with proportional alpha)
   - Render to 256×256 PNG tiles at zoom 2–8 using `gdal2tiles`
3. **Flight category tiles** — Combine ceiling + visibility into IFR/LIFR/MVFR/VFR classification:
   - LIFR: ceiling < 500 ft or visibility < 1 SM
   - IFR: ceiling 500–999 ft or visibility 1–2.99 SM
   - MVFR: ceiling 1,000–2,999 ft or visibility 3–4.99 SM
   - VFR: ceiling ≥ 3,000 ft and visibility ≥ 5 SM
   - Color each cell by flight category, render tiles
4. **Grid extraction** — Sample all variables at 1° spacing across CONUS:
   - Cloud cover (%, per level and per pressure level)
   - Ceiling (ft MSL, converted from gpm)
   - Cloud base/top (ft MSL)
   - Visibility (SM, converted from m)
   - Wind direction/speed (°true/kt, converted from U/V in m/s)
   - Temperature (°C, converted from K)
   - Wind gust (kt)
5. Print grid JSON to stdout

**Dependencies:** `cfgrib`, `xarray`, `eccodes`, `GDAL`, `numpy`, `Pillow`

### Tile Products

#### Cloud Coverage Tiles

| Level ID | Label | Source | Altitude Range |
|----------|-------|--------|----------------|
| `total` | All clouds | TCDC entire atmosphere | Entire column |
| `low` | Low clouds | LCDC | SFC–6,500 ft |
| `mid` | Mid clouds | MCDC | 6,500–20,000 ft |
| `high` | High clouds | HCDC | 20,000+ ft |
| `850` | ~5,000 ft | TCDC 850 hPa | — |
| `700` | ~10,000 ft | TCDC 700 hPa | — |
| `500` | ~FL180 | TCDC 500 hPa | — |
| `400` | ~FL240 | TCDC 400 hPa | — |
| `300` | ~FL300 | TCDC 300 hPa | — |

**Color ramp:** White (#FFFFFF) with alpha proportional to cloud coverage:
- 0% → fully transparent
- 25% (FEW) → alpha 40
- 50% (SCT) → alpha 100
- 75% (BKN) → alpha 160
- 100% (OVC) → alpha 210

#### Forecast Flight Category Tiles

Single tile set combining ceiling and visibility into flight category colors:

| Category | Ceiling | Visibility | Tile Color |
|----------|---------|------------|------------|
| LIFR | < 500 ft | or < 1 SM | Magenta (#FF00FF), alpha 140 |
| IFR | 500–999 ft | or 1–2.99 SM | Red (#FF0000), alpha 120 |
| MVFR | 1,000–2,999 ft | or 3–4.99 SM | Blue (#0000FF), alpha 100 |
| VFR | ≥ 3,000 ft | and ≥ 5 SM | Transparent (no tile) |

### Tile Rendering Spec

- **Tile size:** 256×256 PNG with transparency
- **Zoom levels:** 2–8
- **Tile scheme:** XYZ (convert from TMS if using gdal2tiles)
- **Filesystem layout:** `data/hrrr/tiles/{cycle}/{product}/{level}/{z}/{x}/{y}.png`
  - Cloud: `data/hrrr/tiles/2026021312/clouds/low/5/8/11.png`
  - Flight cat: `data/hrrr/tiles/2026021312/flight-cat/5/8/11.png`
- **Cleanup:** Delete tile sets from cycles older than 6 hours

### Polling Schedule

| Scenario | Interval | Rationale |
|----------|----------|-----------|
| Normal | Every 60 min | HRRR runs hourly; processing takes ~5–10 min |
| Failed download | Retry after 10 min | S3 availability occasionally delayed |
| Stale threshold | 3 hours | Alert if no successful cycle in 3 hours |

### Forecast Hours to Process

- **F01 through F06** — covers the next 6 hours (most relevant for GA flight planning)
- Skip F00 (initialization artifacts make it less reliable)
- F07–F18 available for route briefings that extend beyond 6 hours (process on demand or on extended cycles at 00/06/12/18z)

---

## 3. Data Model

### Design Principle: Rows, Not Blobs

Data is stored as **individual rows** (not JSONB blobs) so that:
- New cycle data is written alongside existing data — mobile apps continue reading the old cycle while the new one populates
- Once the new cycle is fully written, a cycle status flag flips to `active` and the API switches over atomically
- Old cycle data is cleaned up after the new cycle is confirmed active
- Individual rows enable efficient spatial queries (e.g., "all 700 hPa cloud cover near this lat/lng")

### HrrrCycle Entity (pipeline status tracking)

Tracks each HRRR model cycle through the full pipeline. This is the primary admin dashboard entity — shows the current state of every stage.

```typescript
@Entity('a_hrrr_cycles')
export class HrrrCycle {
  @PrimaryColumn({ type: 'timestamptz' })
  init_time: Date;  // e.g., 2026-02-13T12:00:00Z

  // --- Overall Status ---
  @Column({ type: 'varchar', length: 20, default: 'discovered' })
  status: string;
  // 'discovered' → 'downloading' → 'processing' → 'ingesting'
  //   → 'generating_tiles' → 'active' → 'superseded'
  // On failure at any stage: 'failed'

  @Column({ type: 'boolean', default: false })
  is_active: boolean;  // Only one cycle is active at a time. API serves this one.

  // --- Stage 1: Download ---
  @Column({ type: 'int', default: 0 })
  download_total: number;       // Total forecast hours to download (e.g., 6)

  @Column({ type: 'int', default: 0 })
  download_completed: number;   // Forecast hours successfully downloaded

  @Column({ type: 'int', default: 0 })
  download_failed: number;      // Forecast hours that failed to download

  @Column({ type: 'bigint', default: 0 })
  download_bytes: number;       // Total bytes downloaded across all forecast hours

  @Column({ type: 'timestamptz', nullable: true })
  download_started_at: Date | null;

  @Column({ type: 'timestamptz', nullable: true })
  download_completed_at: Date | null;

  // --- Stage 2: Processing (Python GRIB2 decode) ---
  @Column({ type: 'int', default: 0 })
  process_total: number;

  @Column({ type: 'int', default: 0 })
  process_completed: number;

  @Column({ type: 'int', default: 0 })
  process_failed: number;

  @Column({ type: 'timestamptz', nullable: true })
  process_started_at: Date | null;

  @Column({ type: 'timestamptz', nullable: true })
  process_completed_at: Date | null;

  // --- Stage 3: Grid Ingest ---
  @Column({ type: 'int', default: 0 })
  ingest_surface_rows: number;   // Rows written to a_hrrr_surface

  @Column({ type: 'int', default: 0 })
  ingest_pressure_rows: number;  // Rows written to a_hrrr_pressure

  @Column({ type: 'timestamptz', nullable: true })
  ingest_completed_at: Date | null;

  // --- Stage 4: Tile Generation ---
  @Column({ type: 'int', default: 0 })
  tiles_total: number;      // Total tile sets to generate (products × levels × hours)

  @Column({ type: 'int', default: 0 })
  tiles_completed: number;  // Tile sets successfully generated

  @Column({ type: 'int', default: 0 })
  tiles_failed: number;

  @Column({ type: 'int', default: 0 })
  tiles_count: number;      // Total individual tile files generated

  @Column({ type: 'timestamptz', nullable: true })
  tiles_started_at: Date | null;

  @Column({ type: 'timestamptz', nullable: true })
  tiles_completed_at: Date | null;

  // --- Stage 5: Activation ---
  @Column({ type: 'timestamptz', nullable: true })
  activated_at: Date | null;      // When this cycle became the active one

  @Column({ type: 'timestamptz', nullable: true })
  superseded_at: Date | null;     // When a newer cycle replaced this one

  // --- Error Tracking ---
  @Column({ type: 'text', nullable: true })
  last_error: string | null;

  @Column({ type: 'int', default: 0 })
  total_errors: number;

  // --- Timing ---
  @Column({ type: 'int', nullable: true })
  total_duration_ms: number | null;  // End-to-end pipeline time

  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;
}
```

**Status state machine:**
```
discovered → downloading → processing → ingesting → generating_tiles → active → superseded
     ↓             ↓             ↓            ↓               ↓
   failed        failed        failed      failed           failed
```

**Active cycle rule:** Exactly one cycle has `is_active = true` at any time. The API always queries data where `init_time` matches the active cycle's `init_time`. When a new cycle completes all stages, it atomically flips `is_active`:
1. New cycle: `is_active = true`, `status = 'active'`, `activated_at = now()`
2. Old cycle: `is_active = false`, `status = 'superseded'`, `superseded_at = now()`
3. Both updates in a single transaction

### HrrrSurface Entity (surface-level data)

One row per grid point per forecast hour per cycle. Contains surface weather: ceiling, visibility, cloud composites, surface wind.

```typescript
@Entity('a_hrrr_surface')
@Unique(['init_time', 'forecast_hour', 'lat', 'lng'])
export class HrrrSurface {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'timestamptz' })
  @Index()
  init_time: Date;

  @Column({ type: 'int' })
  forecast_hour: number;

  @Column({ type: 'timestamptz' })
  @Index()
  valid_time: Date;

  @Column({ type: 'float' })
  @Index()
  lat: number;

  @Column({ type: 'float' })
  @Index()
  lng: number;

  // Cloud composites (0–100%)
  @Column({ type: 'smallint', nullable: true })
  cloud_total: number;

  @Column({ type: 'smallint', nullable: true })
  cloud_low: number;

  @Column({ type: 'smallint', nullable: true })
  cloud_mid: number;

  @Column({ type: 'smallint', nullable: true })
  cloud_high: number;

  // Cloud geometry (feet MSL)
  @Column({ type: 'int', nullable: true })
  ceiling_ft: number;

  @Column({ type: 'int', nullable: true })
  cloud_base_ft: number;

  @Column({ type: 'int', nullable: true })
  cloud_top_ft: number;

  // Flight category (derived from ceiling + visibility)
  @Column({ type: 'varchar', length: 4, nullable: true })
  flight_category: string;  // LIFR, IFR, MVFR, VFR

  // Visibility
  @Column({ type: 'float', nullable: true })
  visibility_sm: number;  // statute miles

  // Surface wind
  @Column({ type: 'smallint', nullable: true })
  wind_dir: number;  // degrees true

  @Column({ type: 'smallint', nullable: true })
  wind_speed_kt: number;

  @Column({ type: 'smallint', nullable: true })
  wind_gust_kt: number;

  // Surface temperature
  @Column({ type: 'float', nullable: true })
  temperature_c: number;
}
```

**Row count per cycle:** 1,620 grid points × 6 forecast hours = **9,720 rows**

### HrrrPressure Entity (pressure-level data)

One row per grid point per pressure level per forecast hour per cycle. Contains wind, temperature, and cloud cover at a specific altitude.

```typescript
@Entity('a_hrrr_pressure')
@Unique(['init_time', 'forecast_hour', 'lat', 'lng', 'pressure_level'])
export class HrrrPressure {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'timestamptz' })
  @Index()
  init_time: Date;

  @Column({ type: 'int' })
  forecast_hour: number;

  @Column({ type: 'timestamptz' })
  @Index()
  valid_time: Date;

  @Column({ type: 'float' })
  @Index()
  lat: number;

  @Column({ type: 'float' })
  @Index()
  lng: number;

  @Column({ type: 'smallint' })
  @Index()
  pressure_level: number;  // hPa: 1000, 925, 850, 700, 500, 400, 300, 250, 200

  @Column({ type: 'int' })
  altitude_ft: number;  // Approx altitude MSL for this pressure level

  // Cloud cover at this level (0–100%)
  @Column({ type: 'smallint', nullable: true })
  cloud_cover: number;

  // Wind at this level
  @Column({ type: 'smallint', nullable: true })
  wind_dir: number;  // degrees true

  @Column({ type: 'smallint', nullable: true })
  wind_speed_kt: number;

  // Temperature at this level
  @Column({ type: 'float', nullable: true })
  temperature_c: number;
}
```

**Row count per cycle:** 1,620 grid points × 6 forecast hours × 9 pressure levels = **87,480 rows**

### Grid Specifications

- **Spacing:** 1° lat/lng (matches existing wind grid)
- **CONUS bounds:** 24°N–50°N, 125°W–66°W (from `DATA_PLATFORM.CONUS_BOUNDS`)
- **Total grid points:** 1,620 (27 lat × 60 lng)
- **Total rows per cycle:**
  - Surface: 9,720
  - Pressure: 87,480
  - **Grand total: 97,200 rows per cycle**
- **Cycles retained:** 2 (active + previous) = ~194,400 rows max
- Superseded cycles cleaned up after 3 hours

### HrrrTileMeta Entity (tile set tracking)

Tracks which tile sets are available for the API to serve. Tied to a cycle via `init_time`.

```typescript
@Entity('a_hrrr_tile_meta')
@Unique(['init_time', 'forecast_hour', 'product', 'level'])
export class HrrrTileMeta {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'timestamptz' })
  @Index()
  init_time: Date;

  @Column({ type: 'int' })
  forecast_hour: number;

  @Column({ type: 'varchar', length: 30 })
  product: string;  // 'clouds', 'flight-cat'

  @Column({ type: 'varchar', length: 30, nullable: true })
  level: string;  // 'low', 'mid', 'high', 'total', '850', etc. Null for flight-cat.

  @Column({ type: 'timestamptz' })
  valid_time: Date;

  @Column({ type: 'varchar', length: 255 })
  tile_path: string;  // relative: '2026021312/clouds/low'

  @Column({ type: 'int', default: 0 })
  tile_count: number;

  @CreateDateColumn()
  created_at: Date;
}
```

### Cycle Lifecycle & Data Serving

```
Time ──────────────────────────────────────────────────────────────►

Cycle A (12z):  [write rows] ─── [active, serving to API] ─── [superseded] ─── [cleanup]
Cycle B (13z):              [write rows alongside A] ─── [activate] ─── [serving] ───
                                                              ▲
                                                    atomic flip in one txn:
                                                    A.is_active=false
                                                    B.is_active=true
```

**API query pattern:** All data endpoints include `WHERE init_time = (SELECT init_time FROM a_hrrr_cycles WHERE is_active = true)`. This means:
- Reads always hit a complete, consistent dataset
- Writes to the new cycle never interfere with reads
- The switch is instantaneous (single transaction)

**Cleanup:** A background job deletes rows from `a_hrrr_surface` and `a_hrrr_pressure` where `init_time` belongs to a cycle with `status = 'superseded'` and `superseded_at` is older than 3 hours. Also deletes the corresponding tile directories.

---

## 4. API Endpoints

### Cloud Tiles (map overlay)

```
GET /api/tiles/hrrr/clouds/:level/:z/:x/:y.png?forecast_hour=1
```

**Parameters:**
- `level` — `low`, `mid`, `high`, `total`, `850`, `700`, `500`, `400`, `300`
- `z`, `x`, `y` — XYZ tile coordinates
- `forecast_hour` — Optional, default `1` (1–18)

**Response:** 256×256 PNG with transparency. Transparent 1×1 PNG for missing tiles.

**Headers:** `Cache-Control: public, max-age=1800`

### Flight Category Tiles (map overlay)

```
GET /api/tiles/hrrr/flight-cat/:z/:x/:y.png?forecast_hour=1
```

Colored overlay showing forecast IFR/LIFR/MVFR areas (VFR is transparent).

**Parameters:** Same as cloud tiles minus `level`.

### Tile Metadata

```
GET /api/hrrr/meta
```

```json
{
  "model": "hrrr",
  "latest_init": "2026-02-13T12:00:00Z",
  "products": {
    "clouds": {
      "levels": ["low", "mid", "high", "total", "850", "700", "500", "400", "300"],
      "forecast_hours": [1, 2, 3, 4, 5, 6]
    },
    "flight-cat": {
      "forecast_hours": [1, 2, 3, 4, 5, 6]
    }
  },
  "level_altitudes": {
    "low": "SFC–6,500 ft",
    "mid": "6,500–20,000 ft",
    "high": "20,000+ ft",
    "total": "All layers",
    "1000": "~360 ft",
    "925": "~2,500 ft",
    "850": "~5,000 ft",
    "700": "~10,000 ft",
    "500": "~18,000 ft",
    "400": "~24,000 ft",
    "300": "~30,000 ft",
    "250": "~34,000 ft",
    "200": "~39,000 ft"
  }
}
```

### Route Weather Query (briefing integration)

```
GET /api/hrrr/route?waypoints=39.86,-104.67;38.81,-104.70&altitude=24000
```

Returns full HRRR data at each waypoint — clouds, winds, temperature, ceiling, visibility. Joins `a_hrrr_surface` and `a_hrrr_pressure` for the active cycle.

**Backend query pattern:**

```sql
-- Get active cycle init_time
SELECT init_time FROM a_hrrr_cycles WHERE is_active = true;

-- For each waypoint, find nearest surface grid point
SELECT * FROM a_hrrr_surface
WHERE init_time = $active_init
  AND forecast_hour = $nearest_fh
ORDER BY (lat - $wp_lat)^2 + (lng - $wp_lng)^2
LIMIT 1;

-- Get pressure-level data at the requested altitude
SELECT * FROM a_hrrr_pressure
WHERE init_time = $active_init
  AND forecast_hour = $nearest_fh
  AND pressure_level = $nearest_pressure
  AND lat = $grid_lat AND lng = $grid_lng;
```

**Response:**
```json
{
  "model": "hrrr",
  "init_time": "2026-02-13T12:00:00Z",
  "altitude_ft": 24000,
  "pressure_level": 400,
  "waypoints": [
    {
      "lat": 39.86,
      "lng": -104.67,
      "forecast_hour": 1,
      "valid_time": "2026-02-13T13:00:00Z",
      "clouds": {
        "at_altitude_pct": 0,
        "at_altitude_coverage": "CLR",
        "total": 85,
        "low": 72,
        "mid": 0,
        "high": 45,
        "ceiling_ft": 8500,
        "cloud_base_ft": 5200,
        "cloud_top_ft": 22000,
        "flight_category": "MVFR"
      },
      "wind": {
        "direction": 255,
        "speed_kt": 70,
        "temperature_c": -35.0
      },
      "surface": {
        "wind_dir": 290,
        "wind_speed_kt": 15,
        "wind_gust_kt": 28,
        "temperature_c": 12.5,
        "visibility_sm": 3.5
      }
    }
  ]
}
```

**Coverage mapping:**
- 0–6% → `CLR`
- 7–31% → `FEW`
- 32–56% → `SCT`
- 57–87% → `BKN`
- 88–100% → `OVC`

### Route Weather Profile (cross-section)

```
GET /api/hrrr/profile?waypoints=39.86,-104.67;38.81,-104.70
```

Returns all altitude levels at each waypoint — used for vertical cross-section rendering.

```json
{
  "waypoints": [
    {
      "lat": 39.86,
      "lng": -104.67,
      "valid_time": "2026-02-13T13:00:00Z",
      "ceiling_ft": 8500,
      "cloud_base_ft": 5200,
      "cloud_top_ft": 22000,
      "visibility_sm": 3.5,
      "flight_category": "MVFR",
      "levels": [
        {
          "pressure": 1000, "altitude_ft": 360,
          "cloud_cover_pct": 0, "wind_dir": 280, "wind_speed_kt": 12, "temp_c": 8.5
        },
        {
          "pressure": 850, "altitude_ft": 5000,
          "cloud_cover_pct": 68, "wind_dir": 270, "wind_speed_kt": 25, "temp_c": -1.0
        },
        {
          "pressure": 700, "altitude_ft": 10000,
          "cloud_cover_pct": 12, "wind_dir": 265, "wind_speed_kt": 35, "temp_c": -8.5
        },
        {
          "pressure": 500, "altitude_ft": 18000,
          "cloud_cover_pct": 0, "wind_dir": 260, "wind_speed_kt": 55, "temp_c": -22.0
        },
        {
          "pressure": 400, "altitude_ft": 24000,
          "cloud_cover_pct": 0, "wind_dir": 255, "wind_speed_kt": 70, "temp_c": -35.0
        },
        {
          "pressure": 300, "altitude_ft": 30000,
          "cloud_cover_pct": 42, "wind_dir": 250, "wind_speed_kt": 85, "temp_c": -48.0
        }
      ]
    }
  ]
}
```

### HRRR vs Open-Meteo Wind Comparison (temporary)

```
GET /api/hrrr/compare-winds?lat=39.86&lng=-104.67
```

Returns side-by-side wind data from HRRR grid and Open-Meteo grid for the same point. For validation during the comparison period.

```json
{
  "lat": 39.86,
  "lng": -104.67,
  "hrrr": {
    "init_time": "2026-02-13T12:00:00Z",
    "levels": {
      "850": { "dir": 270, "speed": 25, "temp": -1.0 },
      "700": { "dir": 265, "speed": 35, "temp": -8.5 }
    }
  },
  "open_meteo": {
    "updated_at": "2026-02-13T12:30:00Z",
    "levels": {
      "850": { "dir": 268, "speed": 24, "temp": -1.2 },
      "700": { "dir": 263, "speed": 34, "temp": -8.8 }
    }
  }
}
```

### Admin Endpoints

```
GET /api/admin/hrrr/cycles
```

Returns recent HRRR cycles with full pipeline status. Powers the admin dashboard panel.

```json
{
  "active_cycle": "2026-02-13T12:00:00Z",
  "cycles": [
    {
      "init_time": "2026-02-13T13:00:00Z",
      "status": "ingesting",
      "is_active": false,
      "download": { "completed": 6, "failed": 0, "total": 6, "bytes": 148201472 },
      "processing": { "completed": 6, "failed": 0, "total": 6 },
      "ingest": { "surface_rows": 7290, "pressure_rows": 65610 },
      "tiles": { "completed": 0, "failed": 0, "total": 60, "count": 0 },
      "timing": {
        "download_started_at": "2026-02-13T14:51:00Z",
        "download_completed_at": "2026-02-13T14:53:12Z",
        "process_started_at": "2026-02-13T14:53:12Z",
        "process_completed_at": "2026-02-13T14:56:45Z",
        "ingest_completed_at": null,
        "tiles_started_at": null,
        "tiles_completed_at": null,
        "activated_at": null,
        "total_duration_ms": null
      },
      "errors": { "total": 0, "last_error": null }
    },
    {
      "init_time": "2026-02-13T12:00:00Z",
      "status": "active",
      "is_active": true,
      "download": { "completed": 6, "failed": 0, "total": 6, "bytes": 145892301 },
      "processing": { "completed": 6, "failed": 0, "total": 6 },
      "ingest": { "surface_rows": 9720, "pressure_rows": 87480 },
      "tiles": { "completed": 60, "failed": 0, "total": 60, "count": 118432 },
      "timing": {
        "activated_at": "2026-02-13T13:52:18Z",
        "total_duration_ms": 443000
      },
      "errors": { "total": 0, "last_error": null }
    }
  ]
}
```

```
POST /api/admin/hrrr/cycles/:init_time/retry
```

Re-run a failed cycle from the failed stage. Creates a new attempt for the same init_time.

---

## 5. Configuration Constants

Add to `api/src/config/constants.ts`:

```typescript
export const HRRR = {
  // S3 source (public, no auth)
  S3_BASE_URL: 'https://noaa-hrrr-bdp-pds.s3.amazonaws.com',
  S3_REGION: 'us-east-1',

  // Variables to extract from wrfsfcf (2D surface)
  SURFACE_VARS: [
    'TCDC:entire atmosphere',
    'TCDC:boundary layer cloud layer',
    'LCDC:low cloud layer',
    'MCDC:middle cloud layer',
    'HCDC:high cloud layer',
    'HGT:cloud ceiling',
    'HGT:cloud base',
    'HGT:cloud top',
    'VIS:surface',
    'UGRD:10 m above ground',
    'VGRD:10 m above ground',
    'TMP:2 m above ground',
    'GUST:surface',
  ],

  // Variables to extract from wrfprsf (3D pressure levels)
  PRESSURE_VARS: ['TCDC', 'UGRD', 'VGRD', 'TMP'],
  PRESSURE_LEVELS: [1000, 925, 850, 700, 500, 400, 300, 250, 200],

  // Tile rendering
  TILE_ZOOM_MIN: 2,
  TILE_ZOOM_MAX: 8,
  TILE_SIZE: 256,
  TILES_BASE_DIR: 'data/hrrr/tiles',
  MAX_CYCLE_AGE_HOURS: 6,

  // Forecast hours
  FORECAST_HOURS: [1, 2, 3, 4, 5, 6],

  // Grid extraction
  GRID_SPACING_DEG: 1.0,

  // Polling
  POLL_INTERVAL_MS: 60 * 60 * 1000,       // 60 min
  RETRY_INTERVAL_MS: 10 * 60 * 1000,      // 10 min on failure
  S3_TIMEOUT_MS: 30_000,
  PROCESSOR_TIMEOUT_MS: 10 * 60 * 1000,   // 10 min for Python processing

  // API caching
  CACHE_TTL_TILES_MS: 30 * 60 * 1000,     // 30 min
  CACHE_TTL_ROUTE_MS: 15 * 60 * 1000,     // 15 min

  // Stale threshold
  STALE_MS: 3 * 60 * 60 * 1000,           // 3 hours
};
```

---

## 6. Client Architecture (Flutter)

### Map Overlays

Two new tile layers on the map, toggled from the layer control:

```
lib/features/maps/
  widgets/
    hrrr_layer_control.dart          # Cloud level picker + flight cat toggle
    forecast_hour_scrubber.dart      # Time slider for F01–F06
  providers/
    hrrr_overlay_provider.dart       # Selected product, level, forecast hour, opacity
```

**Cloud tile URL:**
```
{apiBaseUrl}/api/tiles/hrrr/clouds/{level}/{z}/{x}/{y}.png?forecast_hour={fh}
```

**Flight category tile URL:**
```
{apiBaseUrl}/api/tiles/hrrr/flight-cat/{z}/{x}/{y}.png?forecast_hour={fh}
```

### Cloud Altitude Selector

Compact horizontal pill bar:
```
[ Low ] [ Mid ] [ High ] [ FL180 ] [ FL240 ] [ FL300 ]
```

Active level is highlighted. Tapping switches the cloud tile layer. Flight category is a separate toggle (no altitude selector — it's a surface product).

### Forecast Hour Scrubber

Horizontal time slider beneath the altitude selector:
```
[ +1h ] [ +2h ] [ +3h ] [ +4h ] [ +5h ] [ +6h ]
```

Shows the valid time for the selected forecast hour. Scrubbing updates both cloud and flight category tile layers.

### Route Briefing Integration

```
lib/features/flights/
  widgets/
    briefing_hrrr_section.dart       # Combined cloud + wind + ceiling per waypoint
    route_weather_profile.dart       # Vertical cross-section chart
```

The briefing section shows at each waypoint:
- Cloud coverage at cruise altitude + coverage category (CLR/FEW/SCT/BKN/OVC)
- Wind direction/speed at cruise altitude
- Temperature at cruise altitude
- Ceiling and visibility (flight category)
- Cloud base/top if in or near clouds

### State Management (Riverpod)

```dart
final hrrrOverlayProvider = StateNotifierProvider<HrrrOverlayNotifier, HrrrOverlayState>((ref) {
  return HrrrOverlayNotifier();
});

class HrrrOverlayState {
  final bool cloudLayerVisible;
  final String cloudLevel;       // 'low', 'mid', 'high', 'total', '850', etc.
  final bool flightCatVisible;
  final int forecastHour;        // 1–6
  final double opacity;          // 0.0–1.0
}

final routeHrrrProvider = FutureProvider.family<RouteHrrrData, RouteWeatherParams>((ref, params) async {
  final client = ref.read(apiClientProvider);
  return client.getRouteHrrr(params.waypoints, params.altitude);
});
```

---

## 7. Relationship to Existing Systems

### WindGridPoller (Open-Meteo) — Keep Active

The existing `WindGridPoller` continues to run unchanged. HRRR wind data and Open-Meteo wind data coexist in separate tables (`a_hrrr_pressure` vs `a_wind_grid`). The comparison endpoint lets us validate HRRR winds against the established Open-Meteo source before any migration.

**Future:** Once validated, the route briefing and winds aloft display can switch from Open-Meteo to HRRR as the primary source. The `WindGridPoller` can then be retired, eliminating the Open-Meteo dependency and ScrapingBee proxy cost.

### Existing METAR / PIREP / G-AIRMET Data

HRRR provides **forecast** data. Observational data remains essential:

| Source | Role | Relationship to HRRR |
|--------|------|---------------------|
| **METARs** | Current observed conditions at airports | Ground truth — compare HRRR forecast vs actual |
| **PIREPs** | Pilot-reported cloud bases and tops | Only source with actual cloud top heights |
| **G-AIRMETs** | Official IFR/icing/turbulence advisory areas | Supplements forecast; covers advisory-level hazards |

The route briefing blends both: HRRR forecast for area coverage between stations, METAR observations for current conditions at departure/destination, PIREPs for cloud tops.

### Imagery Module (GFA Panels)

GFA cloud panels (`gfa-clouds-*`) remain in the imagery catalog. They're AWC's official human-analyzed product and serve as a cross-reference. HRRR tiles are model-only.

---

## 8. Infrastructure Requirements

### Python Environment

```bash
# Recommended: conda (handles GDAL/eccodes C library dependencies)
conda create -n efb-hrrr python=3.11 cfgrib xarray eccodes gdal numpy pillow
conda activate efb-hrrr
```

Or pip with system GDAL:
```bash
pip install cfgrib xarray eccodes numpy Pillow
# System: apt install gdal-bin python3-gdal (Ubuntu/Debian)
# macOS: brew install gdal
```

### Disk Space

**Tiles:**
- Per cycle: 6 forecast hours × (9 cloud levels + 1 flight cat) × ~2,000 tiles = ~120,000 tiles
- Tile size: ~1–5 KB each
- Per cycle total: ~150–600 MB
- Retention (6 hours, ~6 cycles): ~1–3.5 GB
- **Recommendation:** 5 GB allocated

**GRIB2 downloads (temporary):**
- ~55 MB per forecast hour, ~330 MB per cycle
- Deleted after processing
- **Recommendation:** 500 MB scratch space

### Server Dependencies

- Python 3.11+ with cfgrib, xarray, GDAL, eccodes
- `wgrib2` CLI tool (optional, for debugging)
- No AWS credentials needed (public S3 bucket)
- Sufficient CPU for tile rendering (~5–10 min per cycle)

---

## 9. Implementation Phases

### Phase 1: HRRR Pipeline + Grid Values
- `HrrrCycle`, `HrrrSurface`, `HrrrPressure` entities + database migrations
- `HrrrPoller` (NestJS) — S3 .idx parsing, byte-range downloads, cycle status tracking
- `process-hrrr.py` — GRIB2 decoding, grid value extraction (no tiles yet)
- Admin cycle status endpoint (`/api/admin/hrrr/cycles`)
- Register `hrrr_poll` DataSource in scheduler
- Route weather query endpoint (`/api/hrrr/route`)
- Wind comparison endpoint (`/api/hrrr/compare-winds`)
- Validate HRRR winds against Open-Meteo

### Phase 2: Tile Rendering + Map Overlays
- Extend `process-hrrr.py` with tile rendering (cloud + flight category)
- `HrrrTileMeta` entity
- Tile serving endpoints (`/api/tiles/hrrr/clouds/...`, `/api/tiles/hrrr/flight-cat/...`)
- Tile metadata endpoint (`/api/hrrr/meta`)
- Tile lifecycle management (cleanup old cycles)
- Flutter: cloud overlay with altitude selector
- Flutter: flight category overlay toggle
- Flutter: forecast hour scrubber

### Phase 3: Route Profile + Briefing Integration
- Route weather profile endpoint (`/api/hrrr/profile`)
- Flutter: vertical cross-section chart (clouds + wind + temp along route)
- Briefing screen: HRRR cloud/wind/ceiling section per waypoint
- Blend METAR observations with HRRR forecast in briefing

### Phase 4: Open-Meteo Migration (after validation)
- Switch winds aloft display from Open-Meteo to HRRR source
- Switch route briefing winds from Open-Meteo to HRRR
- Retire `WindGridPoller` and ScrapingBee proxy dependency
- Remove Open-Meteo comparison endpoint

---

## 10. Open Questions

1. **Pressure-level tiles** — Do we render tiles for all 9 pressure levels, or just the composite layers (Low/Mid/High/Total)? Pressure-level tiles are more useful for IFR altitude planning but multiply tile count. Could start with composites only and add pressure levels based on demand.

2. **Tile zoom range** — Zoom 2–8 covers regional planning. Zoom 9–10 would add terminal area detail but significantly increases tile count (~4× per additional zoom level).

3. **Extended forecasts** — Process F07–F18 for longer flights? Could do this lazily — only when a route briefing requests it — rather than every cycle.

4. **Alaska** — HRRR has a separate Alaska domain (`hrrr.YYYYMMDD/alaska/`). Defer to v2.

5. **Wind tiles** — Should we also render wind barb tiles from HRRR? ForeFlight shows winds as a colored speed overlay with barbs. Currently wind is displayed as arrows at grid points which works but lacks the visual impact of a filled overlay.
