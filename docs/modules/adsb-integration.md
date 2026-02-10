# ADS-B & TIS-B Integration Module
## EFB Product Specification

[← Back to Core Specification](../EFB_Product_Specification_v1.md)

---

The ADS-B Integration module provides real-time situational awareness by connecting the EFB to portable ADS-B receivers via the GDL 90 protocol — an open FAA-published standard. This delivers ownship GPS position, traffic targets, FIS-B weather, and AHRS attitude data. All data is processed client-side over the local WiFi network with no backend involvement.

This module is separate from the [Garmin Avionics Data Integration](./avionics-integration.md) module, which covers post-flight flight data import (flight times, fuel, engine parameters) from Garmin flight decks.

---

## 1. Core Features

| Feature | Details | Complexity |
|---------|---------|------------|
| GDL 90 Receiver | Receive and decode GDL 90 messages over UDP port 4000 from any compatible ADS-B receiver (Stratux, Sentry, Garmin GDL 50/52, SkyEcho, etc.). | High |
| Ownship Position | Use GPS position from GDL 90 ownship reports for moving map, ownship icon, and track recording. Falls back to device GPS when no external source is connected. | Medium |
| ADS-B Traffic Display | Display traffic targets on the moving map with altitude, groundspeed, heading, and callsign. TargetTrend-style relative motion vectors. Configurable altitude filter. | High |
| FIS-B Weather Ingest | Decode FIS-B uplink data (UAT message ID 7) for NEXRAD radar, METARs, TAFs, PIREPs, winds aloft, NOTAMs, AIRMETs/SIGMETs, and TFRs received over ADS-B In. | Very High |
| AHRS Attitude Data | Receive pitch, roll, heading, IAS, and TAS from ForeFlight Extended GDL 90 messages (ID 0x65, sub-ID 0x01) at 5 Hz. Display on a backup attitude indicator widget. | Medium |
| Device Discovery | Auto-detect ADS-B receivers on the local WiFi network. Support Stratux mDNS/HTTP discovery, ForeFlight GDL 90 discovery broadcast (UDP port 63093), and manual IP entry. | Medium |
| Connection Status | Persistent status indicator showing receiver connection state, GPS fix quality, satellite count, traffic target count, and FIS-B age. | Low |
| Stratux REST Integration | Connect to Stratux HTTP API for enhanced status, settings, and AHRS data beyond standard GDL 90. | Low |

---

## 2. What ADS-B Provides (and What It Does Not)

### Data Available via ADS-B / GDL 90

| Data | Source | Rate |
|------|--------|------|
| GPS position (lat/lon/altitude) | Ownship Report (0x0A) | 1 Hz |
| Groundspeed and track | Ownship Report (0x0A) | 1 Hz |
| Pressure altitude | Ownship Report (0x0A) | 1 Hz |
| GPS geometric altitude | Ownship Geo Altitude (0x0B) | 1 Hz |
| Traffic targets (position, altitude, callsign, velocity) | Traffic Report (0x14) | As received |
| FIS-B weather (NEXRAD, METARs, TAFs, PIREPs, TFRs, AIRMETs) | UAT Uplink (0x07) | Varies by product |
| AHRS attitude (pitch, roll, heading) | ForeFlight Extended (0x65) | 5 Hz |
| IAS / TAS | ForeFlight Extended (0x65) | 5 Hz |
| Height above terrain | HAT (0x09) | 1 Hz |

### Data NOT Available via ADS-B

These require Garmin Connext (proprietary) or post-flight SD card CSV import — see [Garmin Avionics Data Integration](./avionics-integration.md):

- Hobbs / tach time
- Flight time counters
- Engine data (CHT, EGT, oil temp/pressure, fuel flow, RPM, MAP)
- Fuel quantity / fuel remaining
- Flight plan / route from avionics
- Two-way flight plan transfer
- Avionics database management

---

## 3. GDL 90 Protocol Specification

### 3.1 Framing

Based on asynchronous HDLC (High-Level Data Link Control):

```
┌──────┬───────────┬─────────────────────────┬──────────┬──────┐
│ Flag │ Message ID│    Message Data          │ FCS (CRC)│ Flag │
│ 0x7E │  1 byte   │    variable length       │  2 bytes │ 0x7E │
└──────┴───────────┴─────────────────────────┴──────────┴──────┘
```

