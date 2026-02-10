# Traffic Module
## EFB Product Specification

[← Back to Core Specification](../EFB_Product_Specification_v1.md)

---

The Traffic module provides real-time aircraft traffic awareness from multiple data sources with a unified display. On the ground, traffic is sourced from internet-based ADS-B aggregation APIs. In the air, traffic comes from a connected ADS-B receiver via GDL 90 (see [ADS-B Integration](./adsb-integration.md)). Regardless of source, all traffic targets flow through a common pipeline that provides client-side position interpolation between updates, projected flight path "heads," and threat-level classification.

---

## 1. Core Features

| Feature | Details | Complexity |
|---------|---------|------------|
| Multi-Source Traffic | Pluggable backend architecture supporting GDL 90 (ADS-B receiver), Airplanes.live, OpenSky Network, and ADS-B Exchange APIs. Only one source active at a time, with automatic and manual switching. | High |
| Position Interpolation | Client-side dead-reckoning between data updates (up to 10s for API sources, ~1s for GDL 90). Smoothly extrapolates each target's position using last-known groundspeed, track, and vertical rate so the map never "jumps." | High |
| Projected Flight Path Heads | For each target, render projected future positions at configurable intervals (default 2 min and 5 min) based on current track, groundspeed, and vertical rate. Displayed as ghost icons connected by a dashed leader line. | Medium |
| Unified Traffic Model | All sources produce the same `TrafficTarget` model. The display layer is source-agnostic — switching from API to ADS-B receiver is seamless with no UI changes. | Medium |
| Threat Classification | Classify targets relative to ownship: `none`, `proximate` (<6 nm, ±1200 ft), `alert` (<3 nm, ±600 ft), `resolution` (<1 nm, ±300 ft). Color-coded on map. | Medium |
| Altitude Filter | User-configurable altitude band filter. Default: show traffic within ±3,000 ft of ownship (or field elevation when on the ground). | Low |
| Traffic List View | Sortable list of active targets showing callsign, altitude, groundspeed, distance, bearing, and trend (climbing/descending/level). Tap to center map on target. | Medium |
| Audio Alerts | Spoken traffic callouts when a target enters alert or resolution proximity: "Traffic, 2 o'clock, 3 miles, 500 feet above, descending." | Medium |
| Auto Source Switching | When an ADS-B receiver connects, automatically switch from API source to GDL 90. When the receiver disconnects, fall back to API source (if on ground / if configured). | Medium |

---

## 2. Data Sources

### 2.1 Source Priority

The traffic module selects one active source at a time. Priority order:

1. **GDL 90 ADS-B Receiver** — Always preferred when connected. Real-time, ~1 Hz updates, includes TIS-B rebroadcasts. Available in flight and on the ground (when receiver is powered on and connected via WiFi).
2. **Internet API** — Used when no ADS-B receiver is connected. Requires internet connectivity. Configurable polling interval (default 10 seconds). Best suited for ground-based preflight situational awareness.

### 2.2 API Backends

The architecture supports pluggable API backends. Each backend implements a common interface that returns normalized `TrafficTarget` data.

| Backend | Auth | Cost | Coverage | Update Latency | Rate Limit | Notes |
|---------|------|------|----------|----------------|------------|-------|
| **Airplanes.live** | None (no API key) | Free | Global, unfiltered | ~5 s | 1 req/s | Community-funded. Best default for free tier. Query by lat/lon with radius up to 250 nm. |
| **OpenSky Network** | Optional (free account) | Free (non-commercial) | Global | ~5–10 s | 400–8,000 credits/day | Research-oriented. Requires license for commercial use. Bounding-box queries. |
| **ADS-B Exchange** | API key (RapidAPI) | ~$10/mo personal | Global, unfiltered | ~2 s | 10,000 req/mo | Unfiltered (no LADD/PIA blocking). Query within 100 nm radius. |
| **FlightAware AeroAPI** | API key | ~$0.002/query | Global, filtered | ~5 s | Usage-based | Most polished commercial option. Honors LADD/PIA. 60+ endpoints. |

**Default backend**: Airplanes.live (free, no API key, unfiltered).

