# Aircraft Registry: Additional Data Sources

## Current State

We import the FAA ReleasableAircraft.zip which gives us per N-number:
- Manufacturer, model, serial number, year manufactured
- Engine type code, number of engines, number of seats
- Cruising speed (MPH) — coarse, from ACFTREF
- No ICAO type code, no fuel burn, no climb rate, no ceiling

## Future Data Sources

### 1. Doc8643.com — ICAO Type Designators + Performance Specs

**Best candidate.** Server-rendered site with clean URLs (`/aircraft/C172`).

Per ICAO type code it provides:
- ICAO type code (C172, TBM9, BE36, SR22, etc.)
- Classification code (L1P = land/1-engine/piston, L1T = land/1-engine/turboprop)
- MTOW (tonnes), fuel capacity (liters)
- Max speed, optimum cruise speed (kts)
- Max climb rate (fpm)
- Absolute ceiling, optimum ceiling (x100 ft)
- Max range (nm)
- Takeoff/landing distance (m)
- Persons on board

**Implementation approach:**
1. Build a static mapping from FAA MFR MDL CODE → ICAO type code (~500 GA-relevant types)
2. Compile performance data per ICAO type into a seed-able JSON/CSV
3. On N-number lookup, join FAA registry → ICAO type → performance specs
4. Auto-fill ICAO type code + performance profile on aircraft create

**No public API.** Would need a one-time scrape or manual compilation of GA types.

### 2. ICAO API Data Service — Official DOC 8643

Official source for ICAO type designators. CSV/JSON format.
- 100 free API calls, then paid plans
- Contains designator + engine/weight class only
- Does NOT include performance data (speeds, fuel, ceiling)
- Useful for building the FAA → ICAO mapping table
- Contact: ICAOAPI@icao.int for bulk download

URL: https://www.icao.int/api-data-service

### 3. Little Navmap Performance Files — Community Profiles

XML files (.lnmperf) with per-aircraft performance data:
- Cruise speed (TAS, kts), cruise fuel flow (gal/hr)
- Climb speed, climb rate, climb fuel flow
- Descent speed, descent rate, descent fuel flow

~100+ aircraft covered including C172, SR22, TBM, Baron, Bonanza, PA46.
Community-contributed, quality varies. X-Plane sourced.

URL: https://www.littlenavmap.org/downloads/Aircraft%20Performance/

Could be used to pre-populate default performance profiles on aircraft create.

### 4. OpenAP — Open-Source Performance Models

Python library with JSON data files for fuel burn, drag, thrust.
Covers airliners and business jets only (A320, B738, GLF6, etc.).
**No GA piston/turboprop coverage — not useful for our user base.**

URL: https://github.com/junzis/openap

### 5. FlightAware AeroAPI — Commercial

Paid API. Provides aircraft info by N-number including ICAO type.
Not cost-effective for our use case since we can derive the same from
FAA registry + a static ICAO mapping table.

## Priority

Not worth implementing yet. The FAA registry alone covers the core use case
(auto-fill manufacturer + model from N-number). When we're ready to add
ICAO type auto-fill and default performance profiles, start with doc8643
data compilation + FAA-to-ICAO mapping table.
