# Offline-First Architecture & Sync

> **Status:** Draft
> **Last updated:** 2026-02-09
> **Dependencies:** [Third-Party API Audit](third-party-api-audit.md) · [US Data Sources](us-data-sources.md) · [Weight & Balance](weight-and-balance.md)

---

## 1. Motivation

Pilots routinely lose connectivity at altitude and at remote airports. The product spec lists "offline-first architecture with background sync" as a P0 requirement. Today the Flutter app is a thin online-only client — every screen fetches data through Dio → Riverpod FutureProviders → in-memory cache. There is no local database, no download manager, and no sync layer. A dropped connection renders the app useless.

This document defines the complete offline architecture organized around **three data groups** with distinct ownership, sync patterns, and storage strategies.

---

## 2. Three Data Groups

All data in the app belongs to one of three groups, defined by **who owns it** and **how it flows**.

```
┌─────────────────────────────────────────────────────────────────────┐
│                        EFB Data Groups                              │
├──────────────────┬──────────────────────┬───────────────────────────┤
│  Aviation Data   │     User Data        │     System Data           │
│  (FAA → client)  │  (client ↔ server)   │   (server → client)      │
│                  │                      │                           │
│  Airports        │  Aircraft profiles   │  User profile / account   │
│  Runways/Freqs   │  W&B profiles        │  Subscription status      │
│  Navaids/Fixes   │  Flights (plans)     │  Auth tokens              │
│  Procedures      │  Logbook entries     │  App feature flags        │
│  VFR tiles       │  Certificates        │  Server announcements     │
│  METARs/TAFs     │  Endorsements        │                           │
│  NOTAMs/TFRs     │  W&B scenarios       │                           │
│  PIREPs          │  User preferences    │                           │
│  Advisories      │                      │                           │
│  Winds aloft     │                      │                           │
│  Imagery         │                      │                           │
├──────────────────┼──────────────────────┼───────────────────────────┤
│  Read-only       │  Full CRUD           │  Read-only (mostly)       │
│  Bulk download   │  Bidirectional sync  │  Fetch on login           │
│  Cache w/ TTL    │  Mutation queue      │  Refresh on foreground    │
│  ~1–10 GB        │  <15 MB              │  <100 KB                  │
└──────────────────┴──────────────────────┴───────────────────────────┘
```

Each group gets its own sync service, storage strategy, and offline behavior.

---

## 3. Storage Technology

### Primary: Drift (SQLite)

**Drift** (formerly Moor) is the local database for all three data groups.

| Criterion | Drift | Isar | Hive | sqflite (raw) |
|-----------|-------|------|------|---------------|
| Relational queries / joins | Yes (full SQL) | No (NoSQL) | No (key-value) | Yes (raw SQL) |
| Type-safe Dart API | Yes (codegen) | Yes (codegen) | Partial | No |
| Reactive streams | Yes (built-in `watch()`) | Yes | Yes (boxes) | No |
| Migrations | Yes (versioned) | Auto | Manual | Manual |
| Riverpod integration | StreamProvider ← Drift streams | Similar | Manual | Manual |
| Complex queries (spatial, aggregate) | Full SQL + extensions | Limited | None | Full SQL |
| Community / maintenance | Active, widely used | Active | Declining | Stable |
| iOS/Android/Web | All | All | All | iOS/Android only |

**Decision: Drift.** The EFB data model is deeply relational — airports have runways, runway ends, frequencies; aircraft have W&B profiles with stations and envelopes; flights reference airports, aircraft, and route waypoints. Joins, foreign keys, and reactive queries are essential. Drift's type-safe codegen and built-in `watch()` streams map directly to Riverpod StreamProviders.

### Secondary: Filesystem

- **VFR sectional tiles** — PNG/WebP files at `{appSupportDir}/tiles/{chart}/{z}/{x}/{y}.png`.
- **Terminal procedure PDFs** — At `…/procedures/{airport}/{filename}.pdf`.
- **Weather imagery** — At `…/imagery/{product}/{timestamp}.png` with metadata in Drift.

### Tertiary: Mapbox OfflineManager

If using Mapbox GL for the base map layer, its built-in `OfflineManager` handles vector tile packs for the street/terrain/satellite base layer. This is separate from VFR raster tiles.

---

## 4. Connectivity Monitoring (Shared Infrastructure)

All three data groups depend on a shared connectivity layer.

### 4.1 Network State Machine

```
┌──────────┐    network detected     ┌──────────┐    API reachable     ┌──────────┐
│ OFFLINE  │────────────────────────▶│ DEGRADED │────────────────────▶│  ONLINE  │
│          │◀────────────────────────│          │◀────────────────────│          │
└──────────┘    network lost         └──────────┘    API unreachable  └──────────┘
                                                                           │
                                                                           │ sync in progress
                                                                           ▼
                                                                      ┌──────────┐
                                                                      │ SYNCING  │
                                                                      └──────────┘
```

