# Maps Module
## EFB Product Specification

[← Back to Core Specification](../EFB_Product_Specification_v1.md)

---

The Maps module is the primary interface of the application. It provides a moving map display with layered aeronautical charts, weather overlays, flight plan visualization, and real-time ownship positioning. Based on analysis of ForeFlight's implementation, this module contains the highest density of features and the most complex rendering requirements.

## 1. Base Map Layers

Users can select one base map layer at a time. Each layer renders as the primary map background.

| Feature | Details | Complexity |
|---------|---------|------------|
| Aeronautical Map | Data-driven vector map with airports, airspace, navaids, obstacles, and waypoints. Continuous zoom with dynamic decluttering. | Very High |
| VFR Sectional | FAA VFR Sectional Charts rendered as georeferenced raster tiles with smooth pan/zoom. | High |
| VFR TAC | Terminal Area Charts for Class B airspace regions. | Medium |
| VFR Flyway | Flyway planning charts for major terminal areas. | Medium |
| IFR Low Enroute | IFR Low Altitude Enroute Charts with airways, MEAs, and navaids. | High |
| IFR High Enroute | IFR High Altitude Enroute Charts for jet routes. | High |
| Street Map | Standard street/road map for ground reference. | Low |
| Aerial/Satellite Map | Satellite imagery basemap for terrain visual reference. | Low |

## 2. Weather Overlay Layers

Multiple weather overlays can be toggled independently on top of the base map layer.

| Feature | Details | Complexity |
|---------|---------|------------|
| Radar (NEXRAD) | Animated composite radar with timeline scrubber, playback controls, dBZ legend differentiating rain/mixed/snow. | High |
| Radar (Lowest Tilt) | Lowest tilt radar for precipitation closest to ground level. | High |
| Satellite (Enhanced) | Enhanced satellite imagery overlay. | Medium |
| Satellite (Color IR) | Color-enhanced infrared satellite for cloud top temperatures. | Medium |
| Icing (US) | Current and forecast icing conditions by altitude. | Medium |
| Turbulence (US) | Current and forecast turbulence by altitude. | Medium |
| Clouds | Cloud coverage and ceiling visualization. | Medium |
| Surface Analysis | Surface weather analysis with fronts and pressure systems. | Medium |
| Winds (Temps/Speeds) | Wind barbs and temperature data at various altitudes. | Medium |
| Lightning | Real-time and recent lightning strike positions. | Medium |

## 3. Aviation Data Overlay Layers

| Feature | Details | Complexity |
|---------|---------|------------|
| Flight Category | Color-coded VFR/MVFR/IFR/LIFR dots at reporting stations based on METAR data. | Low |
| METARs/TAFs | Station weather observations and forecasts displayed on map. | Low |
| Surface Wind | Wind direction and speed at surface reporting stations. | Low |
| Winds Aloft | Forecast winds at altitude overlaid on map. | Medium |
| Dewpoint Spread | Temperature/dewpoint spread for fog/visibility prediction. | Low |
| Temperature | Reported temperatures at stations. | Low |
| Visibility | Reported visibility values at stations. | Low |
| Ceiling | Reported ceiling heights at stations. | Low |
| Sky Coverage | Sky condition (clear, few, scattered, broken, overcast) at stations. | Low |
| PIREPs | Pilot reports plotted on map with icons indicating type (turbulence, icing, etc.). | Medium |
| AIR/SIGMET/CWAs | Graphical AIRMETs, SIGMETs, and Center Weather Advisories as shaded regions. | Medium |
| NOTAMs | Notices to Air Missions displayed geographically. | Medium |
| TFRs | Temporary Flight Restrictions as shaded polygons, color-coded by active/upcoming status. | Medium |
| Obstacles | Towers, antennas, and other obstacles with height indicators. | Medium |
| Traffic | ADS-B traffic targets displayed on map (requires ADS-B receiver). | High |
| Cameras | Airport and weather camera locations with tap-to-view. | Low |
| Fuel Prices (100LL) | 100LL avgas prices displayed at airports. | Low |
| Fuel Prices (Jet A) | Jet A fuel prices displayed at airports. | Low |
| User Waypoints | Custom user-created waypoints and markers. | Low |
| Hazard Advisor | Terrain and obstacle proximity highlighting relative to planned altitude. | High |