- **Flag byte**: `0x7E` marks start and end of each message
- **Byte stuffing**: `0x7D` is the escape byte. `0x7E` in payload → `0x7D 0x5E`. `0x7D` in payload → `0x7D 0x5D`.
- **FCS**: 16-bit CRC appended before trailing flag (CRC-CCITT, polynomial 0x1021)
- **Byte order**: All multibyte fields are **big-endian**

### 3.2 Message Types

| Message ID | Name | Rate | Payload Size | Description |
|------------|------|------|-------------|-------------|
| `0x00` | Heartbeat | 1 Hz | 7 bytes | GPS validity, UTC timestamp, status flags |
| `0x07` | UAT Uplink | As received | 436 bytes | FIS-B weather/TFR data (432-byte UAT payload + time/header) |
| `0x09` | Height Above Terrain | 1 Hz | 2 bytes | Terrain-derived height (not always available) |
| `0x0A` | Ownship Report | 1 Hz | 28 bytes | Own aircraft GPS position, altitude, accuracy, velocity |
| `0x0B` | Ownship Geometric Altitude | 1 Hz | 5 bytes | GPS altitude at 5-foot resolution, vertical metrics |
| `0x14` | Traffic Report | As received | 28 bytes | Other aircraft — same format as Ownship Report |

### 3.3 Ownship Report (0x0A) — 28 bytes

This is the primary position message. Fields:

| Offset | Field | Size | Encoding |
|--------|-------|------|----------|
| 0 | Status | 1 byte | Bits 7–4: participant address type, bits 3–0: alert status |
| 1–3 | Participant Address | 3 bytes | ICAO Mode S address (24-bit) |
| 4–6 | Latitude | 3 bytes | Signed, 180/2^23 degrees per LSB |
| 7–9 | Longitude | 3 bytes | Signed, 180/2^23 degrees per LSB |
| 10–11 | Altitude | 12 bits | Pressure altitude, 25 ft per LSB, offset -1000 ft. `0xFFF` = invalid |
| 11 | Misc | 4 bits | Airborne/ground, report type, TT indicator |
| 12 | NIC | 4 bits | Navigation Integrity Category |
| 12 | NACp | 4 bits | Navigation Accuracy Category for Position |
| 13–14 | Horizontal Velocity | 12 bits | Knots, `0xFFF` = invalid |
| 14–15 | Vertical Velocity | 12 bits | 64 fpm per LSB, signed, `0x800` = invalid |
| 16 | Track/Heading | 8 bits | 360/256 degrees per LSB |
| 17 | Emitter Category | 1 byte | Aircraft type (light, large, rotorcraft, etc.) |
| 18–25 | Callsign | 8 bytes | ASCII, space-padded |
| 26 | Emergency/Priority | 4 bits | Emergency code |
| 26 | Spare | 4 bits | Reserved |

Traffic Report (0x14) uses the identical 28-byte format.

### 3.4 Heartbeat (0x00) — 7 bytes

| Offset | Field | Size | Description |
|--------|-------|------|-------------|
| 0 | Status Byte 1 | 1 byte | Bit 7: GPS position valid, Bit 0: UAT initialized |
| 1 | Status Byte 2 | 1 byte | Bit 7: timestamp MSB, Bit 5: CSA requested, Bit 0: UTC OK |
| 2–3 | Timestamp | 16 bits | Seconds since midnight UTC (combined with bit 7 of byte 1) |
| 4–5 | Message Counts | 2 bytes | Uplink and basic/long message reception counts |

### 3.5 ForeFlight Extended Messages (0x65)

ForeFlight publishes an open extension spec. Message ID `0x65` with sub-IDs:

**Sub-ID 0x00 — Device ID Message** (sent once at connection):

| Offset | Field | Size | Description |
|--------|-------|------|-------------|
| 0 | Sub-ID | 1 byte | `0x00` |
| 1 | Version | 1 byte | `0x01` |
| 2–9 | Device Serial | 8 bytes | ASCII serial number |
| 10–17 | Device Name | 8 bytes | ASCII short name |
| 18–33 | Device Long Name | 16 bytes | ASCII extended name |
| 34–37 | Capabilities | 4 bytes | Bitmask (AHRS, ADS-B In, GPS, etc.) |

**Sub-ID 0x01 — AHRS Message** (transmitted at 5 Hz):