- **OFFLINE:** No network interface active. All reads from local DB.
- **DEGRADED:** Network interface active but backend API unreachable (e.g., WiFi connected but no internet, or server down).
- **ONLINE:** Backend API reachable. Normal operation.
- **SYNCING:** Online + actively processing sync queue or pulling updates.

### 4.2 Implementation

Use `connectivity_plus` for network interface detection, plus a periodic health check (`GET /api/health`) to confirm API reachability.

```dart
final connectivityProvider = StreamProvider<ConnectivityState>((ref) {
  return ConnectivityMonitor(
    healthCheckUrl: '${apiBaseUrl}/health',
    healthCheckInterval: Duration(seconds: 30),
  ).stateStream;
});
```

### 4.3 UI Indicators

- **Status bar widget** — Persistent indicator at top of screen when not fully online:
  - Offline: Red bar — "Offline — showing cached data"
  - Degraded: Yellow bar — "Limited connectivity"
  - Syncing: Blue bar with progress — "Syncing 3 changes..."
- **Per-screen indicators** — Weather screens show freshness dots. Airport screens show cycle date.
- **Sync queue badge** — If mutations are queued, show count on the "More" tab (settings).

### 4.4 Auto-Sync Triggers

Sync runs automatically when:
1. App transitions from OFFLINE/DEGRADED → ONLINE.
2. App returns to foreground after >5 minutes in background.
3. Periodic background sync (every 15 minutes when online, via `workmanager`).
4. User pulls-to-refresh on any list screen.
5. User taps "Sync now" in settings.

---

## 5. Repository Pattern (Shared Infrastructure)

A new **Repository** layer sits between Riverpod providers and ApiClient. Each domain has its own repository, and each data group uses a different repository base class.

```
mobile/lib/repositories/
├── base/
│   ├── aviation_repository.dart     # Read-only, download + cache
│   ├── user_data_repository.dart    # Bidirectional CRUD + sync queue
│   └── system_repository.dart       # Read-only, fetch-on-login
├── aviation/
│   ├── airport_repository.dart
│   ├── navaid_repository.dart
│   ├── procedure_repository.dart
│   ├── weather_repository.dart
│   └── tile_repository.dart
├── user/
│   ├── aircraft_repository.dart
│   ├── flight_repository.dart
│   ├── logbook_repository.dart
│   └── wb_repository.dart
├── system/
│   └── profile_repository.dart
├── sync_service.dart                # Mutation queue processor (User Data)
├── download_service.dart            # Bulk download manager (Aviation Data)
└── connectivity_monitor.dart
```

### Provider Migration

Current pattern (online-only):
```dart
final airportDetailProvider = FutureProvider.family<Airport?, String>((ref, id) async {
  return ref.read(apiClientProvider).getAirport(id);
});
```

New pattern (offline-first):
```dart
final airportRepositoryProvider = Provider<AirportRepository>((ref) {
  return AirportRepository(ref.read(driftDbProvider), ref.read(apiClientProvider));
});

// StreamProvider backed by Drift reactive query
final airportDetailProvider = StreamProvider.family<Airport?, String>((ref, id) {
  return ref.read(airportRepositoryProvider).watchAirport(id);
});
```

All FutureProviders migrate to StreamProviders backed by Drift `watch()` queries.

---

# Group A: Aviation Data

FAA aeronautical data, weather, and chart tiles. **Read-only on the client.** Server is the source of truth. Data flows one direction: upstream sources → backend → client.

Aviation data splits into two sub-categories with different caching strategies:

---

## 6. Reference Data (Airports, Navaids, Procedures, Tiles)

Large, static datasets updated on FAA 28/56-day cycles. Downloaded in bulk, stored permanently until user deletes.

### 6.1 Data Inventory

| Data | Records | Est. Size | Update Cycle |
|------|---------|-----------|--------------|
| Airports (NASR) | ~19,000 | ~50 MB | 28-day |
| Runways + runway ends | ~25,000 | ~15 MB | 28-day |
| Frequencies | ~40,000 | ~10 MB | 28-day |
| Navaids | ~5,000 | ~5 MB | 56-day |
| CIFP procedures (SID/STAR/IAP) | ~50,000 | ~200 MB | 28-day |
| Fixes / waypoints | ~70,000 | ~20 MB | 56-day |
| Airways | ~3,000 | ~5 MB | 56-day |
| VFR sectional tiles (per chart) | ~5,000–20,000/chart | 200–900 MB/chart | 28-day |
| Terminal procedure PDFs | varies | ~50–200 MB/region | 28-day |

### 6.2 Download Manager

#### Region Model

Downloads are organized by **VFR sectional chart area**, which aligns with pilot mental models.