## 4. Map Interaction & Display

| Feature | Details | Complexity |
|---------|---------|------------|
| Ownship Position | Real-time aircraft position and heading from GPS or ADS-B receiver, displayed as aircraft icon. | Medium |
| Glide Range Ring | Concentric rings showing glide distance based on current altitude, aircraft performance, and wind. Displayed as "Glide: 120kts, 13.8:1". | High |
| Distance Rings | Configurable range rings (2nm, 5nm, 10nm, 25nm) from ownship position. | Low |
| Track Recording | Record flight track with timer. REC button with elapsed time display. Breadcrumb trail on map. | Medium |
| Auto-Center Modes | North Up, Track Up Centered, Track Up Forward map orientation options. | Medium |
| Route Display | Magenta course line for active flight plan with waypoint labels. | Medium |
| Approach Plate Overlay | Geo-referenced approach plates (FAA) rendered semi-transparently on the map. | Very High |
| Map Annotations | Freehand drawing, holding pattern templates, text notes, and highlights on map. | Medium |
| Declutter Control | Slider or toggle to progressively simplify map elements at different zoom levels. | Medium |
| Map Settings | Screen brightness, chart color inversion, dark/light theme, terrain coloring, day/night overlay, place labels, cultural elements. | Low |
| Zoom & Pan | Smooth pinch-to-zoom and pan with momentum. Continuous zoom without tile boundaries. | High |

## 5. Bottom Information Bar

A persistent or contextual information bar at the bottom of the map displays real-time flight data: Distance Next, ETE Destination, Groundspeed, GPS Altitude, and Track. When a flight plan is active, additional fields show: Distance (total), ETE, ETA (with timezone), Fuel Required, and Wind.

---

## Implementation Status

### Built

**Base Map Layers:**
- VFR Sectional — FAA raster tiles served from backend TilesModule (TMS/XYZ conversion), pan/zoom working
- Street Map — Mapbox streets basemap
- Aerial/Satellite — Mapbox satellite basemap
- Layer picker with base layer selection (left column) and overlay toggles (right column)

**Aviation Data Overlay Layers:**
- Aeronautical layer toggle — data-driven vector overlay with sub-toggles ([detailed spec](./maps.aeronautical.md))
- Airspaces — Class B/C/D/E polygons from FAA NASR shapefiles, color-coded fill+line rendering
- Special Use Airspace — MOA, Restricted, Prohibited areas from AIXM data
- Airways — Victor and Jet route segments from NASR CSV data
- Navaids — VOR, VORTAC, NDB, DME with icon symbols from NASR
- Fixes/Waypoints — Waypoint markers with identifiers from NASR
- Airport dots — Color-coded by type, tappable with bottom sheet detail

**Map Interaction & Display:**
- Zoom & Pan — Smooth Mapbox gesture handling
- Route Display — Magenta course line for flight plan with waypoint labels
- Map tap — Bottom sheets for airports, navaids, fixes with details and actions (Direct To, Add to Route)
- Flight plan panel — Slide-up panel showing route legs, distance, bearing

**Bottom Information Bar:**
- Not yet implemented

### Not Started

**Base Map Layers:** Aeronautical Map (vector), VFR TAC, VFR Flyway, IFR Low Enroute, IFR High Enroute

**Weather Overlay Layers:** All (Radar/NEXRAD, Satellite, Icing, Turbulence, Clouds, Surface Analysis, Winds, Lightning)

**Aviation Data Overlay Layers:** Flight Category dots, METARs/TAFs on map, Surface Wind, Winds Aloft, Dewpoint Spread, Temperature, Visibility, Ceiling, Sky Coverage, PIREPs on map, AIR/SIGMET/CWA polygons on map, NOTAMs on map, TFRs on map, Obstacles, Traffic (ADS-B), Cameras, Fuel Prices, User Waypoints, Hazard Advisor

**Map Interaction & Display:** Ownship Position (GPS/ADS-B), Glide Range Ring, Distance Rings, Track Recording, Auto-Center Modes (North Up/Track Up), Approach Plate Overlay, Map Annotations, Declutter Control, Map Settings (brightness/inversion/theme)