Users can configure their preferred backend in Settings. If a backend requires an API key, the user enters it in Settings and it is stored in secure local storage (Keychain / Android Keystore).

### 2.3 API Backend Interface

Each backend implements:

```
TrafficBackend {
  /// Human-readable name for display in settings
  name: String

  /// Whether this backend requires an API key
  requiresApiKey: bool

  /// Fetch traffic targets within a radius of a point.
  /// Returns normalized TrafficTarget list.
  fetchTraffic(
    latitude: double,
    longitude: double,
    radiusNm: double,      // Nautical miles, typically 30–100
  ) → List<TrafficTarget>

  /// Maximum recommended poll interval for this backend
  recommendedPollInterval: Duration

  /// Whether the backend is currently reachable
  healthCheck() → bool
}
```

### 2.4 Backend-Specific Query Details

**Airplanes.live**
- Endpoint: `GET https://api.airplanes.live/v2/point/{lat}/{lon}/{radius_nm}`
- Returns JSON array of aircraft with `hex`, `flight`, `lat`, `lon`, `alt_baro`, `gs`, `track`, `baro_rate`, `category`, `nav_altitude_mcp`, `squawk`, `emergency`, `seen`, `rssi`
- Map `hex` → ICAO address, `flight` → callsign, `gs` → groundspeed (knots), `track` → true track, `baro_rate` → vertical rate (fpm), `category` → emitter category
- `seen` field = seconds since last message from this aircraft — use to calculate true position age

**OpenSky Network**
- Endpoint: `GET https://opensky-network.org/api/states/all?lamin={}&lomin={}&lamax={}&lomax={}`
- Returns state vectors with `icao24`, `callsign`, `longitude`, `latitude`, `baro_altitude` (meters), `velocity` (m/s), `true_track`, `vertical_rate` (m/s), `on_ground`
- Convert: altitude m→ft (×3.28084), velocity m/s→knots (×1.94384), vertical_rate m/s→fpm (×196.85)
- Uses bounding box instead of radius — compute bounding box from center point + radius

**ADS-B Exchange**
- Endpoint: `GET https://adsbexchange-com1.p.rapidapi.com/v2/lat/{lat}/lon/{lon}/dist/{dist}/`
- Headers: `X-RapidAPI-Key`, `X-RapidAPI-Host`
- Returns `ac[]` array with fields matching Airplanes.live format (both use readsb-derived JSON)

---

## 3. Position Interpolation (Dead Reckoning)

Between data updates, the client extrapolates each target's position to prevent visual "jumping" on the map and provide smooth animation.

### 3.1 Algorithm

For each target, on every animation frame (~60 fps):

```
elapsed = now - target.lastUpdated

// Horizontal extrapolation
distance_nm = target.groundspeed * (elapsed / 3600)  // speed in kts, time in hours
new_lat = target.lat + (distance_nm / 60) * cos(target.track)
new_lon = target.lon + (distance_nm / (60 * cos(target.lat))) * sin(target.track)

// Vertical extrapolation
new_alt = target.altitude + target.verticalRate * (elapsed / 60)  // vrate in fpm
```

### 3.2 Interpolation Constraints

| Constraint | Value | Rationale |
|------------|-------|-----------|
| Max interpolation time | 15 seconds | Beyond this, error accumulates too much. Target freezes in place and shows "stale" indicator. |
| Max extrapolation distance | 5 nm from last known position | Prevents runaway extrapolation if a target goes off-radar. |
| Turn rate assumption | 0 (straight-line only) | We don't attempt to predict turns. Future enhancement could use historical track rate-of-change. |
| Speed change assumption | Constant groundspeed | No acceleration modeling. Acceptable for 10-second intervals. |
| Vertical rate damping | None | Constant climb/descent rate. Acceptable for 10-second intervals. |

### 3.3 Position Blending on Update

When a new data update arrives, the target's position may differ from the interpolated position. To prevent a visual snap:

```
1. Compute interpolated position at time of new update
2. Compute error vector: (actual - interpolated)
3. If error < 0.5 nm: blend over 1 second (ease-out)
4. If error ≥ 0.5 nm: snap immediately (target likely maneuvered)
```

This keeps motion smooth during straight-line flight while quickly correcting after turns or maneuvers.

---