| Sectional Chart | Approx. Coverage | Airport Count | Tile Count (z5–z11) | Est. Size |
|-----------------|------------------|---------------|----------------------|-----------|
| New York | NY, NJ, CT, PA (east) | ~1,200 | ~12,000 | ~400 MB |
| Chicago | IL, IN, OH, MI | ~1,500 | ~15,000 | ~500 MB |
| Dallas–Ft Worth | TX (north), OK, AR | ~1,100 | ~14,000 | ~450 MB |
| Los Angeles | CA (south), AZ (west) | ~800 | ~10,000 | ~350 MB |
| Seattle | WA, OR (west) | ~600 | ~8,000 | ~300 MB |
| *... (37 total sectional charts)* | | | | |

A download region includes:
- All airports within the sectional boundary (with runways, frequencies).
- All navaids and fixes within the boundary.
- All CIFP procedures for airports in the region.
- VFR raster tiles for zoom levels 5–11.
- Terminal procedure PDFs for airports with instrument approaches.

#### Download Job Lifecycle

```
┌──────────┐     ┌────────────┐     ┌─────────────┐     ┌───────────┐
│ QUEUED   │────▶│ DOWNLOADING│────▶│ PROCESSING  │────▶│ COMPLETE  │
│          │     │ (progress) │     │ (indexing)   │     │           │
└──────────┘     └────────────┘     └─────────────┘     └───────────┘
     │                │                                       │
     │                ▼                                       │
     │           ┌──────────┐                                 │
     └──────────▶│  PAUSED  │                                 │
                 └──────────┘                                 │
                      │                                       │
                      ▼                                       ▼
                 ┌──────────┐                            ┌──────────┐
                 │  FAILED  │                            │ EXPIRED  │
                 └──────────┘                            └──────────┘
```

**Download tracking table (Drift):**
```sql
CREATE TABLE a_download_jobs (
  id              TEXT PRIMARY KEY,
  region          TEXT NOT NULL,         -- e.g. 'sectional:new_york'
  data_type       TEXT NOT NULL,         -- 'airports' | 'tiles' | 'procedures' | 'all'
  status          TEXT NOT NULL,         -- QUEUED | DOWNLOADING | PROCESSING | COMPLETE | PAUSED | FAILED | EXPIRED
  progress        REAL DEFAULT 0.0,     -- 0.0 to 1.0
  total_bytes     INTEGER,
  downloaded_bytes INTEGER DEFAULT 0,
  cycle_date      TEXT NOT NULL,         -- e.g. '2025-01-23' (FAA effective date)
  expires_at      TEXT NOT NULL,         -- cycle_date + 28 or 56 days
  created_at      TEXT NOT NULL,
  completed_at    TEXT,
  error_message   TEXT
);
```

#### Resume Capability

Large downloads (VFR tiles can be 500MB+) must survive app backgrounding, suspension, and device restart.

- Tile downloads are individual HTTP requests — track per-tile completion in a `downloaded_tiles` table.
- On resume, skip already-downloaded tiles and continue from where we left off.
- Bulk data (airports, procedures) uses chunked API responses with cursor pagination.

### 6.3 FAA Cycle Awareness

FAA aeronautical data follows a 28-day or 56-day cycle (published schedule). The download manager:

1. Stores the cycle effective date with each download.
2. On each app launch, checks if any downloaded regions are past their cycle expiration.
3. **Expired data is flagged with a yellow warning banner** — "Chart data expired 3 days ago. Update available."
4. **Expired data is NEVER auto-deleted.** Pilots may be mid-flight when data expires. Deletion would be dangerous.
5. Users can tap "Update now" or defer. Old data remains accessible until the user explicitly downloads the new cycle.

### 6.4 VFR Tile Offline Strategy

VFR raster tiles are served by the backend's TilesModule from `data/charts/tiles/`. The tile structure follows TMS/XYZ conventions.

**Download strategy:**
- User selects a sectional chart region in the download manager.
- Client requests a tile manifest from the server: `GET /api/tiles/manifest?chart=new_york&zoom_min=5&zoom_max=11`.
- Manifest returns a list of tile coordinates and total size estimate.
- Client downloads tiles in parallel (4 concurrent connections) to local filesystem.
- Tiles stored at: `{appSupportDir}/tiles/{chart}/{z}/{x}/{y}.png`.

**Zoom levels:**
- z5–z7: Overview / route planning (~5 MB per chart).
- z8–z9: Enroute / terminal area (~50 MB per chart).
- z10–z11: Detail / approach (~200–800 MB per chart).
- z5–z9 is a "lite" download option for pilots who want minimal storage use.

**Base map (Mapbox):** If using Mapbox GL, its `OfflineManager` handles the street/terrain/satellite base layer independently. Users configure a bounding box (e.g., 200 NM around home airport).

