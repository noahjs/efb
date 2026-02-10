# Garmin Avionics Data Integration Module
## EFB Product Specification

[← Back to Core Specification](../EFB_Product_Specification_v1.md)

---

The Garmin Avionics Data Integration module imports flight operational data — flight times, fuel burn, engine parameters, Hobbs/tach, and route — from Garmin integrated flight decks. This is the data pilots need for logbook entries, engine trend monitoring, and aircraft record-keeping.

This module is separate from the [ADS-B & TIS-B Integration](./adsb-integration.md) module, which covers real-time situational awareness (traffic, weather, GPS, AHRS) via portable ADS-B receivers.

---

## 1. The Problem

Garmin dominates the GA avionics market. Most of the flight operational data a pilot needs lives inside the Garmin flight deck — but Garmin does not provide a public API or SDK to access it. Understanding the available paths (and their limitations) is critical to our integration strategy.

### What Pilots Want from Their Avionics

| Data | Use Case |
|------|----------|
| **Flight time** (block, flight, air time) | Logbook entries, currency tracking, rental billing |
| **Hobbs / tach time** | Maintenance scheduling, rental charges, engine TBO tracking |
| **Route flown** | Logbook route field, flight review, GPS track replay |
| **Fuel burned / fuel remaining** | Fuel cost tracking, fuel planning accuracy feedback |
| **Engine parameters** (CHT, EGT, oil, MAP, RPM, ITT, Ng, torque) | Engine trend monitoring, exceedance tracking, maintenance insights |
| **Departure / arrival airports** | Logbook auto-population |
| **Takeoff / landing counts** | Day/night currency tracking |

### What's Available Today

| Path | Data Richness | Real-Time? | Requires Partnership? | Available Now? |
|------|--------------|------------|----------------------|----------------|
| **SD Card CSV** (G1000, G3000, G5000) | Excellent — all engine, fuel, GPS, nav data at 1 Hz | No (post-flight) | No | **Yes** |
| **Garmin Pilot CSV Export** (flyGarmin.com) | Good — logbook fields, flight times, some engine summary | No (post-flight) | No | **Yes** (covered in [logbook-import.md](./logbook-import.md)) |
| **Connext Bluetooth** (Flight Stream / GDL 60) | Excellent — real-time engine, fuel, GPS, flight plans | Yes | **Yes — locked** | No |
| **PlaneSync** (GDL 60 → flyGarmin.com → service providers) | Good — auto-uploaded flight/engine logs | No (post-flight, automatic) | **Yes — approved providers** | No |

**Our starting point is SD card CSV import** — it provides the richest data, covers the most Garmin flight decks, and requires no partnership. Garmin Pilot CSV import is already spec'd in [logbook-import.md](./logbook-import.md).

---

## 2. Garmin Ecosystem Overview

### 2.1 Why We Can't Get Real-Time Data (Yet)

Garmin panel-mount avionics (G1000, GTN 650/750, G3000, G5000) have **no wireless capability on their own**. Wireless connectivity requires a separate gateway device — Flight Stream 510 or GDL 60 — which uses Garmin's proprietary encrypted Connext Bluetooth protocol.

```
┌───────────────────────────────────────────────────────────────────┐
│  HOW GARMIN AVIONICS DATA REACHES MOBILE APPS                     │
│                                                                   │
│  G1000 / GTN 650 / GTN 750 / G3000 / G5000                      │
│      ↓  internal bus / SD card slot                               │
│  Flight Stream 510 (MMC card) or GDL 60 (remote box)            │
│      ↓  Bluetooth + WiFi (PROPRIETARY ENCRYPTED)                 │
│  Garmin Pilot, ForeFlight, FltPlan Go (approved partners only)   │
│      ✗  Our app CANNOT connect — protocol is locked              │
│                                                                   │
│  However:                                                         │
│  G1000 / G3000 / G5000 → SD card CSV (1 Hz flight data log)     │
│      ✓  Our app CAN parse these files (open CSV format)          │
└───────────────────────────────────────────────────────────────────┘
```