## 4. Projected Flight Path Heads

Each traffic target displays "heads" — projected future positions showing where the aircraft will likely be if it maintains its current track, speed, and vertical rate.

### 4.1 Rendering

```
               ▲ N456AB          ← current target icon
              ╱  +3 ↑ 4,500'       with altitude tag
             ╱
            ╱  - - - ◇ 2 min    ← 2-minute projected position (ghost icon)
           ╱
          ╱
         ╱   - - - - ◇ 5 min    ← 5-minute projected position (ghost icon)
```

| Element | Rendering |
|---------|-----------|
| Leader line | Dashed line from current position extending along current track. Length proportional to groundspeed. |
| 2-minute head | Small hollow diamond (◇) at the position the target will reach in 2 minutes. Labeled "2" or "2 min." Same color as target but at 60% opacity. |
| 5-minute head | Smaller hollow diamond at 5-minute projected position. Labeled "5" or "5 min." Same color at 40% opacity. |
| Altitude annotation | Each head shows projected altitude if climbing/descending. E.g., "5,200↑" at the 2-min head if target is climbing through 4,500 at +350 fpm. |
| Vertical trend arrow | ↑ climbing, ↓ descending, — level. Shown at current position and optionally at heads. |

### 4.2 Head Position Calculation

Same dead-reckoning as interpolation, but projected forward:

```
For each head interval T (120s, 300s):
  distance_nm = groundspeed * (T / 3600)
  head_lat = lat + (distance_nm / 60) * cos(track)
  head_lon = lon + (distance_nm / (60 * cos(lat))) * sin(track)
  head_alt = altitude + verticalRate * (T / 60)
```

### 4.3 Head Configuration

| Setting | Default | Options |
|---------|---------|---------|
| Show heads | On | On / Off |
| Head intervals | 2 min, 5 min | User-configurable: 1, 2, 3, 5, 10 min. Up to 3 intervals simultaneously. |
| Show on all targets | Proximate + Alert only | All targets / Proximate + Alert only / Alert only / Off |
| Show projected altitude | On (when climbing/descending) | On / Off |

### 4.4 Accuracy Disclaimer

Projected heads are straight-line extrapolations only. They do not account for:
- Turns (heading changes)
- Speed changes (acceleration/deceleration)
- ATC instructions or flight plan routing
- Altitude level-offs (step climbs, assigned altitudes)

The heads are a situational awareness aid — they show "if nothing changes" projections. The UI should not imply certainty. Ghost icons use reduced opacity and dashed lines to visually communicate uncertainty.

---

## 5. Polling & Data Flow

### 5.1 API Polling Cycle

```
┌─────────────────────────────────────────────────────┐
│                   POLLING LOOP                       │
│                                                     │
│  1. Determine query center:                         │
│     - If ownship GPS available → ownship position   │
│     - Else → selected airport or last known position│
│                                                     │
│  2. Fetch from active API backend                   │
│     GET /point/{lat}/{lon}/{radius}                  │
│                                                     │
│  3. Normalize response → List<TrafficTarget>        │
│                                                     │
│  4. Merge into active target map:                   │
│     - Match by ICAO hex address                     │
│     - Update existing targets (blend position)      │
│     - Add new targets                               │
│     - Mark unseen targets as stale                  │
│                                                     │
│  5. Recompute relative geometry:                    │
│     - Bearing & distance from ownship               │
│     - Altitude delta                                │
│     - Threat level                                  │
│                                                     │
│  6. Recalculate projected heads (2 min, 5 min)      │
│                                                     │
│  7. Sleep for poll interval (default 10s)           │
│     During sleep: interpolation runs on render loop  │
│                                                     │
│  8. Repeat                                          │
└─────────────────────────────────────────────────────┘
```

### 5.2 Target Lifecycle

| State | Condition | Display |
|-------|-----------|---------|
| **Active** | Updated within last poll interval | Full icon, labels, and heads |
| **Interpolating** | Between polls, position being dead-reckoned | Full icon (animated position), labels, and heads |
| **Stale** | Not updated for 2 consecutive polls (>20s for API, >5s for GDL 90) | Faded icon (50% opacity), heads removed, "?" indicator |
| **Expired** | Not updated for 60 seconds | Removed from map and target list |