**Tile loading priority:**
1. **Memory cache** — LRU cache of recently viewed tiles (configurable, default 100 MB).
2. **Local filesystem** — Downloaded tiles for this region.
3. **Network** — Fetch from backend API (if online).
4. **Placeholder** — Gray tile with "No data" text (if offline and not downloaded).

The map never shows a blank/broken tile — always falls back to the placeholder.

### 6.5 Storage Estimates & Disk Management

| Download Type | Per Region | Full CONUS |
|---------------|------------|------------|
| Airport data (with runways, freqs) | 2–5 MB | ~80 MB |
| CIFP procedures | 5–15 MB | ~200 MB |
| VFR tiles (z5–11) | 200–900 MB | ~8 GB |
| Terminal procedure PDFs | 50–200 MB | ~3 GB |
| **Typical pilot (2–3 regions)** | | **~1.5–3 GB** |

The download manager shows:
- Per-region size estimate before download.
- Total downloaded data size in settings.
- Device free space.
- Option to delete individual regions.

A warning appears if free space drops below 1 GB.

### 6.6 Backend API: Bulk Download Endpoints

```
GET /api/download/manifest
  → { cycles: { airports: "2025-01-23", navaids: "2025-01-23", ... }, regions: [...] }

GET /api/download/airports?region=new_york&cursor=0&limit=500
  → { data: [...], next_cursor: 500, total: 1200 }

GET /api/download/navaids?region=new_york
GET /api/download/procedures?region=new_york&cursor=0&limit=100
GET /api/download/fixes?region=new_york

GET /api/tiles/manifest?chart=new_york&zoom_min=5&zoom_max=11
  → { tiles: [{z, x, y, size_bytes}], total_size: 412_000_000 }
```

All bulk endpoints use cursor-based pagination to support resumable downloads.

---

## 7. Weather & Operational Data (METARs, TAFs, NOTAMs, TFRs, etc.)

Short-lived data with TTL-based caching. Cached aggressively but always shown with staleness context.

### 7.1 Data Inventory

| Data | Cache TTL | Staleness Threshold | Prefetch |
|------|-----------|---------------------|----------|
| METARs | 5 min | Green <30 min, Yellow <60 min, Red >60 min | Along route |
| TAFs | 5 min | Green <1 hr, Yellow <3 hr, Red >3 hr | Along route |
| NOTAMs | 30 min | Green <1 hr, Yellow <2 hr, Red >2 hr | Along route |
| PIREPs | 10 min | Green <30 min, Yellow <1 hr, Red >1 hr | Along route |
| TFRs (polygons + metadata) | 15 min | Green <30 min, Yellow <1 hr, Red >1 hr | Regional |
| G-AIRMETs / SIGMETs / CWAs | 10 min | Green <30 min, Yellow <1 hr, Red >1 hr | Regional |
| Winds aloft | 1 hr | Green <3 hr, Yellow <6 hr, Red >6 hr | Along route |
| GFA / prog chart imagery | 30 min | Green <1 hr, Yellow <2 hr, Red >2 hr | Current region |

### 7.2 Cache-Then-Network Pattern

```dart
Stream<WeatherState<T>> getCachedWeather<T>({
  required String cacheKey,
  required Duration ttl,
  required Future<T> Function() networkFetch,
  required T? Function(String key) cacheRead,
  required void Function(String key, T data) cacheWrite,
}) async* {
  // 1. Emit cached data immediately (if available)
  final cached = cacheRead(cacheKey);
  if (cached != null) {
    yield WeatherState(data: cached, source: DataSource.cache, age: cacheAge);
  }

  // 2. Fetch fresh data in background (if connected + TTL expired)
  if (isConnected && cacheAge > ttl) {
    try {
      final fresh = await networkFetch();
      cacheWrite(cacheKey, fresh);
      yield WeatherState(data: fresh, source: DataSource.network, age: Duration.zero);
    } catch (e) {
      // Network failed — keep showing cached data, log error
      yield WeatherState(data: cached, source: DataSource.cache, age: cacheAge, error: e);
    }
  }
}
```

### 7.3 Weather State Model

```dart
class WeatherState<T> {
  final T? data;
  final DataSource source;    // cache | network
  final Duration age;         // time since data was fetched
  final Freshness freshness;  // green | yellow | red (computed from age + thresholds)
  final Object? error;        // non-null if last network fetch failed
}
```

UI components receive `WeatherState` and render:
- The data itself (METAR text, TAF blocks, etc.).
- A freshness indicator (colored dot: green/yellow/red).
- Age text ("Updated 12 min ago" or "Last updated 2 hr ago — may be outdated").
- Error context if applicable ("Unable to refresh — showing cached data").

### 7.4 Weather Cache Storage

Weather data is stored in Drift tables with insertion timestamps:

```sql
CREATE TABLE a_cached_metars (
  station_id    TEXT PRIMARY KEY,
  raw_ob        TEXT NOT NULL,
  data_json     TEXT NOT NULL,   -- full METAR object as JSON
  observed_at   TEXT NOT NULL,   -- observation time from the METAR itself
  cached_at     TEXT NOT NULL    -- when we fetched it
);
```

Similar tables for TAFs, NOTAMs, PIREPs, TFRs, advisories, winds aloft. Weather data older than 24 hours is purged automatically.

### 7.5 Flight Weather Prefetch

When a flight plan has a route, the app prefetches weather for all airports and waypoints along the route:

1. Identify all airports within 25 NM of the route centerline.
2. Fetch METARs + TAFs for those airports.
3. Fetch NOTAMs for departure, destination, and alternates.
4. Fetch PIREPs along the route corridor.
5. Fetch TFRs intersecting the route buffer.
6. Fetch winds aloft for waypoints along the route (for flight calculations).

This happens automatically when the user opens a flight plan (if connected). The prefetched data is cached locally, so the pilot has weather available for the entire route even if they lose connectivity after departure.

### 7.6 Online-Only Aviation Data

Some aviation data cannot be meaningfully cached:

| Data | Reason |
|------|--------|
| Live wind grid overlays (Windy) | Large streaming dataset, viewport-dependent |
| Radar / satellite imagery | Large binary, rapidly changing |
| FAA registry lookup | On-demand, low frequency |

These features show a "Requires internet connection" message when offline.

### 7.7 Backend API: Weather Bulk Endpoints

Once the backend migrates to server-side polling (per [Third-Party API Audit](third-party-api-audit.md)), add bulk weather endpoints:

```
GET /api/weather/metars?bbox=24,-125,50,-66          -- CONUS bounding box
GET /api/weather/metars?stations=KAPA,KDEN,KBJC      -- specific stations
GET /api/weather/tafs?stations=KAPA,KDEN
GET /api/weather/pireps?bbox=38,-106,42,-102
GET /api/weather/tfrs?bbox=38,-106,42,-102
GET /api/weather/notams?airports=APA,DEN,BJC
```

These return the server's cached data from PostgreSQL, not live-proxied from upstream APIs.

---

# Group B: User Data

Pilot-owned data created and edited on-device. **Bidirectional sync.** The client is the primary copy — writes go local first, sync to server in background. Server is the backup and multi-device bridge.

---

## 8. User Data Inventory

| Data | Records | Est. Size | Write Pattern |
|------|---------|-----------|---------------|
| Aircraft profiles | ~5–20 | <100 KB | CRUD |
| W&B profiles, stations, envelopes | ~5–50 | <200 KB | CRUD |
| W&B scenarios | ~20–100 | <500 KB | CRUD |
| Flights (plans) | ~50–500 | <2 MB | CRUD, frequent edits |
| Logbook entries | ~100–5,000 | <10 MB | Append-heavy |
| Certificates & endorsements | ~5–30 | <50 KB | Rare edits |
| User preferences / settings | 1 | <10 KB | Key-value |

Total user data is typically <15 MB. Small enough to sync the entire dataset on every pull.

---

## 9. Local-First CRUD

```
┌──────────────┐     ┌───────────┐     ┌──────────────┐     ┌────────────┐
│  UI / Screen │────▶│ Riverpod  │────▶│  Repository  │────▶│  Drift DB  │
│              │◀────│ Provider  │◀────│              │◀────│  (SQLite)  │
└──────────────┘     └───────────┘     └──────────────┘     └────────────┘
                      streams                  │
                                               │ enqueue mutation
                                               ▼
                                        ┌──────────────┐     ┌────────────┐
                                        │  Sync Queue  │────▶│  Backend   │
                                        │  (Drift tbl) │◀────│  API       │
                                        └──────────────┘     └────────────┘
```

### 9.1 Write Path

1. User creates/updates/deletes a record.
2. Repository writes to Drift DB immediately (optimistic).
3. Repository inserts a row into the `u_sync_queue` table: `{ id, entity_type, entity_id, operation (CREATE|UPDATE|DELETE), payload_json, created_at, retry_count }`.
4. Drift reactive query fires → StreamProvider emits new state → UI updates instantly.
5. SyncService (background) picks up queued mutations and sends to backend API.
6. On success: remove from queue, update `server_synced_at` on the entity.
7. On failure: increment `retry_count`, exponential backoff (1s, 5s, 30s, 2min, 10min). Cap at 50 retries then flag for manual review.

### 9.2 Read Path

1. Provider streams from Drift reactive query — zero network latency.
2. On app launch (or connectivity restored), SyncService runs a pull sync.

### 9.3 Pull Sync (Server → Client)

For each user-data entity type, the client stores `last_synced_at` timestamp.