- **No public SDK or API exists.** Garmin's developer portal covers wearables, fitness, and marine — not aviation.
- **No aviation developer program.** There is no self-service registration for Connext access.
- **Access requires business partnership.** ForeFlight gained access in 2015 via B2B agreement (likely under NDA). FlyQ was explicitly blocked — Garmin encrypts the datastream and refused to share it.
- **G3000 PRIME, GI 275, G3X Touch** have built-in WiFi/Bluetooth but still use the same proprietary Connext protocol.

### 2.2 Flight Stream Architecture

Flight Stream is a **separate hardware device**, not built into the avionics.

| Model | Form Factor | Installs In | Connectivity |
|-------|-------------|-------------|-------------|
| Flight Stream 510 | MMC memory card | GTN 650/750/Xi card slot, G1000 NXi MFD, G3000, G5000 | WiFi + Bluetooth |
| Flight Stream 210 | Standalone box | Wired RS-232 to GNS 430W/530W or GTN + GDL 88 | Bluetooth only |
| Flight Stream 110 | Standalone box | Wired RS-232 to GDL 88 | Bluetooth only |
| GDL 60 | Remote box | Wired to G1000 NXi/G3000/G5000 avionics bus | WiFi + Bluetooth + 4G LTE |

**Data available through Flight Stream / GDL 60 (to approved apps only):**

| Data | Flight Stream 510 | GDL 60 |
|------|-------------------|--------|
| GPS position (WAAS) | Yes | Yes |
| AHRS (pitch, roll, heading) | Yes | Yes |
| ADS-B traffic | Yes (via GTX 345/GDL 88) | Yes |
| Flight plans (two-way) | Yes | Yes |
| Engine data (with EIS) | Yes (G1000 NXi, TXi, G3000) | Yes |
| Fuel quantity | Yes (with EIS) | Yes |
| PlaneSync cloud upload | No | Yes (automatic) |
| Remote aircraft monitoring | No | Yes (via Garmin Pilot) |

### 2.3 PlaneSync (Future Partnership Path)

Garmin's PlaneSync service (via GDL 60) automatically uploads flight and engine data to flyGarmin.com after each flight. Approved service providers receive this data through opt-in integrations:

- **Savvy Aviation** — engine trend analysis
- **FlySto** — flight data analytics
- **Crewchief Systems** — aircraft maintenance tracking

Becoming an approved provider requires contacting Garmin's aviation business development team. This is a lower-effort path than Connext Bluetooth access and worth pursuing once we have users. The data includes GPS track, engine parameters, Hobbs/tach times, fuel quantity, and CO levels.

---

## 3. Compatible Garmin Flight Decks

### 3.1 Integrated Flight Decks (SD Card CSV Logging)

| Avionics | Aircraft Examples | SD Card CSV | Engine Data Columns | Flight Stream | GDL 60 |
|----------|-------------------|-------------|---------------------|---------------|--------|
| **G1000 / G1000 NXi** | Cessna 172/182/206, Beech G36/G58, DA42/DA62, PA-46 | **Yes (1 Hz)** | Piston: CHT, EGT, oil, MAP, RPM, fuel flow | FS 510 | Yes |
| **G3000** | TBM 930/940/960, Cirrus Vision Jet, Piper M600/SLS, HondaJet | **Yes (1 Hz)** | Turbine: ITT, Ng, Np, torque, % power, fuel flow | FS 510 | Yes |
| **G3000 PRIME** | TBM 980, Citation CJ4 Gen3, Pilatus PC-12 PRO | **Yes (1 Hz)** | Turbine (same as G3000) | Built-in (proprietary) | Yes |
| **G3000H** | Part 27 turbine helicopters | **Yes (1 Hz)** | Turbine | FS 510 | Yes |
| **G5000** | Citation Excel/XLS/Sovereign/Latitude/Longitude/Ascend | **Yes (1 Hz)** | Multi-engine turbine (E1 + E2) | FS 510 | Yes |

### 3.2 Navigators & Displays (No SD Card Logging)

These units do not log flight data to SD card. Flight operational data from these is only accessible via Connext (locked) or Garmin Pilot CSV export.

| Avionics | SD Card CSV | Engine Data | Notes |
|----------|-------------|-------------|-------|
| GTN 650 / 650Xi | No | No (nav/comm only) | Flight Stream 510 fits in card slot |
| GTN 750 / 750Xi | No | No (nav/comm only) | Flight Stream 510 fits in card slot |
| GNS 430W / 530W | No | No | Flight Stream 210 via RS-232 |
| G500/G600 TXi | No | Yes (with GEA 110) — but only via Connext | No SD card log |
| GI 275 | No | Yes (EIS variant) — but only via Connext | Built-in BT, proprietary |
| G3X Touch | Yes | Yes (built-in EIS) | Experimental/LSA only |