| Offset | Field | Size | Encoding |
|--------|-------|------|----------|
| 0 | Sub-ID | 1 byte | `0x01` |
| 1–2 | Roll | 2 bytes | Signed, 1/10 degree units. Positive = right wing down. `0x7FFF` = invalid |
| 3–4 | Pitch | 2 bytes | Signed, 1/10 degree units. Positive = nose up. `0x7FFF` = invalid |
| 5–6 | Heading | 2 bytes | Bit 15: 0 = true, 1 = magnetic. Bits 14–0: 1/10 degree. `0x7FFF` = invalid |
| 7–8 | Indicated Airspeed | 2 bytes | Knots. `0xFFFF` = invalid |
| 9–10 | True Airspeed | 2 bytes | Knots. `0xFFFF` = invalid |

### 3.6 Stratux Extended Messages

Stratux (open-source ADS-B receiver) adds three non-standard messages:

| Message ID | Name | Description |
|------------|------|-------------|
| `0xCC` | Stratux Heartbeat | Device status, GPS satellites, connected clients |
| `0x5358` | Stratux Alt Heartbeat | Alternative heartbeat (2-byte message ID) |
| `0x4C` | Stratux AHRS | Roll, pitch, heading, G-load from built-in IMU |

These should be parsed when present but are not required — Stratux also sends standard GDL 90 messages.

---

## 4. Device Discovery & Connection

### 4.1 Network Architecture

ADS-B receivers create a WiFi access point (or join an existing network). Data flows:

```
┌─────────────────┐       WiFi        ┌───────────────────┐
│  ADS-B Receiver  │ ──── UDP:4000 ──→ │  EFB App (iPad)    │
│  (Stratux/Sentry)│                   │                     │
│                  │ ←── Discovery ──  │  Listens UDP:4000   │
│  IP: 192.168.x.1│    UDP:63093      │  Sends discovery    │
└─────────────────┘                   └───────────────────┘
```

### 4.2 Discovery Methods

| Method | Source | Protocol | Details |
|--------|--------|----------|---------|
| ForeFlight Discovery | Sentry, Stratux, others | UDP broadcast on port 63093 | JSON: `{"App":"EFB","GDL90":{"port":4000}}`. Sent every 5 sec. |
| Stratux HTTP API | Stratux | HTTP `GET /getStatus` | Default IP: `192.168.10.1`. Returns JSON with device info, GPS status, connected clients. |
| Manual IP Entry | Any | User-configured | User enters receiver IP address manually. App sends GDL 90 listen on UDP:4000 to that IP. |
| Bonjour/mDNS | Some receivers | mDNS service type `_gdl90._udp` | Not universally supported but worth listening for. |

### 4.3 Connection Lifecycle

```
1. SCANNING     — Listen for discovery broadcasts on UDP:63093
                  Probe known IPs (192.168.10.1, 192.168.1.1)
                  Listen for mDNS announcements

2. CONNECTING   — Begin listening for GDL 90 on UDP:4000
                  Send ForeFlight-style discovery response (optional)

3. CONNECTED    — Receiving heartbeat messages at 1 Hz
                  Parse ownship, traffic, weather, AHRS
                  Update connection status indicator

4. STALE        — No heartbeat received for 5 seconds
                  Show warning, continue listening

5. DISCONNECTED — No heartbeat for 30 seconds
                  Clear traffic display
                  Fall back to device GPS
                  Return to SCANNING
```

### 4.4 Multiple Receiver Handling

If multiple receivers are detected, display a chooser. Only one active connection at a time. Priority:
1. User's last-selected receiver (persisted preference)
2. Receiver with strongest signal / most recent heartbeat
3. First discovered

---

## 5. Data Processing Pipeline

### 5.1 Ownship GPS

```
GDL 90 Ownship Report (1 Hz)
  → Decode lat/lon/altitude/groundspeed/track
  → Validate: GPS position valid (heartbeat bit 7)?
  → Compare accuracy (NIC/NACp) with device GPS
  → If external GPS is higher quality or device GPS unavailable:
      → Use as primary position source
      → Feed to moving map (ownship icon position)
      → Feed to track recorder
      → Feed to nearest airport calculations
  → Store last-known position for glide ring calculations
```

**GPS Source Priority:**
1. GDL 90 ownship with valid fix (certified GPS accuracy, typically WAAS)
2. Device GPS (iPad/phone internal GPS)
3. No position available

### 5.2 Traffic

```
GDL 90 Traffic Report (as received)
  → Decode ICAO address, lat/lon, altitude, velocity, callsign
  → Deduplicate: key on ICAO address + source
  → Age out: remove targets not updated in 60 seconds
  → Calculate relative: bearing, distance, altitude delta from ownship
  → Classify threat level:
      - Proximate:  <6 nm horizontal, ±1200 ft vertical
      - Alert:      <3 nm horizontal, ±600 ft vertical
      - Resolution: <1 nm horizontal, ±300 ft vertical
  → Feed to traffic map layer
  → Feed to traffic alerting system (audio callout: "Traffic, 2 o'clock, 3 miles, same altitude")
```

