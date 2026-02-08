# Airport Details Module
## EFB Product Specification

[← Back to Core Specification](../EFB_Product_Specification_v1.md)

---

The Airport Details module provides a comprehensive directory of US airports accessible via the bottom tab bar, map tap, or search. It serves as the primary reference for preflight planning and in-flight diversion decisions.

## 1. Core Features

| Feature | Details | Complexity |
|---------|---------|------------|
| Airport Search | Search by identifier (KAPA), name, city, or location. Supports partial matching and nearest-airport lookup. | Medium |
| General Info | Airport name, identifier, city/state, elevation, magnetic variation, time zone, ownership type, operating status. | Low |
| Runways | Runway identifiers, dimensions (length/width), surface type, lighting, markings, slope, displaced thresholds. | Low |
| Frequencies | ATIS, Ground, Tower, Approach, Departure, CTAF, UNICOM, Clearance Delivery, and FSS frequencies. | Low |
| Weather (METAR/TAF) | Current METAR (decoded and raw) and TAF forecast for the airport. Color-coded flight category. | Medium |
| NOTAMs | Active NOTAMs for the airport, categorized and sorted by relevance. | Medium |
| Procedures | SIDs, STARs, and approach procedures available at the airport with direct link to plate viewer. | Medium |
| FBO Information | FBO name, services, fuel types/prices, fees, hours, phone, and amenities. | Medium |
| Taxi Diagrams | Airport taxi/ground movement charts with NOTAM-affected areas highlighted. | High |
| Nearby Airports | List of airports within configurable radius, sorted by distance, with basic info for diversion planning. | Low |