### 3.3 What This Means for Pilots

| Pilot's Garmin Setup | Can We Import Flight Data? | How? |
|----------------------|---------------------------|------|
| G1000 / G1000 NXi | **Yes** | SD card CSV import |
| G3000 (TBM, Vision Jet, M600, HondaJet) | **Yes** | SD card CSV import |
| G5000 (Citation fleet) | **Yes** | SD card CSV import |
| GTN 650/750 only (no integrated flight deck) | **Partial** | Garmin Pilot CSV export only (logbook fields, no engine data) |
| G500/G600 TXi only | **Partial** | Garmin Pilot CSV export only |
| GI 275 only | **Partial** | Garmin Pilot CSV export only |
| G3X Touch (experimental) | **Yes** | SD card CSV import |
| Any Garmin + PlaneSync (GDL 60) | **Future** | Requires becoming approved PlaneSync provider |

---

## 4. SD Card CSV Format

### 4.1 File Structure

The G1000, G1000 NXi, G3000, G3000 PRIME, G3000H, and G5000 all log flight data to an SD card in the MFD at 1 Hz (one sample per second). The CSV format is consistent across all platforms, with additional columns for turbine-specific parameters on the G3000/G5000.

- **Location**: `data_log/log_YYYY-MM-DD_HHMMSS_IDENT.csv`
- **Capacity**: ~1,000 flight hours per GB
- **Structure**:
  - Row 1: Airplane identification (tail number, model)
  - Row 2: Column headers
  - Row 3: Units
  - Row 4+: Data (1 row per second)

### 4.2 Key Columns

#### Flight & Position Data

| Column | Unit | Description |
|--------|------|-------------|
| `Lcl Date` | `yyyy-mm-dd` | Local date |
| `Lcl Time` | `HH:MM:SS` | Local time |
| `UTCOfst` | `hh:mm` | UTC offset |
| `Latitude` | degrees | GPS latitude |
| `Longitude` | degrees | GPS longitude |
| `AltB` | ft msl | Barometric altitude |
| `AltMSL` | ft msl | Altitude MSL |
| `AltGPS` | ft wgs84 | GPS altitude |
| `IAS` | kt | Indicated airspeed |
| `TAS` | kt | True airspeed |
| `GndSpd` | kt | Groundspeed |
| `VSpd` | fpm | Vertical speed |
| `Pitch` | deg | Pitch angle |
| `Roll` | deg | Roll angle |
| `HDG` | deg | Magnetic heading |
| `TRK` | deg | Ground track |
| `WndSpd` | kt | Wind speed |
| `WndDr` | deg | Wind direction |

#### Engine Data — Piston (G1000, `E1` prefix)

| Column | Unit | Description |
|--------|------|-------------|
| `E1 FFlow` | gph | Fuel flow |
| `E1 FPres` | psi | Fuel pressure |
| `E1 OilT` | deg F | Oil temperature |
| `E1 OilP` | psi | Oil pressure |
| `E1 MAP` | inHg | Manifold pressure |
| `E1 RPM` | rpm | Engine RPM |
| `E1 CHT1`–`E1 CHT4` | deg F | Cylinder head temperatures (per cylinder) |
| `E1 EGT1`–`E1 EGT4` | deg F | Exhaust gas temperatures (per cylinder) |

#### Engine Data — Turbine (G3000 / G5000, `E1` prefix)

| Column | Unit | Description |
|--------|------|-------------|
| `E1 ITT` | deg C | Interstage Turbine Temperature |
| `E1 Ng` | % | Gas generator (N1) RPM percentage |
| `E1 Np` | RPM | Propeller RPM (turboprops) |
| `E1 TRQ` | ft-lbs or % | Torque |
| `E1 Pwr` | % | Computed power percentage |
| `E1 FF` | pph or gph | Fuel flow (turbines often use pounds per hour) |

Multi-engine aircraft add `E2` prefix columns for the second engine.

#### Fuel Data