### 5.3 FIS-B Weather

FIS-B (Flight Information Services — Broadcast) is embedded in UAT uplink messages (ID 0x07). The 432-byte payload contains:

| FIS-B Product ID | Product | Update Rate | Coverage |
|-----------------|---------|-------------|----------|
| 8 | NEXRAD (CONUS) | 5 min | Regional |
| 13 | NEXRAD (Regional) | 2.5 min | ~250 nm |
| 63 | METARs | As updated | ~250 nm |
| 64 | TAFs | As updated | ~250 nm |
| 70 | PIREPs | As updated | ~250 nm |
| 80–83 | Winds/Temp Aloft | 12 hrs | Regional |
| 103–106 | TFR (Text/Graphic) | As updated | ~250 nm |
| 11, 12 | AIRMETs/SIGMETs | As updated | ~250 nm |

**Decoding FIS-B is complex** — each product has its own encoding scheme defined in TSO-C157a and DO-267A. The NEXRAD radar products use a run-length encoded raster format mapped to a geographic grid.

**Phase 1 approach**: Parse METARs, TAFs, and TFR text products (simpler text-based formats). Defer NEXRAD raster decoding to Phase 2 (significantly more complex).

### 5.4 AHRS

```
ForeFlight AHRS Message (5 Hz)
  → Decode roll, pitch, heading, IAS, TAS
  → Validate: check for invalid markers (0x7FFF, 0xFFFF)
  → Smooth: apply low-pass filter to reduce jitter
  → Feed to attitude indicator widget
  → Feed to heading indicator
  → Store for flight data recording
```

---

## 6. Compatible Hardware

| Device | GDL 90 | AHRS | GPS | FIS-B | Price Range | Notes |
|--------|--------|------|-----|-------|-------------|-------|
| **Stratux** (DIY) | Yes | Yes (IMU) | Yes (WAAS) | Yes (978/1090) | $100–200 | Open-source. REST API + WebSocket. Most customizable. |
| **ForeFlight Sentry / Sentry Plus** | Yes | Yes | Yes (WAAS) | Yes (978/1090) | $500–1,000 | Follows ForeFlight Extended GDL 90 spec. CO monitor. |
| **Garmin GDL 50/52** | Yes | No | Yes (WAAS) | Yes (978) | $600–900 | Standard GDL 90 output. No AHRS. |
| **uAvionix SkyEcho 2** | Yes | No | Yes | Yes (1090 only) | $500 | Popular in Europe. 1090 MHz only (no 978 UAT). |
| **Appareo Stratus 3** | Limited | Yes | Yes | Yes (978/1090) | $900 | Primarily targets ForeFlight; may use proprietary extensions. |
| **Levil Aviation BOM** | Yes | Yes | Yes | Yes (978/1090) | $1,200 | Includes AHRS. Less common. |
| **iLevil 3 AW** | Yes | Yes | Yes (WAAS) | Yes (978/1090) | $1,800 | 3x RS-232 serial ports for avionics bridging. NORSEE approved. |

**Not compatible (proprietary protocol):**
- Garmin GDL 39 / GDL 39-3D (encrypted Bluetooth)
- Garmin Flight Stream 510/210/110 (Connext Bluetooth)
- Garmin GDL 60 (Connext Bluetooth + LTE)

---

## 7. Data Model

### 7.1 Entity: `AdsReceiver`

Represents a known ADS-B receiver the user has connected to.

| Field | Type | Description |
|-------|------|-------------|
| `id` | int (PK) | Auto-generated |
| `name` | varchar | User-facing name (e.g., "My Stratux", "Sentry Plus") |
| `device_serial` | varchar, nullable | Serial number from GDL 90 Device ID message |
| `device_type` | enum | `stratux`, `sentry`, `gdl50`, `gdl52`, `skyecho`, `ilevil`, `generic` |
| `ip_address` | varchar, nullable | Manual IP override (null = auto-discover) |
| `last_connected_at` | timestamp, nullable | Last successful connection |
| `is_preferred` | boolean | Preferred receiver for auto-connect |
| `capabilities` | jsonb | Bitmask/flags: `{ ahrs: bool, gps: bool, adsb_in: bool, uat: bool, es1090: bool }` |

