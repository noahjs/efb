// Centralized configuration constants.
// Env-var overrides belong in their respective config files (db.config.ts, filing.config.ts).
// This file holds tuning parameters, API URLs, search defaults, and magic numbers.

// --- Data Groups ---
// Every entity belongs to one data group, which determines its sync strategy.
//   AVIATION: Read-only on client. Bulk-downloaded or cached with TTL.
//   USER:     Bidirectional sync. Local-first CRUD with mutation queue.
//   SYSTEM:   Server-managed. Fetched on login, refreshed on foreground.
export enum DataGroup {
  AVIATION = 'aviation',
  USER = 'user',
  SYSTEM = 'system',
}

// --- Weather ---
export const WEATHER = {
  AWC_BASE_URL: 'https://aviationweather.gov/api/data',
  NWS_BASE_URL: 'https://api.weather.gov',
  NWS_USER_AGENT: '(EFB Flight App, contact@efb.app)',
  NOTAM_API_URL: 'https://notams.aim.faa.gov/notamSearch/search',
  NOTAM_SEARCH_RADIUS_NM: '10',
  CACHE_TTL_METAR_MS: 5 * 60 * 1000,
  CACHE_TTL_WINDS_MS: 60 * 60 * 1000,
  CACHE_TTL_NOTAM_MS: 30 * 60 * 1000,
  CACHE_TTL_GRID_MS: 24 * 60 * 60 * 1000,
  TIMEOUT_NOTAM_MS: 30_000,
  TIMEOUT_BULK_METAR_MS: 15_000,
  TAF_SEARCH_RADIUS_NM: 50,
  TAF_SEARCH_LIMIT: 20,
  METAR_SEARCH_RADIUS_NM: 30,
  METAR_SEARCH_LIMIT: 100,
  WINDS_SEARCH_RADIUS_NM: 100,
  WINDS_SEARCH_LIMIT: 50,
};

// --- D-ATIS (Digital ATIS via clowd.io) ---
export const DATIS = {
  API_URL: 'https://datis.clowd.io/api',
  CACHE_TTL_MS: 5 * 60 * 1000, // 5 minutes
  TIMEOUT_MS: 10_000,
};

// --- LiveATC ATIS Transcription ---
export const LIVEATC_ATIS = {
  BASE_URL: 'http://d.liveatc.net',
  RECORD_DURATION_MS: 90_000,
  CONNECTION_TIMEOUT_MS: 10_000,
  CACHE_TTL_MS: 10 * 60 * 1000, // 10 minutes
  CACHE_TTL_FAILURE_MS: 2 * 60 * 1000, // 2 minutes
  WHISPER_MODEL: 'whisper-1',
  WHISPER_TIMEOUT_MS: 30_000,
  MAX_AUDIO_BYTES: 500_000,
};

// --- Imagery ---
export const IMAGERY = {
  AWC_BASE_URL: 'https://aviationweather.gov',
  SPC_BASE_URL: 'https://www.spc.noaa.gov',
  TFR_BASE_URL: 'https://tfr.faa.gov',
  CACHE_TTL_GFA_MS: 30 * 60 * 1000,
  CACHE_TTL_ADVISORY_MS: 10 * 60 * 1000,
  CACHE_TTL_TFR_MS: 15 * 60 * 1000,
  CACHE_TTL_WINDS_MS: 60 * 60 * 1000,
  TFR_BATCH_SIZE: 10,
  TIMEOUT_TFR_WFS_MS: 30_000,
  TIMEOUT_TFR_LIST_MS: 15_000,
  TIMEOUT_TFR_TEXT_MS: 10_000,
  PIREP_DEFAULT_BBOX: '20,-130,55,-60',
  PIREP_DEFAULT_AGE_HOURS: 2,
};

