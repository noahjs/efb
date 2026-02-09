# Flight Planning Module
## EFB Product Specification

[← Back to Core Specification](../EFB_Product_Specification_v1.md)

---

The Flight Planning module handles route creation, optimization, filing, and briefing. It is tightly integrated with the Maps module (route displayed on map) and the Aircraft module (performance data for fuel/time calculations).

## 1. Core Features

| Feature | Details | Complexity |
|---------|---------|------------|
| Route Editor | Text-based route entry (identifier-to-identifier). Support for airways, intersections, navaids, lat/lon coordinates, and user waypoints. | High |
| Graphical Touch Planning | Rubber-band route creation directly on the map. Drag to add or reposition waypoints. | High |
| Aircraft Selection | Select aircraft by tail number (N980EK). Cruise profile selection (Maximum Cruise, Economy, etc.). Altitude selection. | Medium |
| Route Advisor | Suggest recently cleared ATC routes, preferred routes, and computed airway routes between origin and destination. | Very High |
| Procedure Advisor | Present available SIDs, STARs, approaches, and traffic pattern entries that can be added to route. | High |
| Altitude Advisor | Show wind speed/direction at multiple altitudes to optimize fuel burn and groundspeed. | Medium |
| Alternate Advisor | Suggest alternate airports based on weather, distance, facilities, and fuel requirements. | Medium |
| Flight Plan Filing | File IFR and VFR flight plans directly to FAA. Amend and cancel filed plans. Activate/close VFR plans. | Very High |
| Graphical Briefing | Visual preflight briefing with weather, NOTAMs, TFRs, and winds along route in a readable graphical format. | High |
| NavLog | Printable navigation log with leg distances, headings, times, fuel, frequencies, and wind data per waypoint. | Medium |
| Flight Stats Bar | Real-time display of DIST, ETE, ETA (with timezone), FUEL required, and WIND for the planned route. | Medium |
| ETD Selection | Set estimated time of departure for accurate ETA and wind calculations. | Low |
| Profile View | Vertical cross-section of route showing terrain, airspace, and planned altitude. | High |

---

## Implementation Status

### Built

| Feature | Status | Notes |
|---------|--------|-------|
| Route Editor | **Done** | Text-based route entry with airport/navaid/fix identifiers. Flight entity with origin, destination, route waypoints. |
| Aircraft Selection | **Done** | Select aircraft by tail number for flight. Links to aircraft profile for performance data. |
| Route Advisor (partial) | **Partial** | FAA Preferred IFR Routes seeded from NASR PFR dataset. Searchable by airport pair. See [routing.md](./routing.md). TEC routes and CDRs not yet integrated. |
| Flight Stats Bar (partial) | **Partial** | Distance, ETE, fuel calculations computed from route + aircraft profile. Displayed in flight detail screen, not yet as persistent bar on map. |
| ETD Selection | **Done** | Departure time selection on flight detail screen. |

### Not Started

| Feature | Notes |
|---------|-------|
| Graphical Touch Planning | Rubber-band route editing on map |
| Procedure Advisor | SID/STAR/approach suggestions for route endpoints |
| Altitude Advisor | Wind-optimized altitude selection |
| Alternate Advisor | Weather-based alternate suggestions |
| Flight Plan Filing | FAA IFR/VFR filing integration |
| Graphical Briefing | Visual preflight briefing along route |
| NavLog | Printable navigation log with per-leg data |
| Profile View | Vertical cross-section with terrain and airspace |