| Column | Unit | Description |
|--------|------|-------------|
| `FQtyL` | gal | Left tank fuel quantity |
| `FQtyR` | gal | Right tank fuel quantity |
| `volt1` | volts | Bus voltage |

#### Navigation

| Column | Unit | Description |
|--------|------|-------------|
| `AtvWpt` | — | Active waypoint identifier |
| `NAV1` | MHz | NAV1 frequency |
| `NAV2` | MHz | NAV2 frequency |
| `COM1` | MHz | COM1 frequency |
| `COM2` | MHz | COM2 frequency |
| `HCDI` | dots | Horizontal CDI deflection |
| `VCDI` | dots | Vertical CDI deflection |
| `WptDst` | nm | Distance to active waypoint |
| `WptBrg` | deg | Bearing to active waypoint |

### 4.3 Derived Flight Data

From the raw 1 Hz CSV data, the importer calculates:

| Derived Field | Calculation | Maps To |
|---------------|-------------|---------|
| **Flight duration** | Last − first timestamp where `GndSpd > 30 kt` | Logbook: `totalTime` |
| **Block time** | Last − first timestamp (full file) | Logbook: block time reference |
| **Total fuel burned** | Sum(`E1 FFlow` / 3600) per second, or `initial FQty − final FQty` | Logbook: fuel burn |
| **Departure airport** | Nearest airport to first GPS position | Logbook: `departureAirport` |
| **Arrival airport** | Nearest airport to last GPS position | Logbook: `arrivalAirport` |
| **Route** | Sequence of `AtvWpt` changes during flight | Logbook: `route` |
| **Max altitude** | Max of `AltMSL` | Logbook: supplemental |
| **Max groundspeed** | Max of `GndSpd` | Logbook: supplemental |
| **GPS track** | Array of `(lat, lon, alt, time)` for map replay | Track log |
| **Takeoff/landing count** | Detect groundspeed transitions (>30→<30 kt and <30→>30 kt) near airports | Logbook: landings |
| **Day/night determination** | Compare takeoff/landing times against civil twilight at GPS position | Logbook: `night`, day/night landings |
| **CHT/EGT exceedances** | Timestamps where any CHT > redline or EGT > redline | Engine trend alert |
| **Avg/peak engine params** | Per-cylinder peak CHT/EGT, avg fuel flow, avg oil temp/pressure | Engine trend summary |

### 4.4 What's NOT in the CSV

| Data | Status | Workaround |
|------|--------|------------|
| **Hobbs time** | Not directly recorded as a running counter in the CSV | Derive from block time (first to last row). Not identical to Hobbs but close. |
| **Tach time** | Not in CSV | Cannot be derived — tach time is RPM-weighted and only the physical tach or Garmin's internal counter tracks it. Available in Garmin Pilot logbook export. |
| **Flight plan / filed route** | Not in CSV (only `AtvWpt` — the active waypoint at each second) | Reconstruct approximate route from waypoint sequence. |
| **Clearance / assigned altitude** | Not in CSV | N/A |
| **Radio communications** | Not in CSV | N/A |

---

## 5. Data Model

### 5.1 Entity: `FlightDataLog`

Persisted. Stores an imported Garmin CSV data log linked to a logbook entry.