### 5.3 Query Radius

| Context | Default Radius | Rationale |
|---------|---------------|-----------|
| On ground, viewing airport area | 30 nm | Local traffic pattern, arrivals, departures |
| On ground, zoomed out | 50 nm | Broader area awareness for planning |
| In flight (API fallback) | 50 nm | Situational awareness when ADS-B receiver is unavailable |
| In flight (GDL 90) | N/A (receiver range) | ADS-B receiver provides all targets within radio range (~100+ nm) |

### 5.4 Bandwidth & Battery Considerations

| Concern | Mitigation |
|---------|-----------|
| Cellular data usage | At 10s intervals with ~50 targets, each API response is ~5–15 KB. ~90 KB/min, ~5.4 MB/hr. Minimal. |
| Battery drain (polling) | Timer-based polling only when traffic layer is visible. Pause polling when app is backgrounded. Reduce poll frequency to 30s when screen is off. |
| Battery drain (interpolation) | Interpolation runs on the render loop only when map is visible. No computation when traffic layer is hidden or app is backgrounded. |
| API rate limits | Respect per-backend rate limits. Airplanes.live: 1 req/s max (10s interval is well within). OpenSky: track daily credit usage, warn user when approaching limit. |

---

## 6. Data Model

### 6.1 Entity: `TrafficTarget` (In-Memory)

Unified model used by all sources. Not persisted to database.

| Field | Type | Source Mapping | Description |
|-------|------|---------------|-------------|
| `icaoHex` | String | `hex` / `icao24` / ICAO address | 24-bit ICAO Mode S address (hex string). Primary key for deduplication. |
| `callsign` | String? | `flight` / `callsign` | Flight number or tail number. May be null. |
| `latitude` | double | API response / GDL 90 decode | Last known latitude (decimal degrees). |
| `longitude` | double | API response / GDL 90 decode | Last known longitude (decimal degrees). |
| `altitude` | int? | `alt_baro` / `baro_altitude` | Pressure altitude (feet MSL). Null if unknown. |
| `groundspeed` | double? | `gs` / `velocity` | Groundspeed (knots). Null if unknown. |
| `track` | double? | `track` / `true_track` | True track (degrees, 0–360). Null if unknown. |
| `verticalRate` | int? | `baro_rate` / `vertical_rate` | Feet per minute, signed. Positive = climbing. Null if unknown. |
| `squawk` | String? | `squawk` | Transponder squawk code (4-digit octal string). |
| `emitterCategory` | EmitterCategory | `category` / emitter byte | Aircraft type classification. |
| `onGround` | bool | `on_ground` / misc bits | Whether the target is on the ground. |
| `lastUpdated` | DateTime | Computed from `seen` or receive time | When the position was last updated. |
| `positionAge` | Duration | Computed | Time since position was last updated by the data source (not interpolation). |
| `source` | TrafficSource | Set by backend | `gdl90`, `airplanesLive`, `openSky`, `adsbExchange`, `flightAware` |
| `interpolatedLat` | double | Computed | Current interpolated latitude for rendering. |
| `interpolatedLon` | double | Computed | Current interpolated longitude for rendering. |
| `interpolatedAlt` | int? | Computed | Current interpolated altitude for rendering. |
| `threatLevel` | ThreatLevel | Computed | `none`, `proximate`, `alert`, `resolution` |
| `relativeBearing` | double? | Computed | Bearing from ownship (degrees). Null if no ownship position. |
| `relativeDistance` | double? | Computed | Distance from ownship (nm). Null if no ownship position. |
| `relativeAltitude` | int? | Computed | Altitude difference from ownship (feet). Null if no ownship or target altitude. |
| `heads` | List\<ProjectedHead\> | Computed | Projected future positions. |

### 6.2 Entity: `ProjectedHead` (Computed, In-Memory)

| Field | Type | Description |
|-------|------|-------------|
| `intervalSeconds` | int | Projection interval (e.g., 120, 300). |
| `latitude` | double | Projected latitude. |
| `longitude` | double | Projected longitude. |
| `altitude` | int? | Projected altitude (feet MSL). Null if target altitude or vertical rate unknown. |
| `distanceFromTarget` | double | Distance from current target position to this head (nm). |

