# Cross-Cutting Concerns
## EFB Product Specification

[← Back to Core Specification](../EFB_Product_Specification_v1.md)

---

## 1. Offline Capability

All chart data, airport information, procedures, and navigation data must be downloadable for offline use. Pilots frequently operate without cellular connectivity at altitude or at remote airports. The download manager must support region-based downloads with automatic update checks when connectivity is available.

## 2. Data Currency

FAA charts and procedures are updated on 28-day and 56-day cycles. The application must track data currency, alert pilots when data is expired, and provide seamless background updates. Expired charts must be clearly marked but still accessible (not deleted) to avoid leaving pilots without reference material.

## 3. GPS & Connectivity

The application must support iPad internal GPS (cellular models), iPhone GPS, and external GPS sources via ADS-B receivers using the GDL 90 protocol over WiFi or Bluetooth. Background GPS tracking must be reliable for track recording during long flights.

## 4. Performance

Map rendering must maintain 60fps during pan and zoom operations. Chart tile loading must feel instantaneous when data is cached locally. Weather overlay rendering must not block map interaction. The application must remain responsive during large data downloads.

## 5. Sync & Cloud

Flight plans, logbook entries, aircraft profiles, W&B configurations, user waypoints, and settings must sync across all user devices (iPad, iPhone, Android, web) in near real-time. Conflict resolution must favor the most recent edit.

## 6. Checklists & Documents

While not called out as a primary module, the application must support digital checklists (pre-configured templates, custom creation, speak mode) and a document management system for importing and organizing PDFs, images, and other reference materials. These are accessible from the "More" menu as seen in the ForeFlight UI.

## 7. Additional Menu Items

Based on the ForeFlight "More" menu, the following secondary features are required: Downloads manager, Settings, Plates viewer, Documents catalog, Imagery browser, ScratchPads (freeform notes), Custom Content, Track Logs viewer, Devices (ADS-B receiver management), Discover (community/content), Passenger app connectivity, Account management, and Support.

---

## Implementation Status

| Concern | Status | Notes |
|---------|--------|-------|
| Offline Capability | **Not Started** | No download manager or offline data storage. All data fetched live from backend. |
| Data Currency | **Partial** | 28-day NASR seed pipeline exists (airports, navaids, fixes, procedures, preferred routes). Manual admin trigger via dashboard. No automatic update checks or expiration alerts. |
| GPS & Connectivity | **Not Started** | No GPS integration, no ADS-B receiver support. |
| Performance | **Good** | Map rendering is smooth (Mapbox GL). Tile loading from backend is fast. Weather proxy caching in place. |
| Sync & Cloud | **Not Started** | No user accounts, no cross-device sync. All data is per-device (SQLite backend). |
| Checklists & Documents | **Not Started** | No checklist or document management features. |
| Additional Menu Items | **Partial** | "More" tab exists with navigation to Aircraft and Logbook. Admin dashboard built for seed management. Missing: Downloads, Settings, Plates, Documents, ScratchPads, Track Logs, Devices. |

### Admin Dashboard (Built)

The admin dashboard (`/api/admin`) provides seed management and monitoring:
- Database stats: airports, runways, frequencies, navaids, fixes, preferred routes, procedures, registry aircraft
- Seed triggers: Airports (FAA NASR), Navaids, Fixes, Procedures, Preferred Routes, Registry (FAA)
- Job status with polling
- Chart tile management (process VFR sectionals)
