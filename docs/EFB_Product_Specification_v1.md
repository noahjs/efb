# PRODUCT SPECIFICATION
## Electronic Flight Bag Application
### US General Aviation — Non-Commercial Pilots

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

- [Maps Module](./modules/maps.md)
- [Airport Details Module](./modules/airport-details.md)
- [Flight Planning Module](./modules/flight-planning.md)
- [Logbook Module](./modules/logbook.md)
- [Aircraft Profiles Module](./modules/aircraft-profiles.md)
- [Weight & Balance Module](./modules/weight-and-balance.md)
- [Weather Imagery Module](./modules/weather-imagery.md) (overview)
- [Imagery Module](./modules/imagery.md) (detailed spec — weather imagery + plates)
- [US Data Sources](./modules/us-data-sources.md)
- [Cross-Cutting Concerns](./modules/cross-cutting-concerns.md)

---

## 1. Executive Summary

This document defines the high-level product specification for an Electronic Flight Bag (EFB) mobile application targeting US-based general aviation pilots operating under Part 91 (non-commercial). The application will provide comprehensive preflight planning, in-flight situational awareness, and post-flight logging capabilities comparable to ForeFlight, the current market leader.

The product scope is limited to the United States, leveraging freely available FAA data products to minimize recurring data licensing costs. The application will be developed as a native iOS and Android application with a companion web experience for desktop flight planning.

This specification covers seven core modules: Maps, Airport Details, Flight Planning, Logbook, Aircraft Profiles, Weight & Balance, and Weather Imagery. Each module will have a dedicated detailed specification developed subsequently.

---

## 2. Scope & Constraints

### 2.1 In Scope

- US airspace only (including territories)
- VFR and IFR operations under 14 CFR Part 91
- FAA-published charts, procedures, and data
- Native iOS (iPad and iPhone) and Android (tablet and phone) applications
- Companion web application for preflight planning
- Integration with common portable ADS-B receivers (Stratux, Sentry, Stratus)
- Offline capability for all chart and airport data

### 2.2 Out of Scope

- International charts and procedures (no Jeppesen license)
- Commercial operations (Part 121/135 dispatch, EFB compliance documentation)
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

### 2.4 Platform Requirements

- iOS 16+ (iPad and iPhone, optimized for iPad in cockpit use)
- Android 12+ (tablet and phone)
- Responsive web application (Chrome, Safari, Firefox)
- Offline-first architecture with background sync when connected
- GPS functionality without cellular connection (WiFi-only iPads with external GPS via ADS-B receiver)

---

## 3. Module Overview

The application is organized into seven core modules. Each module will have a dedicated detailed specification. The table below summarizes scope and build priority.

| Module | Description | Priority |
|--------|-------------|----------|
| **[Maps](./modules/maps.md)** | Moving map with aeronautical charts, weather overlays, ownship position, glide range, and flight plan route display | **P0 — Core** |
| **[Airport Details](./modules/airport-details.md)** | Comprehensive airport directory with frequencies, runways, weather, procedures, NOTAMs, and FBO information | **P0 — Core** |
| **[Flight Planning](./modules/flight-planning.md)** | Route creation, editing, filing (IFR/VFR), briefing, navlog generation, and route optimization | **P0 — Core** |
| **[Logbook](./modules/logbook.md)** | Digital flight logging, currency tracking, endorsements, certificates, and experience reports | **P1 — Important** |
| **[Aircraft Profiles](./modules/aircraft-profiles.md)** | Aircraft configuration, performance profiles, tail number management, and type certificate data | **P1 — Important** |
| **[Weight & Balance](./modules/weight-and-balance.md)** | Pre-loaded aircraft W&B envelopes, fuel planning, passenger/cargo loading, and limit checks | **P1 — Important** |
| **[Weather Imagery](./modules/weather-imagery.md)** | Forecast products, radar animation, satellite, winds aloft, icing/turbulence, PIREPs, and graphical briefing | **P0 — Core** |

---

## 4. Next Steps

This high-level specification establishes the scope and module boundaries for the application. The following detailed specifications will be developed for each module:

| Specification | Scope | Status |
|---------------|-------|--------|
| Maps Detailed Spec | Map engine selection, tile architecture, rendering pipeline, layer compositing, and interaction model. | Pending |
| Airport Details Spec | Data schema, FAA NASR parsing, search indexing, and UI wireframes. | Pending |
| Flight Planning Spec | Route computation engine, FAA filing integration, briefing generation, and navlog format. | Pending |
| Logbook Spec | Data model, currency calculation rules, endorsement workflow, and import/export formats. | Pending |
| Aircraft Spec | Performance model schema, type certificate database, and profile management. | Pending |
| Weight & Balance Spec | Envelope computation, station configuration, and limit checking algorithms. | Pending |
| Weather Imagery Spec | Data pipeline architecture, rendering approach for each product, and caching strategy. | Pending |
| Architecture Spec | Overall system architecture, API design, offline-first data layer, sync infrastructure, and platform approach (native vs cross-platform). | Pending |
