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

### Integrated & Working

| Data | Source | Status |
|------|--------|--------|
| Airport Data | FAA NASR | **Seeded** — Airports, runways, runway ends, frequencies. 28-day seed pipeline via admin dashboard. |
| Navigation Data (CIFP) | FAA CIFP | **Seeded** — Navaids, fixes, airways, preferred routes, procedures (SIDs/STARs/approaches). |
| METARs/TAFs | aviationweather.gov | **Live** — Proxied via WeatherModule with 5-min cache. |
| NOTAMs | FAA NOTAM API | **Live** — Proxied via WeatherModule with 30-min cache. Uses FAA 3-letter identifiers. |
| PIREPs | aviationweather.gov | **Live** — Proxied via ImageryModule. |
| AIRMETs/SIGMETs | aviationweather.gov | **Live** — G-AIRMETs, SIGMETs, CWAs proxied via ImageryModule. |
| GFA Panels | aviationweather.gov | **Live** — Cloud/surface panels proxied via ImageryModule. |
| VFR Sectional Charts | FAA Digital Products | **Seeded** — Raster tiles processed and served via TilesModule. |
| FAA Aircraft Registry | FAA Releasable Aircraft DB | **Seeded** — ~300K+ N-number registrations with ACFTREF + ENGINE data joined. |
| Street/Satellite Maps | Mapbox | **Live** — Mapbox GL used for base maps. |

### Not Yet Integrated

| Data | Notes |
|------|-------|
| IFR Enroute Charts | GeoTIFF rasters available from FAA, not yet processed |
| Terminal Procedures | d-TPP PDFs available from FAA (spec written in [imagery.md](./imagery.md)), not yet downloaded/served |
| Obstacles | FAA DOF available, not yet seeded |
| TFRs | FAA TFR feed available, not yet integrated |
| NEXRAD Radar | NOAA MRMS / RainViewer verified working, not yet integrated |
| Satellite Imagery | nowCOAST WMS verified working, not yet integrated |
| Winds Aloft | NWS forecast products available, not yet integrated |
| Icing/Turbulence | AWC Decision Support Graphics available (legacy URLs blocked), not yet integrated |
| Fuel Prices | No data source selected (AirNav.com or FBO partnerships TBD) |
| FBO Directory | No data source selected |
| ADS-B Traffic | Requires receiver hardware integration (Stratux GDL 90) |
| Terrain Elevation | USGS data available, not yet integrated |