### 6.3 Enum: `EmitterCategory`

Mapped from ADS-B emitter category codes:

| Value | Code | Description |
|-------|------|-------------|
| `unknown` | 0 | No category information |
| `light` | 1 | Light (<15,500 lbs) |
| `small` | 2 | Small (15,500–75,000 lbs) |
| `large` | 3 | Large (75,000–300,000 lbs) |
| `highVortexLarge` | 4 | High vortex large (e.g., B757) |
| `heavy` | 5 | Heavy (>300,000 lbs) |
| `highPerformance` | 6 | High performance (>5g, >400 kts) |
| `rotorcraft` | 7 | Rotorcraft |
| `glider` | 9 | Glider / sailplane |
| `lighterThanAir` | 10 | Balloon / blimp |
| `parachutist` | 11 | Skydiver |
| `ultralight` | 12 | Ultralight / hang glider |
| `uav` | 14 | Unmanned aerial vehicle |
| `spaceship` | 15 | Space / transatmospheric vehicle |
| `emergencyVehicle` | 17 | Surface emergency vehicle |
| `serviceVehicle` | 18 | Surface service vehicle |
| `pointObstacle` | 19 | Obstacle / fixed structure |

### 6.4 Enum: `TrafficSource`

| Value | Description |
|-------|-------------|
| `gdl90` | ADS-B receiver via GDL 90 protocol |
| `airplanesLive` | Airplanes.live REST API |
| `openSky` | OpenSky Network REST API |
| `adsbExchange` | ADS-B Exchange via RapidAPI |
| `flightAware` | FlightAware AeroAPI |

---

## 7. UI Design

### 7.1 Traffic Map Layer

Traffic targets rendered on the moving map with interpolated positions and projected heads:

```
                         ◇ 5 min (3,800')
                        ╱
                   ◇ 2 min (4,100')
                  ╱
          ▲ N456AB
       +3 ↑ 4,500'                    ← Active target, climbing

                     ▽ UAL472
                  -12 — FL350          ← Airline traffic, level

       ◆                               ← Ownship (centered)

            △ ??                       ← Target with no callsign, on ground
```

| Element | Rendering |
|---------|-----------|
| Target icon | Filled chevron (▲) for airborne, hollow (△) for on-ground. Points in direction of track. Size scales slightly with emitter category (heavy > light). |
| Callsign | Displayed adjacent to icon. Falls back to ICAO hex if no callsign. "??" if both unknown. |
| Altitude tag | Relative altitude in hundreds of feet: `+3` = 300 ft above ownship, `-12` = 1,200 ft below. Absolute altitude shown when no ownship altitude reference. |
| Vertical trend | ↑ climbing (>200 fpm), ↓ descending (<-200 fpm), — level. |
| Leader line | Dashed line from target along track to projected heads. Color matches target. |
| 2-min head | Hollow diamond (◇) at 60% opacity. Shows projected altitude if climbing/descending. |
| 5-min head | Smaller hollow diamond at 40% opacity. Shows projected altitude. |
| Color coding | White = no threat. Yellow = proximate. Red = alert/resolution. |
| Stale target | 50% opacity, no heads, small "?" badge. |

### 7.2 Traffic Source Indicator

Shown in the map status area or traffic layer toggle:

```
┌─────────────────────────────────────────────────┐
│  TFC: 12  |  Source: Airplanes.live  |  ⟳ 8s   │
└─────────────────────────────────────────────────┘
```

- Target count, active data source name, time until next poll (countdown)
- When using GDL 90: `Source: Stratux (ADS-B)  |  Live`
- Tap to open traffic settings

### 7.3 Traffic List View

Accessible via a panel/drawer from the map screen:

```
┌──────────────────────────────────────────────────────────┐
│  TRAFFIC (12 targets)                    Sort: Distance ▼│
├──────────────────────────────────────────────────────────┤
│  ▲ N456AB    4,500' (+300)   120kt   2.3 nm   045°  ↑  │
│  ▲ UAL472    FL350 (-1200)   280kt   8.1 nm   190°  —  │
│  ▲ SKW3341   6,200' (+800)   180kt  12.4 nm   310°  ↓  │
│  △ N789CD    GND              0kt    0.4 nm   090°  —  │
│  ...                                                     │
└──────────────────────────────────────────────────────────┘
```

