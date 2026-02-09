# Weather Imagery Module
## EFB Product Specification

[← Back to Core Specification](../EFB_Product_Specification_v1.md)

---

The Weather Imagery module provides standalone weather viewing beyond the map overlays. It includes full-screen weather products, forecast imagery, and the graphical briefing system. This module powers both the map weather layers and dedicated weather viewing screens.

## 1. Core Features

| Feature | Details | Complexity |
|---------|---------|------------|
| Radar Animation | Full-screen animated NEXRAD composite radar with play/pause, speed control, timeline scrubber, and loop duration selection. | High |
| Satellite Imagery | Enhanced visible and color IR satellite imagery with animation. | Medium |
| Forecast Products | Prognostic charts, surface analysis, significant weather charts, and convective outlooks. | Medium |
| Winds Aloft | Tabular and graphical winds aloft data at multiple altitudes for route and area planning. | Medium |
| Icing Forecasts | Current and forecast icing conditions by altitude and region. | Medium |
| Turbulence Forecasts | Current and forecast turbulence (clear air and convective) by altitude and region. | Medium |
| METAR/TAF Viewer | Decoded and raw METAR/TAF display with color-coded flight categories, trend indicators, and plain-English translations. | Medium |
| PIREPs | Pilot weather reports displayed on map and in list view, filtered by type, altitude, and recency. | Medium |
| AIRMETs/SIGMETs | Active and forecast AIRMETs and SIGMETs with geographic extent and altitude ranges. | Medium |
| TFR Viewer | Detailed TFR information with effective times, altitudes, and geographic boundaries. | Medium |
| Weather Profile View | Vertical cross-section of weather conditions along a planned route showing clouds, precipitation, turbulence, and icing. | Very High |

---

## Implementation Status

### Built

| Feature | Status | Notes |
|---------|--------|-------|
| METAR/TAF Viewer | **Done** | Decoded and raw METAR/TAF on airport detail screen. Color-coded flight categories. Backend proxies AWC API with 5-min cache. |
| PIREPs | **Done** | PIREP viewer in Imagery tab. Backend proxies AWC PIREP GeoJSON. |
| AIRMETs/SIGMETs | **Done** | Advisory map viewer with G-AIRMETs, SIGMETs, CWAs rendered as colored polygons on interactive map. Filter by hazard type. |
| Forecast Products (partial) | **Partial** | GFA cloud/surface panels for CONUS and all 9 regions with time-step selector. Backend proxies AWC static PNGs. |

### Not Started

| Feature | Notes |
|---------|-------|
| Radar Animation | NEXRAD composite radar with play/pause, timeline. Data sources verified (MRMS, RainViewer). |
| Satellite Imagery | GOES visible/IR/water vapor. Data source verified (nowCOAST WMS). |
| Winds Aloft | Tabular and graphical winds aloft |
| Icing Forecasts | CIP/FIP products. Must use AWC Decision Support Graphics (legacy URLs return 403/404). |
| Turbulence Forecasts | GTG products. Must use AWC Decision Support Graphics. |
| TFR Viewer | TFR polygons with effective times and altitudes |
| Weather Profile View | Vertical cross-section along route |

See [imagery.md](./imagery.md) for the detailed implementation spec including all verified data sources and API endpoints.