```
GET /api/aircraft?updated_since=2025-01-15T10:30:00Z
→ Returns all aircraft where updated_at > timestamp (including soft-deleted)
```

The client upserts returned records into Drift, then updates `last_synced_at`. Soft-deleted records (where `deleted_at` is set) are removed from the local DB.

### 9.4 Repository Base Class

```dart
abstract class UserDataRepository<T> {
  final AppDatabase db;
  final ApiClient api;
  final SyncService sync;

  /// Stream local data (reactive)
  Stream<List<T>> watchAll();
  Stream<T?> watchById(String id);

  /// Write locally + enqueue sync
  Future<void> save(T entity);
  Future<void> delete(String id);

  /// Pull from server, upsert locally
  Future<void> pullSync();
}
```

---

## 10. Conflict Resolution

### Strategy: Last-write-wins (LWW) by `updated_at` timestamp.

| Scenario | Resolution |
|----------|------------|
| Client edits, server unchanged | Client wins (normal sync) |
| Server edits, client unchanged | Server wins (pull sync) |
| Both edited same record | Higher `updated_at` wins |
| Client deletes, server edits | Delete wins (user intent was clear) |
| Server deletes, client edits | Delete wins (server-side deletion is authoritative) |

**Rationale:** This is a single-pilot app. There is no collaborative editing. The only multi-device scenario is a pilot switching between iPad and iPhone, which is sequential access. LWW is simple, predictable, and sufficient.

If a conflict is detected (server returned a record with `updated_at` newer than the local mutation), the SyncService logs it, applies the server version, and discards the queued mutation. A toast notification informs the user: "Flight plan updated from another device."

---

## 11. Backend API: User Data Sync Support

### 11.1 Incremental Pull

Add `updated_since` query parameter to all user-data endpoints:

```
GET /api/aircraft?updated_since=2025-01-15T10:30:00Z
GET /api/flights?updated_since=2025-01-15T10:30:00Z
GET /api/logbook?updated_since=2025-01-15T10:30:00Z
```

Returns all records where `updated_at > :timestamp`, including soft-deleted records. The response includes a `server_time` header so the client knows what timestamp to use for the next sync.

### 11.2 Soft Delete

Add `deleted_at` column to all user-data entities. Existing DELETE endpoints set `deleted_at = NOW()` instead of hard-deleting. Pull sync includes soft-deleted records so clients can remove them locally.

```typescript
// Example: AircraftEntity
@DeleteDateColumn()
deleted_at: Date;
```

TypeORM's `@DeleteDateColumn` handles this automatically with `softDelete()` / `restore()` methods.

### 11.3 Online-Only User Actions

Flight filing (Leidos) is transactional and requires a live connection. It is not queued — the UI shows "Requires internet connection" when offline.

---

# Group C: System Data

Server-managed account and configuration data. **Read-only on the client** (with minor exceptions like preference writes). Fetched on login, refreshed when the app foregrounds.

---

## 12. System Data Inventory

| Data | Est. Size | Update Frequency | Write Pattern |
|------|-----------|------------------|---------------|
| User profile (name, email, pilot cert) | <5 KB | Rare | Server-managed |
| Subscription / plan status | <1 KB | On purchase/renewal | Server-managed |
| Auth tokens (JWT + refresh) | <2 KB | On login / refresh | Client writes |
| App feature flags | <1 KB | On deploy | Server-managed |
| Server announcements / MOTD | <5 KB | Occasional | Server-managed |
| User preferences (units, theme, home airport) | <10 KB | Occasional | Bidirectional |

### 12.1 Sync Strategy

```dart
abstract class SystemRepository<T> {
  final AppDatabase db;
  final ApiClient api;

  /// Read from local DB (cached from last fetch)
  T? getCached();
  Stream<T?> watch();

  /// Fetch from server, overwrite local
  Future<void> refresh();
}
```

- **On login:** Fetch full profile, subscription status, feature flags. Store in Drift.
- **On foreground:** If last refresh was >5 minutes ago, refresh in background.
- **Auth tokens:** Stored in platform secure storage (`flutter_secure_storage`), not Drift.
- **Preferences:** Bidirectional — client writes locally, syncs to server. Server wins on conflict (simple overwrite, no queue needed since preferences are low-frequency and low-stakes).

### 12.2 Offline Behavior

System data is always available from the local cache. The app never blocks on fetching system data — it uses whatever was cached at last login. If the subscription check fails offline, the app assumes the last-known status is still valid (grace period).

---

# Implementation

---

## 13. Migration Path

Six phases, each independently shippable. Earlier phases build foundation for later ones.

### Phase 1 — Foundation (~4 weeks)

**Goal:** Drift DB running, connectivity monitoring active, repository pattern established.