| Column | Description |
|--------|-------------|
| Icon + Callsign | Emitter icon and callsign/tail number |
| Altitude | Absolute altitude. Relative delta in parentheses (hundreds of feet). |
| Groundspeed | In knots |
| Distance | From ownship in nautical miles |
| Bearing | From ownship in degrees |
| Trend | ↑ climbing, ↓ descending, — level |

Sort options: Distance (default), Altitude, Callsign, Threat Level.

Tap a row to center the map on that target and highlight it.

### 7.4 Traffic Settings Screen

| Section | Contents |
|---------|----------|
| **Data Source** | Dropdown: Auto (prefer ADS-B, fall back to API) / ADS-B Only / API Only. Default: Auto. |
| **API Backend** | Dropdown: Airplanes.live (default) / OpenSky Network / ADS-B Exchange / FlightAware AeroAPI. |
| **API Key** | Text field for backends that require a key. Stored in secure storage. Show validation status. |
| **Poll Interval** | Slider: 5s / 10s (default) / 15s / 30s. Shows data usage estimate. |
| **Query Radius** | Slider: 10 / 30 (default) / 50 / 100 nm. |
| **Altitude Filter** | Range slider: ±1,000 / ±3,000 (default) / ±5,000 / ±10,000 / Unlimited ft from ownship or field elevation. |
| **Projected Heads** | Toggle: On (default) / Off. Sub-options: intervals (1, 2, 3, 5, 10 min checkboxes, default 2+5), show on (all / proximate+ / alert only). |
| **Audio Alerts** | Toggle: On (default) / Off. Sub-options: alert threshold (proximate / alert / resolution). |

---

## 8. Frontend State Management

| Provider | Type | Purpose |
|----------|------|---------|
| `trafficSourceProvider` | `StateNotifierProvider` | Manages the active traffic source (GDL 90 vs API backend). Handles auto-switching logic. |
| `trafficBackendProvider` | `Provider` | Returns the configured `TrafficBackend` implementation based on user settings. |
| `trafficPollingProvider` | `StreamProvider` | Drives the API polling loop. Emits raw traffic data at the configured interval. Pauses when app is backgrounded or traffic layer is hidden. |
| `trafficTargetsProvider` | `StateNotifierProvider` | Map of ICAO hex → `TrafficTarget`. Merges updates from polling or GDL 90, manages target lifecycle (active → stale → expired), triggers position blending. |
| `trafficInterpolationProvider` | `Provider` | Runs on the render loop (~60 fps). Updates `interpolatedLat`, `interpolatedLon`, `interpolatedAlt` for each active target. |
| `trafficHeadsProvider` | `Provider` | Computes projected heads for each target based on current state and user-configured intervals. Recomputed on each poll update. |
| `trafficThreatProvider` | `Provider` | Derived: computes threat level for each target relative to ownship. Triggers audio alerts on state transitions. |
| `trafficSettingsProvider` | `StateProvider` | User preferences: backend, poll interval, radius, altitude filter, head intervals, audio toggle. Persisted to local storage. |

---

## 9. Backend (API Server)

### 9.1 Proxy Endpoint (Optional)

For backends that require API keys, the EFB backend can optionally proxy requests to avoid exposing keys in the mobile app:

```
GET /api/traffic/nearby?lat={lat}&lon={lon}&radius={radius}
```

Response: Normalized `TrafficTarget[]` array regardless of upstream backend.

However, the **default architecture is client-direct** — the mobile app calls the traffic API directly. This avoids adding latency through the backend and keeps the backend stateless for traffic. The proxy is only needed if:
- The user wants to keep API keys server-side
- A backend requires server-to-server authentication (not currently the case for any supported backend)

### 9.2 No Backend Storage

Traffic data is entirely ephemeral. No traffic positions are stored in PostgreSQL. The backend has no traffic tables or entities. All processing happens client-side.

---

## 10. Implementation Phases

### Phase 1 — API Traffic (Ground-Based Awareness)

