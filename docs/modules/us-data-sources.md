# US Data Sources
## EFB Product Specification

[← Back to Core Specification](../EFB_Product_Specification_v1.md)

---

A key advantage of the US-only scope is that the FAA provides most required data for free. The following table identifies primary data sources for each data type.

| Data | Source | Format | Cost |
|------|--------|--------|------|
| VFR Sectional Charts | FAA Digital Products (aeronav.faa.gov) | GeoTIFF raster | Free |
| IFR Enroute Charts | FAA Digital Products | GeoTIFF raster | Free |
| Terminal Procedures | FAA Digital Products (d-TPP) | PDF per procedure | Free |
| Airport Data | FAA NASR (National Airspace System Resources) | CSV/fixed-width | Free |
| Navigation Data (CIFP) | FAA Coded Instrument Flight Procedures | ARINC 424 | Free |
| Obstacles | FAA Digital Obstacle File (DOF) | CSV | Free |
| NOTAMs | FAA NOTAM API | REST API / JSON | Free |
| TFRs | FAA TFR data feed | XML/KML | Free |
| METARs/TAFs | aviationweather.gov (AWC) | REST API / XML | Free |
| NEXRAD Radar | NOAA/NWS MRMS or RIDGE | GeoTIFF/PNG tiles | Free |
| Satellite Imagery | NOAA GOES-East/West | GeoTIFF/NetCDF | Free |
| Winds Aloft | NWS Forecast Products | GRIB2 / text | Free |
| Icing/Turbulence | AWC CIP/FIP, GTG products | GRIB2 | Free |
| PIREPs | aviationweather.gov | REST API / XML | Free |
| AIRMETs/SIGMETs | aviationweather.gov | REST API / GeoJSON | Free |
| Fuel Prices | AirNav.com or FBO partnerships | API / scrape | TBD |
| FBO Directory | AirNav.com or partnerships | API / scrape | TBD |
| ADS-B Traffic | Receiver hardware (Stratux GDL 90) | UDP / GDL 90 protocol | Free (receiver HW) |
| FAA Aircraft Registry | FAA Releasable Aircraft Database (registry.faa.gov) | CSV (ZIP) | Free |
| Street/Satellite Maps | Google Maps, Mapbox, or OpenStreetMap | Tile API | Usage-based |
| Terrain Elevation | USGS NED / SRTM | GeoTIFF | Free |

---

## Implementation Status

### Seeded (Database / Disk)

Static data loaded via admin seed pipeline. Refreshed on FAA 28-day NASR cycle.

| Data | Source | Status |
|------|--------|--------|
| Airport Data | FAA NASR | Airports, runways, runway ends, frequencies. 28-day seed pipeline via admin dashboard. |
| Navigation Data (CIFP) | FAA CIFP | Navaids, fixes, airways, preferred routes, procedures (SIDs/STARs/approaches). |
| VFR Sectional Charts | FAA Digital Products | Raster tiles processed and served via TilesModule. |
| FAA Aircraft Registry | FAA Releasable Aircraft DB | ~300K+ N-number registrations with ACFTREF + ENGINE data joined. |
| Terminal Procedures | FAA d-TPP | Procedure metadata seeded; PDFs downloaded on-demand and cached to disk per cycle. |

### Live-Proxied (In-Memory Cache Only)

These are fetched from third-party APIs on every user request with short-lived in-memory caching. **Before launch, these should be moved to server-side background polling.** See [Third-Party API Audit](./third-party-api-audit.md) for the full plan.

| Data | Source | Cache TTL | Launch TODO |
|------|--------|-----------|-------------|
| METARs | aviationweather.gov | 5 min | Poll per-state every 5 min (48 calls), store in DB |
| TAFs | aviationweather.gov | 5 min | Poll full CONUS every 5 min (1 call), store in DB |
| NOTAMs | FAA NOTAM API | 30 min | On-demand for now; bulk polling TBD (no bulk API) |
| PIREPs | aviationweather.gov | 10 min | Poll full CONUS every 5 min, store in DB |
| G-AIRMETs | aviationweather.gov | 10 min | Poll every 10 min (1 call), store in DB |
| SIGMETs | aviationweather.gov | 10 min | Poll every 10 min (1 call), store in DB |
| CWAs | aviationweather.gov | 10 min | Poll every 10 min (1 call), store in DB |
| TFRs | FAA tfr.faa.gov | 15 min | Poll every 15 min (WFS + metadata), store in DB |
| Winds Aloft | aviationweather.gov | 1 hour | Poll every hour (3 calls), store in DB |
| NWS Forecast | api.weather.gov | 5 min | Cache grid mappings permanently; forecasts 30-min TTL |
| GFA / Prog / Icing Charts | aviationweather.gov | 30 min | Move to disk/S3 cache |
| Convective Outlook | spc.noaa.gov | 30 min | Move to disk/S3 cache |
| Street/Satellite Maps | Mapbox | N/A | Mapbox GL handles its own tile caching |

### Live (Real-Time, No Cache)

| Data | Source | Notes |
|------|--------|-------|
| Flight Plan Filing | Leidos (lmfsweb.afss.com) | File/amend/cancel/close/status — must be real-time |
| ADS-B Traffic | Stratux GDL 90 (UDP) | Direct device-to-app, no backend involved |

### Not Yet Integrated

| Data | Notes |
|------|-------|
| IFR Enroute Charts | GeoTIFF rasters available from FAA, not yet processed |
| Obstacles | FAA DOF available, not yet seeded |
| NEXRAD Radar | NOAA MRMS / RainViewer verified working, not yet integrated |
| Satellite Imagery | nowCOAST WMS verified working, not yet integrated |
| Fuel Prices | No data source selected (AirNav.com or FBO partnerships TBD) |
| FBO Directory | No data source selected |
| Terrain Elevation | USGS data available, not yet integrated |