| Task | Details |
|------|---------|
| Add Drift + codegen | `drift`, `drift_dev`, `sqlite3_flutter_libs`, `build_runner` |
| Define Drift schema | Tables for all User Data entities (aircraft, flights, logbook, W&B, certs) |
| Implement `AppDatabase` | Single Drift database class with DAOs per domain |
| Add `connectivity_plus` | `ConnectivityMonitor` service + `connectivityProvider` |
| Connectivity UI | Offline/degraded/syncing status bar widget |
| Add `sync_queue` table | Schema for mutation queue |
| Scaffold repository base classes | `UserDataRepository<T>`, `AviationRepository<T>`, `SystemRepository<T>` |
| Scaffold `SyncService` | Queue processor with retry logic (no actual sync yet) |
| System data repository | `ProfileRepository` — fetch on login, cache in Drift |

**Shippable result:** App has local database and connectivity awareness. System data cached locally. No functional change to user experience yet.

### Phase 2 — User Data Offline (~6 weeks)

**Goal:** Aircraft, flights, logbook, and W&B fully work offline with bidirectional sync.

| Task | Details |
|------|---------|
| `AircraftRepository` | Local CRUD + sync queue + pull sync |
| `FlightRepository` | Local CRUD + sync queue + pull sync |
| `LogbookRepository` | Local CRUD + sync queue + pull sync |
| `WBRepository` | Local CRUD + sync queue + pull sync |
| Migrate providers | All user-data FutureProviders → StreamProviders backed by Drift |
| Backend: `updated_since` | Add to all user-data endpoints |
| Backend: soft delete | Add `deleted_at` to all user-data entities |
| `SyncService` full implementation | Push queue processing, pull sync, conflict resolution |
| Sync status UI | Queue count badge, "last synced" timestamp in settings |
| Initial data load | First app launch: pull all user data from server → Drift |

**Shippable result:** Pilot can create/edit aircraft, flights, logbook entries fully offline. Changes sync when back online.

### Phase 3 — Aviation Reference Data Downloads (~6 weeks)

**Goal:** Airports, navaids, procedures downloadable by region for offline use.

| Task | Details |
|------|---------|
| Download manager UI | Region picker (sectional chart map), size estimates, progress |
| Drift schema for reference data | Airport, Runway, Frequency, Navaid, Fix, Procedure tables |
| `DownloadService` | Job queue, progress tracking, resume capability |
| Backend: bulk download endpoints | `/api/download/airports`, `/navaids`, `/procedures`, `/fixes` |
| Backend: region manifest | `/api/download/manifest` with cycle dates and region definitions |
| `AirportRepository` | Read from local Drift DB with network fallback |
| `NavaidRepository`, `ProcedureRepository` | Local-first reads |
| FAA cycle tracking | Expiration warnings, update prompts |
| Storage management UI | Downloaded regions list, sizes, delete option, free space indicator |

**Shippable result:** Pilot downloads their home region(s). Airport directory, procedures, navaids work fully offline.

### Phase 4 — VFR Tile Downloads (~4 weeks)

**Goal:** VFR sectional chart tiles downloadable for offline map use.

| Task | Details |
|------|---------|
| Backend: tile manifest endpoint | `/api/tiles/manifest` with tile list and size estimates |
| Tile download service | Parallel tile downloads, per-tile tracking, resume |
| Local tile provider | Filesystem-backed tile provider for flutter_map |
| Tile loading priority chain | Memory → filesystem → network → placeholder |
| Download manager integration | Add tile downloads to region download flow |
| Zoom level options | "Lite" (z5–9) vs "Full" (z5–11) download options |
| Mapbox offline packs | Base map layer offline regions (if using Mapbox) |

**Shippable result:** Pilot downloads VFR charts for their region. Map works fully offline.

### Phase 5 — Weather Cache (~5 weeks)

**Goal:** Weather data cached locally with staleness indicators and route prefetch.

| Task | Details |
|------|---------|
| Drift schema for weather cache | `cached_metars`, `cached_tafs`, `cached_notams`, `cached_pireps`, `cached_tfrs` |
| `WeatherRepository` | Cache-then-network pattern, TTL management |
| Staleness indicators | Green/yellow/red dots on all weather displays |
| Age text | "Updated X min ago" on all weather elements |
| Flight weather prefetch | Auto-fetch weather along route corridor |
| Migrate weather providers | FutureProvider → StreamProvider with `WeatherState<T>` |
| Cache cleanup | Purge weather data older than 24 hours |

**Shippable result:** Weather screens show cached data instantly, refresh in background. Staleness is always visible. Route weather prefetched before departure.

### Phase 6 — Polish & Optimization (~5 weeks)

**Goal:** Performance tuning, edge case handling, background sync, testing.