| Field | Type | Description |
|-------|------|-------------|
| `id` | int (PK) | Auto-generated |
| `logbook_entry_id` | int (FK → LogbookEntry), nullable | Linked logbook entry |
| `aircraft_id` | int (FK → Aircraft), nullable | Aircraft (matched by tail number in CSV row 1) |
| `source` | enum | `g1000`, `g1000_nxi`, `g3000`, `g3000_prime`, `g5000`, `g3x` |
| `file_name` | varchar | Original CSV filename |
| `start_time` | timestamp | First data row timestamp (UTC) |
| `end_time` | timestamp | Last data row timestamp (UTC) |
| `duration_seconds` | int | Total duration (block time) |
| `flight_time_seconds` | int, nullable | Flight time (groundspeed > 30 kt) |
| `departure_airport` | varchar, nullable | Auto-detected departure (FAA identifier) |
| `arrival_airport` | varchar, nullable | Auto-detected arrival (FAA identifier) |
| `route` | varchar, nullable | Reconstructed route from active waypoint sequence |
| `max_altitude` | int, nullable | Maximum altitude MSL (feet) |
| `max_groundspeed` | int, nullable | Maximum groundspeed (knots) |
| `total_fuel_burned` | float, nullable | Total fuel burned (gallons) |
| `initial_fuel` | float, nullable | Fuel quantity at start (gallons) |
| `final_fuel` | float, nullable | Fuel quantity at end (gallons) |
| `takeoff_count` | int, nullable | Number of takeoffs detected |
| `landing_count` | int, nullable | Number of landings detected |
| `night_landing_count` | int, nullable | Landings during night (civil twilight) |
| `engine_type` | enum | `piston`, `turboprop`, `turbojet` — determines which params to display |
| `gps_track` | jsonb | Compressed array of `{ lat, lon, alt, time }` — sampled every 6 seconds |
| `engine_data` | jsonb | Time-series engine parameters — sampled every 6 seconds |
| `exceedances` | jsonb, nullable | Array of `{ parameter, value, limit, timestamp }` |
| `raw_summary` | jsonb | Summary stats: peak CHT (by cylinder), peak EGT, avg fuel flow, avg oil temp/pressure, etc. |
| `created_at` | timestamp | |

**Storage note**: Raw 1 Hz data at ~50 columns generates ~180 KB/min CSV. A 2-hour flight is ~22 MB raw. We store downsampled data (every 6 seconds) for the GPS track and engine time-series. Raw CSV is not retained server-side.

---

## 6. UI Design

### 6.1 Screen: Garmin Data Import (`/logbook/import/garmin-csv`)

1. **File Selection** — Pick CSV files from device storage / SD card reader
2. **Preview Table** — For each file:
   ```
   ┌──────────────────────────────────────────────────────┐
   │ log_2026-01-15_143022_N172SP.csv                     │
   │                                                       │
   │ Date:       Jan 15, 2026                              │
   │ Aircraft:   N172SP (auto-matched)                     │
   │ Duration:   1h 42m (block) / 1h 35m (flight)         │
   │ Route:      APA → BJC (via REDLE, TOMSN)             │
   │ Fuel Burn:  14.2 gal (8.4 gph avg)                   │
   │ Max Alt:    8,200 ft                                  │
   │ Landings:   2 (1 day, 1 night)                        │
   │ Max CHT:    412°F (cyl 3)                             │
   │ Engine:     No exceedances                            │
   │                                                       │
   │ [Create Logbook Entry]  [Import Engine Data Only]     │
   └──────────────────────────────────────────────────────┘
   ```
3. **Confirmation** — Import summary with count of entries created

### 6.2 Screen: Engine Data Viewer (`/logbook/:id/engine`)

Accessed from a logbook entry that has linked flight data.

**Layout:**
1. **Time scrubber** — horizontal timeline bar spanning the flight duration. Drag to scrub through data.
2. **Primary chart area** — stacked time-series line charts. Adapts to engine type:

   **Piston:**
   - CHT (4 cylinders, color-coded) with redline
   - EGT (4 cylinders, color-coded) with redline
   - Oil Temp / Oil Pressure (dual-axis)
   - Fuel Flow with cumulative fuel burned overlay
   - RPM / MAP (dual-axis)

   **Turbine:**
   - ITT with redline
   - Ng / Np (dual-axis)
   - Torque with redline
   - Fuel Flow (pph) with cumulative fuel burned overlay
   - Oil Temp / Oil Pressure (dual-axis)

3. **Exceedance markers** — red dots on timeline where any parameter exceeded limits
4. **Summary stats panel** — collapsible panel with peak values, averages, total fuel burned
5. **Chart selector** — toggle which parameter groups are visible
6. **Pinch to zoom** on time axis for detailed inspection

### 6.3 Screen: Flight Track Replay (`/logbook/:id/track`)

- GPS track rendered on the map as a colored path
- Color encodes altitude (low → high) or speed
- Play/pause/scrub controls to animate ownship along the track
- Sidebar shows flight parameters at the current scrub position (altitude, speed, engine data)
- Departure and arrival airports highlighted

---

## 7. Backend API Endpoints

