# PRODUCT SPECIFICATION
## Electronic Flight Bag Application
### US Part 91 Operations — All Aircraft Categories

**HIGH-LEVEL SPECIFICATION**
Version 1.0 — February 2026
**CONFIDENTIAL**

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Scope & Constraints](#2-scope--constraints)
3. [Module Overview](#3-module-overview)
4. [Next Steps](#4-next-steps)

### Module Specifications

- [Maps Module](./modules/maps.md) | [Aeronautical Layer](./modules/maps.aeronautical.md)
- [Airport Details Module](./modules/airport-details.md)
- [Flight Planning Module](./modules/flight-planning.md) | [Routing](./modules/routing.md)
- [Logbook Module](./modules/logbook.md) | [Logbook Import & Migration](./modules/logbook-import.md)
- [Aircraft Profiles Module](./modules/aircraft-profiles.md) | [Registry Data Sources](./modules/registry-data-sources.md)
- [Weight & Balance Module](./modules/weight-and-balance.md)
- [Weather Imagery Module](./modules/weather-imagery.md) (overview)
- [Imagery Module](./modules/imagery.md) (detailed spec — weather imagery + plates)
- [ScratchPads Module](./modules/scratchpads.md)
- [US Data Sources](./modules/us-data-sources.md)
- [Garmin Avionics Data Integration](./modules/avionics-integration.md)
- [ADS-B & TIS-B Integration](./modules/adsb-integration.md)
- [Traffic Module](./modules/traffic.md)
- [Cross-Cutting Concerns](./modules/cross-cutting-concerns.md)

---

## 1. Executive Summary

This document defines the high-level product specification for an Electronic Flight Bag (EFB) mobile application targeting US-based pilots operating under Part 91 (non-commercial) across all aircraft categories — single- and multi-engine piston, turboprop, turbojet, and rotorcraft. The application will provide comprehensive preflight planning, in-flight situational awareness, and post-flight logging capabilities comparable to ForeFlight, the current market leader. The scope includes high-altitude operations (FL180–FL450) for turbine aircraft and pressurized cabin awareness, while excluding Part 121 ATP carrier operations.

The product scope is limited to the United States, leveraging freely available FAA data products to minimize recurring data licensing costs. The application will be developed as a native iOS and Android application with a companion web experience for desktop flight planning.

This specification covers seven core modules: Maps, Airport Details, Flight Planning, Logbook, Aircraft Profiles, Weight & Balance, and Weather Imagery. Each module will have a dedicated detailed specification developed subsequently.

---

## 2. Scope & Constraints

### 2.1 In Scope

- US airspace only (including territories)
- VFR and IFR operations under 14 CFR Part 91
- All aircraft categories: single-engine piston, multi-engine piston, turboprop, turbojet, turboshaft (helicopter)
- High-altitude operations (FL180–FL450) for turbine aircraft
- Pressurized aircraft support (cabin altitude tracking, oxygen requirements)
- Part 91K fractional ownership operations
- FAA-published charts, procedures, and data
- Native iOS (iPad and iPhone) and Android (tablet and phone) applications
- Companion web application for preflight planning
- Integration with common portable ADS-B receivers (Stratux, Sentry, Stratus)
- Offline capability for all chart and airport data

### 2.2 Out of Scope

- International charts and procedures (no Jeppesen license)
- Part 121 ATP carrier operations and associated EFB compliance documentation
- Military-specific features (CAP Grid, GARS Grid, MIL flight bag)
- Synthetic vision (deferred to Phase 2)
- Jeppesen chart integration
- JetFuelX fuel pricing integration
- CloudAhoy post-flight analysis integration
- Runway analysis tools

### 2.3 Target Users

- Student pilots in training (PPL, IR)
- Private pilots flying VFR cross-country
- Instrument-rated pilots filing and flying IFR
- Sport pilots and recreational flyers
- Aircraft owners managing single or small fleet aircraft
- Turbine pilots (turboprop and jet, Part 91)
- Corporate flight departments operating Part 91/91K
- Part 135 on-demand charter operators (single-pilot operations)
- Helicopter pilots (Part 91 operations)

### 2.4 Platform Requirements

- iOS 16+ (iPad and iPhone, optimized for iPad in cockpit use)
- Android 12+ (tablet and phone)
- Responsive web application (Chrome, Safari, Firefox)
- Offline-first architecture with background sync when connected
- GPS functionality without cellular connection (WiFi-only iPads with external GPS via ADS-B receiver)

---

## 3. Module Overview

The application is organized into seven core modules. Each module will have a dedicated detailed specification. The table below summarizes scope and build priority.

| Module | Description | Priority | Status |
|--------|-------------|----------|--------|
| **[Maps](./modules/maps.md)** | Moving map with aeronautical charts, weather overlays, ownship position, glide range, and flight plan route display | **P0 — Core** | **Partial** — VFR sectional tiles, Mapbox base maps, airport dots, aeronautical layer (airspaces, airways, navaids, fixes), flight plan route display, bottom sheets for map features. Missing: weather overlays, ownship, glide ring, track recording, approach plate overlay. |
| **[Airport Details](./modules/airport-details.md)** | Comprehensive airport directory with frequencies, runways, weather, procedures, NOTAMs, and FBO information | **P0 — Core** | **Mostly Built** — Search, general info, runways, frequencies, weather (METAR/TAF), NOTAMs, procedures (SIDs/STARs/approaches via CIFP), nearby airports. Missing: FBO info, fuel prices, taxi diagrams. |
| **[Flight Planning](./modules/flight-planning.md)** | Route creation, editing, filing (IFR/VFR), briefing, navlog generation, and route optimization | **P0 — Core** | **Partial** — Flights CRUD, route editor, aircraft selection, distance/time/fuel calculations, preferred routes (FAA NASR). Missing: graphical touch planning, procedure/altitude/alternate advisors, flight filing, briefing, navlog PDF, profile view. |
| **[Logbook](./modules/logbook.md)** | Digital flight logging, currency tracking, endorsements, certificates, and experience reports | **P1 — Important** | **Partial** — Entry CRUD (all time fields, landings, approaches, holds, remarks), experience reports. Missing: currency tracking, endorsements, certificates, import/export, cloud sync. |
| **[Aircraft Profiles](./modules/aircraft-profiles.md)** | Aircraft configuration, performance profiles, tail number management, and type certificate data | **P1 — Important** | **Mostly Built** — Full CRUD, fuel config, glide performance, equipment, FAA registry N-number auto-fill. Missing: pre-loaded aircraft type database, performance profiles by altitude/power setting. |
| **[Weight & Balance](./modules/weight-and-balance.md)** | Longitudinal and lateral CG computation, pre-loaded W&B envelopes (fixed-wing + helicopters), station-based loading, envelope visualization, scenario management, and limit checks | **P1 — Important** | **Not Started** |
| **[Weather Imagery](./modules/weather-imagery.md)** | Forecast products, radar animation, satellite, winds aloft (all flight levels via Windy API), icing/turbulence, PIREPs, wind-corrected route calculations, and graphical briefing | **P0 — Core** | **Partial** — GFA viewer (cloud/surface, all regions, time steps), advisory map (G-AIRMETs, SIGMETs, CWAs with interactive map), PIREP viewer, backend imagery module with proxy/caching. Missing: radar animation, satellite, prog charts, icing/turbulence products, Skew-T, plates, Windy winds aloft integration. |
| **[ScratchPads](./modules/scratchpads.md)** | Digital notepad for clearances, ATIS, briefing templates with drawing/typing support | **P1 — Important** | **Not Started** |

---

## 4. Next Steps

This high-level specification establishes the scope and module boundaries for the application. The following detailed specifications will be developed for each module:

| Specification | Scope | Status |
|---------------|-------|--------|
| Maps Detailed Spec | Map engine selection, tile architecture, rendering pipeline, layer compositing, and interaction model. | **Written** — [maps.md](./modules/maps.md), [maps.aeronautical.md](./modules/maps.aeronautical.md) |
| Airport Details Spec | Data schema, FAA NASR parsing, search indexing, and UI wireframes. | **Written** — [airport-details.md](./modules/airport-details.md) |
| Flight Planning Spec | Route computation engine, FAA filing integration, briefing generation, and navlog format. | **Written** — [flight-planning.md](./modules/flight-planning.md), [routing.md](./modules/routing.md) |
| Logbook Spec | Data model, currency calculation rules, endorsement workflow, and import/export formats. | **Written** — [logbook.md](./modules/logbook.md), [logbook-import.md](./modules/logbook-import.md) |
| Aircraft Spec | Performance model schema, type certificate database, and profile management. | **Written** — [aircraft-profiles.md](./modules/aircraft-profiles.md), [registry-data-sources.md](./modules/registry-data-sources.md) |
| Weight & Balance Spec | Envelope computation, station configuration, and limit checking algorithms. | **Written** — [weight-and-balance.md](./modules/weight-and-balance.md) (spec only, not implemented) |
| Weather Imagery Spec | Data pipeline architecture, rendering approach for each product, and caching strategy. | **Written** — [weather-imagery.md](./modules/weather-imagery.md), [imagery.md](./modules/imagery.md) (detailed) |
| ScratchPads Spec | Drawing engine, templates, and notepad UI for in-flight use. | **Written** — [scratchpads.md](./modules/scratchpads.md) (spec only, not implemented) |
| Architecture Spec | Overall system architecture, API design, offline-first data layer, sync infrastructure, and platform approach (native vs cross-platform). | Pending |