| Task | Details |
|------|---------|
| Background sync via `workmanager` | Periodic sync when app is backgrounded |
| Drift query optimization | Indexes, query analysis, batch operations |
| Storage pressure handling | Warnings at 1 GB free, auto-purge old weather cache |
| Migration testing | Drift schema migration tests for future updates |
| Offline integration tests | Simulate offline scenarios in test suite |
| Sync conflict edge cases | Test and handle: simultaneous edits, large payloads, partial sync |
| Performance profiling | DB query times, sync duration, memory usage |
| Error recovery | Corrupt DB detection, re-sync from server option |

**Shippable result:** Production-ready offline experience. Robust error handling and performance.

### Timeline Summary

| Phase | Duration | Cumulative |
|-------|----------|------------|
| 1. Foundation | ~4 weeks | 4 weeks |
| 2. User Data Offline | ~6 weeks | 10 weeks |
| 3. Aviation Reference Downloads | ~6 weeks | 16 weeks |
| 4. VFR Tile Downloads | ~4 weeks | 20 weeks |
| 5. Weather Cache | ~5 weeks | 25 weeks |
| 6. Polish & Optimization | ~5 weeks | 30 weeks |

Phases 4 and 5 can run in parallel if resources allow, potentially compressing the timeline to ~25 weeks.

---

## 14. Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| **Download size too large** | Users won't download; app store reviews complain | High | Offer "lite" download (z5–9 tiles only, ~50 MB vs 500 MB). Show clear size estimates before download. |
| **iOS background restrictions** | Background sync unreliable; `workmanager` has iOS limitations | High | Use iOS BGTaskScheduler via workmanager. Keep background tasks <30s. Prioritize foreground sync (on app open). Don't rely on background sync for critical data. |
| **SQLite performance at scale** | Slow queries on 19K airports with joins | Medium | Add indexes on all foreign keys and query columns. Use Drift's compiled queries. Benchmark on oldest supported device. |
| **Disk exhaustion** | Device runs out of space mid-download | Medium | Check free space before download. Reserve 500 MB buffer. Pause downloads if free space <1 GB. Show storage management UI. |
| **Drift schema migrations** | Breaking changes to local DB on app update | Medium | Use Drift's versioned migration system. Test migrations on every release. Keep a migration test suite with sample data. |
| **Sync queue corruption** | Queued mutations lost due to crash | Low | WAL mode on SQLite (default in Drift). Mutations are idempotent (use PUT, not POST). Server-side deduplication by entity ID + timestamp. |
| **Stale weather shown as current** | Pilot makes decisions on old data | High | **Staleness indicators are mandatory on every weather element.** Red indicator + banner for data >1 hr old. Never hide age information. |
| **FAA cycle data mismatch** | Procedure changes between cycles cause safety issue | Medium | Bold expiration warnings. Prompt update on cycle change day. Never silently serve expired procedures. |
| **Mapbox offline tile limits** | Mapbox has limits on offline tile pack count/size | Low | Monitor Mapbox usage. VFR raster tiles are independent of Mapbox (served from our backend). Only base map layer uses Mapbox offline. |

---

## 15. New Dependencies

| Package | Purpose | Phase |
|---------|---------|-------|
| `drift` | Type-safe SQLite ORM | 1 |
| `drift_dev` | Drift code generator (dev dependency) | 1 |
| `sqlite3_flutter_libs` | SQLite native libraries for iOS/Android | 1 |
| `build_runner` | Dart code generation runner (dev dependency) | 1 |
| `connectivity_plus` | Network state monitoring | 1 |
| `flutter_secure_storage` | Secure token storage (System Data) | 1 |
| `workmanager` | Background task scheduling (iOS BGTaskScheduler, Android WorkManager) | 6 |
| `path_provider` | Already present — filesystem paths | — |
| `crypto` | SHA-256 for tile integrity verification | 4 |

**No changes to backend dependencies.** Backend additions (soft delete, bulk endpoints, `updated_since`) use existing TypeORM and NestJS features.

---

## 16. Open Questions

1. **Multi-user / shared aircraft:** If two pilots share an aircraft profile, LWW is insufficient. Is this a future requirement? If so, need CRDT or operational transform for W&B profiles.
2. **Procedure chart rendering:** Should CIFP procedures be rendered client-side (from data) or downloaded as pre-rendered PDFs? Client-side rendering enables offline but is significantly more complex.
3. **Full CONUS download:** Should we support a "download everything" option for pilots who fly cross-country? This would be ~8–12 GB. May need incremental/streaming download.
4. **Web platform:** Drift supports web via `drift/web.dart` (IndexedDB backend), but filesystem tile storage doesn't apply. Is web offline a requirement?
5. **ADS-B weather:** Stratux ADS-B receivers provide FIS-B weather (METARs, TAFs, PIREPs, TFRs) directly over WiFi. Should this be an alternative weather source that bypasses the cache-then-network pattern entirely?