All endpoints prefixed with `/api/flight-data`.

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/import/garmin` | Upload and parse Garmin CSV file(s). Returns parsed summary for preview. |
| `POST` | `/import/garmin/confirm` | Confirm import — create logbook entries and persist flight/engine data. |
| `GET` | `/logs` | List all imported flight data logs |
| `GET` | `/logs/:id` | Get flight data log with summary |
| `GET` | `/logs/:id/engine` | Get full engine data time-series for a flight |
| `GET` | `/logs/:id/track` | Get GPS track for a flight |
| `DELETE` | `/logs/:id` | Delete a flight data log |

---

## 8. Frontend State Management

| Provider | Type | Purpose |
|----------|------|---------|
| `flightDataLogsProvider` | `FutureProvider` | List of imported flight data logs. |
| `flightDataLogProvider(logId)` | `FutureProvider` | Single flight data log with summary. |
| `engineDataProvider(logId)` | `FutureProvider` | Engine data time-series for a specific flight. |
| `gpsTrackProvider(logId)` | `FutureProvider` | GPS track for a specific flight. |

---

## 9. Implementation Phases

### Phase 1 — CSV Parser & Import

| Feature | Details | Depends On |
|---------|---------|------------|
| CSV parser | Parse G1000/NXi/G3000/G5000 SD card CSV. Handle column variations across piston and turbine aircraft. Detect engine type from available columns. | — |
| Flight data extraction | Derive flight time, block time, fuel burn, departure/arrival, route (from waypoint sequence), takeoff/landing count, day/night determination | CSV parser, Airports module (for nearest airport lookup) |
| Engine data extraction | Extract piston params (CHT, EGT, oil, fuel flow, RPM, MAP) and turbine params (ITT, Ng, Np, torque, % power). Compute summary stats and detect exceedances. | CSV parser |
| Import flow UI | File picker, preview screen with derived fields, confirmation | CSV parser |
| Logbook integration | Auto-create logbook entry from imported data with pre-filled fields | CSV parser, Logbook module |

### Phase 2 — Engine Data Visualization

| Feature | Details | Depends On |
|---------|---------|------------|
| Engine data viewer | Time-series charts for engine parameters, adapts to piston vs turbine | Phase 1 |
| Exceedance highlighting | Red markers on timeline, exceedance list with parameter/value/timestamp | Phase 1 |
| Engine trend analysis | Compare peak CHT/EGT across multiple flights for the same aircraft, detect degradation trends | Phase 1 (multiple imports) |

### Phase 3 — Flight Track & Replay

| Feature | Details | Depends On |
|---------|---------|------------|
| GPS track display | Render imported GPS track on map with altitude/speed color encoding | Phase 1, Maps module |
| Flight replay | Animated playback of flight with synchronized engine data sidebar | GPS track display, Engine data viewer |

### Phase 4 — Garmin Partnership Paths

| Feature | Details | Priority |
|---------|---------|----------|
| PlaneSync service provider | Apply to become approved provider for automatic post-flight data from GDL 60 | Medium — pursue when we have users |
| Connext Bluetooth partnership | Approach Garmin for proprietary protocol access (the ForeFlight path) | Low — requires significant user base and business relationship |

---

## 10. Open-Source Resources & References

| Resource | URL | Description |
|----------|-----|-------------|
| G1000 CSV Sample | [GitHub](https://github.com/npnicholson/flightaware-tracklog/blob/master/g1000.sample.csv) | Example G1000 data log file |
| Garmin Simple Text Output | [garmin.com](https://www8.garmin.com/support/text_out.html) | RS-232 text format docs (G5, G3X, portables) |
| Garmin NMEA 0183 Proprietary | [PDF](https://developer.garmin.com/downloads/legacy/uploads/2015/08/190-00684-00.pdf) | `$PGRM` sentence documentation |
| Savvy Aviation API | [github.com/savvyaviation/api-docs](https://github.com/savvyaviation/api-docs) | Engine data upload REST API (upload-only) |
| edmtools (JPI decoder) | [github.com/wannamak/edmtools](https://github.com/wannamak/edmtools) | JPI binary format decoder (for future JPI support) |

---

## 11. Implementation Status

**Not Started** — This module has no implementation yet. The Logbook module supports flight entry creation with all required time tracking fields, providing the foundation for auto-creating logbook entries from imported CSV data. The Airports module provides the nearest-airport lookup needed for departure/arrival auto-detection.