### 7.2 Entity: `TrafficTarget`

In-memory only (not persisted). Represents a single ADS-B traffic target.

| Field | Type | Description |
|-------|------|-------------|
| `icao_address` | int (24-bit) | ICAO Mode S address — primary key |
| `callsign` | varchar(8) | Callsign / tail number (space-padded) |
| `latitude` | double | Decimal degrees |
| `longitude` | double | Decimal degrees |
| `altitude` | int | Pressure altitude (feet MSL) |
| `groundspeed` | int | Knots |
| `track` | int | Track angle (degrees true) |
| `vertical_rate` | int | Feet per minute (signed) |
| `emitter_category` | enum | Light, large, heavy, rotorcraft, glider, UAV, etc. |
| `nic` | int | Navigation Integrity Category (0–11) |
| `nacp` | int | Navigation Accuracy Category (0–11) |
| `last_updated` | timestamp | Time of last report |
| `threat_level` | enum | `none`, `proximate`, `alert`, `resolution` |
| `relative_bearing` | double | Bearing from ownship (degrees) |
| `relative_distance` | double | Distance from ownship (nm) |
| `relative_altitude` | int | Altitude difference from ownship (feet) |

---

## 8. UI Design

### 8.1 Connection Status Bar

A persistent compact bar at the top of the map screen (or in the status area):

```
┌──────────────────────────────────────────────────────┐
│ ✈ Stratux  |  GPS: 3D Fix (12 sats)  |  TFC: 8  |  FIS-B: 2m ago │
└──────────────────────────────────────────────────────┘
```

States:
- **Scanning** — pulsing icon, "Searching for receiver..."
- **Connected** — receiver name, GPS fix quality, traffic count, FIS-B data age
- **Stale** — yellow warning, "No data for 5s"
- **Disconnected** — gray, "No receiver connected"

Tap to open the Receiver Settings screen.

### 8.2 Screen: Receiver Settings (`/settings/receiver`)

| Section | Contents |
|---------|----------|
| **Active Connection** | Current receiver name, IP, signal quality, uptime. Disconnect button. |
| **Discovered Devices** | List of auto-discovered receivers on the network. Tap to connect. |
| **Manual Connection** | IP address text field + port (default 4000). Connect button. |
| **Saved Receivers** | Previously connected receivers with last-seen time. Star to mark preferred. |
| **GPS Source** | Toggle: "Prefer external GPS" (default on) vs. "Use device GPS only" |
| **Data Streams** | Toggles for: Traffic display, FIS-B weather, AHRS attitude. Each shows status (receiving/not receiving). |
| **Diagnostics** | Raw message counts by type, bytes received, parse errors, last heartbeat time. Useful for debugging. |

### 8.3 Traffic Map Layer

Traffic targets rendered on the moving map:

```
     ▲ N456AB
  +3 ↑ 4,500'

     ◆ ← ownship (centered)
```

| Element | Rendering |
|---------|-----------|
| Target icon | Chevron (▲) pointing in direction of travel. Filled = airborne, hollow = on ground. |
| Callsign label | Displayed above/below icon. Truncated if needed. |
| Altitude tag | Relative altitude: `+3` = 300 ft above, `-12` = 1,200 ft below. Absolute altitude on tap. |
| Color | White = normal, Yellow = proximate (<6 nm, ±1200 ft), Red = alert (<3 nm, ±600 ft) |
| Trend vector | Line extending from target showing projected position in 60 seconds |
| Stale indicator | Target fades after 30 seconds, removed after 60 seconds |
| Altitude filter | Slider: show traffic within ±X,000 ft of ownship altitude (default ±3,000) |

### 8.4 Backup Attitude Indicator Widget

When AHRS data is available, display a compact attitude indicator:

```
┌─────────────┐
│    ╱  ╲     │  ← Sky (blue)
│   ╱ ─── ╲   │  ← Horizon line
│  ╱_______╲  │  ← Ground (brown)
│  HDG: 270M  │
│  IAS: 105kt │
└─────────────┘
```

- Resizable widget, positionable on the map screen
- Shows artificial horizon (pitch and roll from AHRS)
- Heading, IAS, TAS readouts below
- **NOT FOR PRIMARY FLIGHT REFERENCE** — display disclaimer on first use
- Red X overlay when AHRS data is invalid or stale (>2 seconds)

---

## 9. Frontend State Management

