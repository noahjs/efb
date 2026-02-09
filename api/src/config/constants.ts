// Centralized configuration constants.
// Env-var overrides belong in their respective config files (db.config.ts, filing.config.ts).
// This file holds tuning parameters, API URLs, search defaults, and magic numbers.

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

// --- Airports ---
export const AIRPORTS = {
  SEARCH_DEFAULT_LIMIT: 50,
  NEARBY_DEFAULT_RADIUS_NM: 30,
  NEARBY_DEFAULT_LIMIT: 20,
  BOUNDS_QUERY_LIMIT: 200,
  EARTH_RADIUS_NM: 3440.065,
};