// --- Wind Data (Open-Meteo) ---
export const WINDS = {
  // Open-Meteo free API — serves GFS, HRRR, NAM, ECMWF, ICON model data
  API_BASE_URL: 'https://api.open-meteo.com/v1',
  CACHE_TTL_POINT_MS: 60 * 60 * 1000, // 60 minutes (wind data changes slowly)
  CACHE_TTL_GRID_MS: 30 * 60 * 1000, // 30 minutes
  ROUTE_SAMPLE_INTERVAL_NM: 50,
  // gfs_seamless auto-blends HRRR (3km short-range) with GFS (longer-range)
  DEFAULT_MODEL: 'gfs_seamless',
  FORECAST_DAYS: 2,
  // Pressure levels to request (hPa) — maps to the same altitudes as before
  PRESSURE_LEVELS: [
    1000, 950, 925, 900, 850, 800, 700, 600, 500, 400, 300, 200, 150,
  ],
  // Approximate altitude (ft MSL) for each pressure level
  LEVEL_ALTITUDES: {
    surface: 0,
    1000: 360,
    950: 1640,
    925: 2500,
    900: 3200,
    850: 5000,
    800: 6200,
    700: 10000,
    600: 14000,
    500: 18000,
    400: 24000,
    300: 30000,
    200: 39000,
    150: 44000,
  } as Record<string | number, number>,
  // Model-to-endpoint mapping
  MODEL_ENDPOINTS: {
    gfs_seamless: '/gfs', // HRRR+GFS blend (US, best default)
    hrrr_conus: '/gfs', // HRRR only (3km, 18h)
    nam_conus: '/gfs', // NAM (5km, 84h)
    gfs_global: '/gfs', // GFS only (22km, global)
    ecmwf_ifs025: '/ecmwf', // ECMWF IFS (9km, global)
    icon_seamless: '/dwd-icon', // ICON (13km, global)
  } as Record<string, string>,
};

// --- Elevation (Open-Meteo Elevation API) ---
export const ELEVATION = {
  API_URL: 'https://api.open-meteo.com/v1/elevation',
  SAMPLE_INTERVAL_NM: 5,
  MAX_POINTS_PER_REQUEST: 100, // Open-Meteo batch limit
  CACHE_TTL_MS: 24 * 60 * 60 * 1000, // 24 hours (terrain is static)
  REQUEST_DELAY_MS: 500, // delay between batch requests to avoid 429
};

// --- Traffic ---
export const TRAFFIC = {
  ADSB_LOL_BASE_URL: 'https://api.adsb.lol/v2',
  DEFAULT_RADIUS_NM: 30,
  MAX_RADIUS_NM: 250,
  TIMEOUT_MS: 10_000,
  // Grid-based cache
  GRID_CELL_DEG: 0.5, // ~30nm at mid-latitudes
  GRID_QUERY_RADIUS_NM: 30, // radius per cell query
  POLL_INTERVAL_MS: 3_000, // poll one cell every 3s
  CELL_INACTIVE_MS: 2 * 60 * 1000, // drop cell after 2min with no requests
  MAX_DATA_AGE_MS: 60 * 1000, // data older than 60s is considered stale
};

// --- Briefing ---
export const BRIEFING = {
  ROUTE_CORRIDOR_NM: 25,
  ROUTE_STATION_INTERVAL_NM: 75,
  WINDS_TABLE_ALTITUDE_STEP: 2000,
  WINDS_TABLE_ALTITUDE_RANGE: 4000,
  PIREP_AGE_HOURS: 3,
  NOTAM_CLOSURE_KEYWORDS: ['CLSD', 'CLOSED', 'UNSAFE', 'UNSERVICEABLE'],
};

// --- Data Platform (background polling) ---
export const DATA_PLATFORM = {
  SCHEDULER_INTERVAL_SECONDS: 60,
  WORKER_CONCURRENCY: 3,
  CONUS_BOUNDS: {
    minLat: 24,
    maxLat: 50,
    minLng: -125,
    maxLng: -66,
  },
  WIND_GRID_SPACING_DEG: 1.0,
  WIND_GRID_BATCH_SIZE: 250,
  METAR_STATE_BATCH_SIZE: 6,
  NOTAM_CONCURRENCY: 2,
  NOTAM_THROTTLE_MS: 500,
  TFR_TEXT_BATCH_SIZE: 10,
  // Staleness thresholds for on-demand data
  NWS_FORECAST_STALE_MS: 30 * 60 * 1000, // 30 min
  NOTAM_ON_DEMAND_STALE_MS: 30 * 60 * 1000, // 30 min
};

// --- Airports ---
export const AIRPORTS = {
  SEARCH_DEFAULT_LIMIT: 50,
  NEARBY_DEFAULT_RADIUS_NM: 30,
  NEARBY_DEFAULT_LIMIT: 20,
  BOUNDS_QUERY_LIMIT: 200,
  EARTH_RADIUS_NM: 3440.065,
};