All GDL 90 data is processed client-side. No backend endpoints needed — the mobile app connects directly to the ADS-B receiver over the local WiFi network.

| Provider | Type | Purpose |
|----------|------|---------|
| `gdl90ConnectionProvider` | `StateNotifierProvider` | Connection state machine (scanning/connecting/connected/stale/disconnected). Manages UDP socket lifecycle. |
| `ownshipPositionProvider` | `StreamProvider` | Ownship GPS position from GDL 90, updated at 1 Hz. Falls back to device GPS. |
| `trafficTargetsProvider` | `StateNotifierProvider` | Map of ICAO address → `TrafficTarget`. Auto-ages and removes stale targets. |
| `ahrsDataProvider` | `StreamProvider` | AHRS attitude data at 5 Hz (roll, pitch, heading, IAS, TAS). |
| `fisbWeatherProvider` | `StateNotifierProvider` | Decoded FIS-B weather products (METARs, TAFs, PIREPs). |
| `receiverStatusProvider` | `Provider` | Derived: connection state, GPS quality, traffic count, FIS-B age for status bar. |
| `gpsSourceProvider` | `StateProvider` | Which GPS source is active: `external` or `device`. |
| `savedReceiversProvider` | `FutureProvider` | List of saved receivers from local storage. |

---

## 10. Implementation Phases

### Phase 1 — GDL 90 Core (MVP)

| Feature | Details | Depends On |
|---------|---------|------------|
| GDL 90 UDP listener | Bind UDP socket on port 4000, receive and frame messages | — |
| Message parser | Decode heartbeat, ownship report, ownship geo altitude, traffic report | UDP listener |
| Ownship GPS | Use ownship position on moving map, GPS source priority logic | Message parser, Maps module |
| Connection status | Status bar showing receiver state, GPS fix quality | Message parser |
| Auto-discovery | Listen for ForeFlight discovery broadcast on UDP:63093 | — |
| Receiver settings UI | Manual IP entry, saved receivers, GPS source toggle | Auto-discovery |

### Phase 2 — Traffic & AHRS

| Feature | Details | Depends On |
|---------|---------|------------|
| Traffic display | Render traffic targets on map with chevrons, altitude tags, callsigns | Phase 1, Maps module |
| Traffic alerting | Threat level classification, color coding, audio callouts | Traffic display |
| Traffic altitude filter | User-configurable altitude band filter | Traffic display |
| AHRS parsing | Decode ForeFlight extended AHRS messages (0x65 sub-ID 0x01) | Phase 1 |
| Attitude indicator | Backup attitude widget on map screen | AHRS parsing |
| Stratux REST client | HTTP status polling, enhanced diagnostics | Phase 1 |

### Phase 3 — FIS-B Weather

| Feature | Details | Depends On |
|---------|---------|------------|
| FIS-B product parser | Decode UAT uplink message (ID 0x07) payload | Phase 1 |
| Text product decoding | Parse METARs, TAFs, PIREPs, TFRs from FIS-B text products | FIS-B parser |
| Weather integration | Feed FIS-B weather into existing weather displays (supplement internet weather) | Text product decoding, Weather module |
| NEXRAD raster decoding | Decode FIS-B NEXRAD radar imagery (run-length encoded raster) | FIS-B parser |
| Radar overlay | Render FIS-B NEXRAD on map as weather layer | NEXRAD raster decoding, Maps module |

---

## 11. Open-Source Resources & References

| Resource | URL | Description |
|----------|-----|-------------|
| GDL 90 Specification (FAA) | [PDF](https://www.faa.gov/sites/faa.gov/files/air_traffic/technology/adsb/archival/GDL90_Public_ICD_RevA.PDF) | Official protocol specification |
| ForeFlight GDL 90 Extended Spec | [foreflight.com/connect/spec](https://www.foreflight.com/connect/spec/) | AHRS, device ID extensions |
| Stratux (GitHub) | [github.com/cyoung/stratux](https://github.com/cyoung/stratux) | Open-source ADS-B receiver — reference implementation |
| Stratux App Integration Guide | [GitHub notes](https://github.com/cyoung/stratux/blob/master/notes/app-vendor-integration.md) | How third-party apps integrate with Stratux |
| gdl90 Python Library | [github.com/etdey/gdl90](https://github.com/etdey/gdl90) | Encoder/decoder reference |

---

## 12. Implementation Status

**Not Started** — This module has no implementation yet. The Maps module supports ownship position via device GPS and can render map layers, providing the foundation for traffic display and external GPS integration.
