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
  TAF_SEARCH_RADIUS_NM: 50,
  TAF_SEARCH_LIMIT: 20,
  METAR_SEARCH_RADIUS_NM: 30,
  METAR_SEARCH_LIMIT: 100,
  WINDS_SEARCH_RADIUS_NM: 100,
  WINDS_SEARCH_LIMIT: 50,
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

// --- Traffic ---
export const TRAFFIC = {
  AIRPLANES_LIVE_BASE_URL: 'https://api.airplanes.live/v2',
  CACHE_TTL_MS: 8 * 1000, // 8s cache (slightly under 10s poll)
  DEFAULT_RADIUS_NM: 30,
  MAX_RADIUS_NM: 250,
  TIMEOUT_MS: 10_000,
};

// --- Airports ---
export const AIRPORTS = {
  SEARCH_DEFAULT_LIMIT: 50,
  NEARBY_DEFAULT_RADIUS_NM: 30,
  NEARBY_DEFAULT_LIMIT: 20,
  BOUNDS_QUERY_LIMIT: 200,
  EARTH_RADIUS_NM: 3440.065,
};