| Feature | Details | Depends On |
|---------|---------|------------|
| Traffic backend interface | Define `TrafficBackend` abstract class and `TrafficTarget` model | — |
| Airplanes.live backend | Implement `AirplanesLiveBackend` with fetch, normalize, error handling | Backend interface |
| Polling service | Timer-based polling loop with configurable interval, pause/resume | Backend implementation |
| Target management | Target map with merge, stale detection, expiration | Polling service |
| Position interpolation | Dead-reckoning extrapolation on render loop with blending on update | Target management |
| Projected heads | Compute and render 2-min and 5-min projected positions | Target management |
| Traffic map layer | Render targets with icons, labels, altitude tags, heads on moving map | Interpolation, Heads, Maps module |
| Traffic list view | Sortable list panel showing all active targets | Target management |
| Traffic settings | Backend selection, poll interval, radius, altitude filter, head config | — |

### Phase 2 — ADS-B Integration

| Feature | Details | Depends On |
|---------|---------|------------|
| GDL 90 traffic source | Adapt GDL 90 traffic reports into unified `TrafficTarget` model | Phase 1, ADS-B module Phase 1 |
| Auto source switching | Detect ADS-B receiver connection, switch source, fall back on disconnect | GDL 90 source |
| Threat classification | Compute threat levels relative to ownship, color coding | Phase 1 |
| Audio alerts | Spoken callouts on threat level transitions | Threat classification |

### Phase 3 — Additional Backends & Polish

| Feature | Details | Depends On |
|---------|---------|------------|
| OpenSky backend | Implement `OpenSkyBackend` with unit conversion and bounding-box queries | Phase 1 |
| ADS-B Exchange backend | Implement `AdsbExchangeBackend` with RapidAPI auth | Phase 1 |
| FlightAware backend | Implement `FlightAwareBackend` with AeroAPI auth | Phase 1 |
| Backend proxy endpoint | Optional NestJS endpoint for server-side API key management | Phase 1 |
| Turn rate prediction | Use track history to improve head accuracy during turns (future enhancement) | Phase 1 |

---

## 11. Open Questions

| Question | Options | Decision |
|----------|---------|----------|
| Should heads account for known altitude constraints? | Simple (current track/speed/vrate only) vs. Enhanced (snap to assigned altitudes from squawk/mode-C) | **Simple for MVP.** No reliable way to know assigned altitude from ADS-B data alone. |
| Should traffic data be available offline? | No (traffic is inherently real-time) vs. Cache last-known positions for a few minutes after connectivity loss | **Cache briefly** — show last-known positions fading out over 60s after connectivity loss. |
| Should we show ground vehicles? | Some ADS-B feeds include airport ground vehicles (emitter category 17/18) | **Filter out by default**, allow toggle in settings for airport awareness. |
| Proxy vs. client-direct for API calls? | Client-direct (lower latency, simpler) vs. Proxy (hides API keys, single point of control) | **Client-direct for free APIs** (Airplanes.live). Offer proxy option for keyed APIs. |

---

## 12. References

| Resource | URL | Description |
|----------|-----|-------------|
| Airplanes.live API Guide | [airplanes.live/api-guide](https://airplanes.live/api-guide/) | REST API documentation and field descriptions |
| Airplanes.live Field Descriptions | [airplanes.live/rest-api-adsb-data-field-descriptions](https://airplanes.live/rest-api-adsb-data-field-descriptions/) | Detailed field-by-field reference |
| OpenSky Network API | [openskynetwork.github.io/opensky-api](https://openskynetwork.github.io/opensky-api/) | REST API documentation |
| ADS-B Exchange API | [adsbexchange.com/data](https://www.adsbexchange.com/data/) | Data access and API information |
| FlightAware AeroAPI | [flightaware.com/commercial/aeroapi](https://www.flightaware.com/commercial/aeroapi/) | Commercial flight data API |
| ADS-B Integration Module | [adsb-integration.md](./adsb-integration.md) | GDL 90 protocol, receiver connection, traffic data model |

---

## 13. Implementation Status

**Not Started** — This module has no implementation yet. The ADS-B Integration module spec (Phase 2 traffic) provides the GDL 90 traffic source. This module adds the unified traffic layer, API backends, interpolation, and projected heads on top of that foundation.
