# Aircraft Profiles Module
## EFB Product Specification

[← Back to Core Specification](../EFB_Product_Specification_v1.md)

---

The Aircraft module manages aircraft configurations, performance profiles, and tail number associations. It feeds data into flight planning (fuel/time calculations), weight & balance, and the glide range ring on the map.

## 1. Core Features

| Feature | Details | Complexity |
|---------|---------|------------|
| Aircraft Directory | Pre-loaded database of common GA aircraft types with baseline specifications (e.g., Cessna 172, Piper PA-28, Cirrus SR22). | Medium |
| Tail Number Profiles | Create profiles for specific aircraft by tail number (N980EK, N977CA, N174AH). Associate with aircraft type and custom modifications. | Medium |
| Performance Profiles | Fuel burn rates, cruise speeds, climb/descent rates at various altitudes and power settings (Maximum Cruise, Economy, etc.). | High |
| Fuel Configuration | Fuel tank capacity, fuel type (100LL, Jet A), usable fuel, and consumption rates per profile. | Medium |
| Glide Performance | Best glide speed and glide ratio for glide range ring calculation (e.g., 120kts, 13.8:1). | Low |
| Equipment List | Installed avionics, GPS, transponder type, ADS-B Out compliance, and other equipment codes for flight plan filing. | Medium |
| Multiple Aircraft | Manage multiple aircraft profiles. Quick-switch between aircraft when planning flights. | Low |

---

## Implementation Status

### Built

| Feature | Status | Notes |
|---------|--------|-------|
| Tail Number Profiles | **Done** | Full CRUD for aircraft by tail number. Backend entity: `Aircraft`. Mobile: list, detail, create screens. |
| Fuel Configuration | **Done** | Fuel type (100LL, Jet-A, MoGas, Diesel) and total usable fuel capacity. |
| Glide Performance | **Done** | Best glide speed (KIAS) and glide ratio stored per aircraft. |
| Equipment List | **Done** | Equipment codes field on aircraft profile. |
| Multiple Aircraft | **Done** | Manage multiple aircraft, switch between them. |
| FAA Registry Lookup | **Done** | Auto-fill aircraft details from N-number using FAA ReleasableAircraft database (~300K+ registrations). Debounced lookup on create screen with dialog prompt. Derives aircraft type, serial number, category, fuel type from MASTER + ACFTREF + ENGINE tables. See [registry-data-sources.md](./registry-data-sources.md) for future enrichment options. |

### Not Started

| Feature | Notes |
|---------|-------|
| Aircraft Directory | Pre-loaded database of common GA types with baseline specs. Potential data source: Doc8643.com (see [registry-data-sources.md](./registry-data-sources.md)). |
| Performance Profiles | Fuel burn rates, cruise speeds, climb/descent rates at various altitudes and power settings. Potential data source: Little Navmap community profiles. |
