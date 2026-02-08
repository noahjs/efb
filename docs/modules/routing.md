# Routing Module
## EFB Product Specification

[← Back to Flight Planning Module](flight-planning.md)

---

The Routing module provides the data layer behind the Flight Planning module's Route Advisor feature. It sources, stores, and ranks routes between airport pairs from three domains: FAA-published preferred routes, the user's own flight history, and real-world flight tracking data showing what routes aircraft are actually flying. Together these give pilots a comprehensive picture of realistic routing options rather than relying solely on manual airway construction.

## 1. FAA Preferred Routes

Published IFR routing data from the FAA, updated on 28-day AIRAC cycles. These routes are authoritative but not always what ATC actually clears in practice.

| Feature | Details | Complexity |
|---------|---------|------------|
| IFR Preferred Routes | Search FAA preferred IFR routes by origin/destination pair. Display route string, altitude restrictions, aircraft type restrictions, direction, and effective hours. | Medium |
| TEC Routes | Tower Enroute Control routes for IFR flight within terminal radar approach control areas without entering ARTCC airspace. Searchable by origin/destination TRACON. | Medium |
| Coded Departure Routes (CDRs) | Routes between specific airport/fix pairs used during traffic management initiatives. Display CDR type (1/2/3) and conditions under which each is assigned. | Medium |
| Preferred Route Map Overlay | Visualize selected preferred route on the map as a course line with intermediate fixes, airways, and altitude constraints labeled. | High |
| Route Import | One-tap import of any preferred route into the Flight Planning route editor for further modification. | Low |

### Data Sources

| Data | Source | Format | Update Cycle | Cost |
|------|--------|--------|--------------|------|
| Preferred IFR Routes | FAA NASR Subscriber Files (PFR dataset) | Fixed-width text | 28-day AIRAC | Free |
| TEC Routes | FAA NASR Subscriber Files (TEC dataset) | Fixed-width text | 28-day AIRAC | Free |
| Coded Departure Routes | FAA Route Management Tool (RMT) | Web / parseable | Updated as needed | Free |
| Navaids, Fixes, Airways | FAA CIFP (Coded Instrument Flight Procedures) | ARINC 424 | 28-day AIRAC | Free |

## 2. Flight History Routes

Routes sourced from the user's own flights and optionally from the broader user community. These reflect what pilots are actually being cleared to fly.

| Feature | Details | Complexity |
|---------|---------|------------|
| Personal Route History | Automatically record the filed and/or cleared route for every flight the user completes. Associate each route with aircraft type, altitude, and date. | Medium |
| Frequency Ranking | Rank personal routes by how often they've been flown. Show count and last-flown date for each unique route between an airport pair. | Low |
| Community Cleared Routes | Opt-in sharing of cleared routes to a shared database. Display aggregated routes between airport pairs from other app users, ranked by frequency and recency. | High |
| Aircraft Type Filtering | Filter community routes by aircraft category (SEL, MEL, jet) or specific type (C172, SR22, etc.) to see routes relevant to the user's performance profile. | Low |
| Route Comparison | Side-by-side comparison of multiple route options showing distance, estimated time, and number of legs for each. | Medium |

## 3. Real-World Flight Tracking

What routes are aircraft actually flying between airport pairs, sourced from flight tracking services. This provides the most practical routing intelligence, especially for GA operations where preferred routes are rarely assigned.

| Feature | Details | Complexity |
|---------|---------|------------|
| Popular Routes | Display the most frequently flown routes between an origin/destination pair, ranked by frequency with flight count and recency indicators. | High |
| GA Route Filtering | Filter tracked routes to general aviation operations only (exclude Part 121/135 airline traffic) based on aircraft type and operator data. | Medium |
| Altitude Distribution | Show the distribution of altitudes flown on a given route to help the pilot choose an optimal cruise altitude. | Medium |
| Route Freshness | Weight route suggestions by recency so that recently-flown routes rank higher than historical routes that may reflect outdated ATC practices. | Low |
| Tracking Route Map Overlay | Visualize tracked routes on the map with line thickness proportional to flight frequency. | High |

### Data Source Evaluation

Multiple flight tracking data sources were evaluated. The table below summarizes trade-offs relevant to a GA-focused EFB.

| Source | Route Data Quality | GA Coverage | History Depth | Cost | Notes |
|--------|-------------------|-------------|---------------|------|-------|
| FlightAware AeroAPI | High (decoded route strings) | Good (filed flight plans) | 2011 to present | ~$100/mo (Personal tier) | Best structured route data. Returns filed route, altitude, aircraft type per flight. Rate-limited. |
| ADS-B Exchange | Medium (raw position traces, routes must be reconstructed) | Excellent (unfiltered ADS-B) | 2020 to present | Free for personal use | Requires trajectory-to-route reconstruction. Best raw GA coverage since no filtering. |
| OpenSky Network | Medium (position data, some route metadata) | Good (crowdsourced receivers) | 30-day rolling window | Free for non-commercial | Academic project with API access. Limited historical lookback restricts trend analysis. |
| FAA SWIM TFMS | High (flight plan data direct from NAS) | Complete (all IFR flights) | Real-time + archive | Free (gov data) | Most authoritative but requires JMS infrastructure, SWIM registration, and XML parsing. High integration complexity. |

## 4. Route Suggestion Engine

The engine that combines all three data domains into a unified ranked list of route suggestions for the pilot.

| Feature | Details | Complexity |
|---------|---------|------------|
| Unified Route Ranking | Merge preferred routes, personal history, community routes, and tracked routes into a single ranked list. Weight by source reliability, recency, frequency, and relevance to aircraft type. | Very High |
| Route Source Labels | Tag each suggested route with its source (FAA Preferred, Personal History, Community, FlightAware, etc.) so the pilot understands provenance. | Low |
| Weather-Aware Filtering | Deprioritize or flag routes that pass through current adverse weather (convective SIGMETs, icing AIRMETs) using Weather module data. | High |
| Altitude Optimization | For each route, suggest optimal altitude(s) based on winds aloft data, MEAs, aircraft performance, and direction-of-flight rules. | High |

## Implementation Phases

**Phase 1 — FAA Preferred Routes (free data, offline-capable)**
Ingest IFR Preferred Routes and TEC Routes from NASR subscription data during the existing 28-day seed process. Store in SQLite alongside airport data. Provide search-by-airport-pair API endpoint.

**Phase 2 — Personal Flight History**
Record routes from filed flight plans. Build local route history database. Surface personal route suggestions in Route Advisor.

**Phase 3 — Real-World Flight Tracking**
Integrate FlightAware AeroAPI (or ADS-B Exchange as a free alternative) to fetch recently-flown routes between airport pairs. Cache results aggressively (routes don't change rapidly). Display in Route Advisor with frequency ranking.

**Phase 4 — Community Routes & Unified Ranking**
Add opt-in community route sharing. Build the unified ranking engine that merges all sources. Add weather-aware filtering.
