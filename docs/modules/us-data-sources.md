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
| Street/Satellite Maps | Google Maps, Mapbox, or OpenStreetMap | Tile API | Usage-based |
| Terrain Elevation | USGS NED / SRTM | GeoTIFF | Free |
