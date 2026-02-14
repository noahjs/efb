import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PNG } from 'pngjs';
import { HrrrCycle } from '../data-platform/entities/hrrr-cycle.entity';
import { HrrrSurface } from '../data-platform/entities/hrrr-surface.entity';
import { HrrrPressure } from '../data-platform/entities/hrrr-pressure.entity';
import { HRRR, DATA_PLATFORM } from '../config/constants';

// CONUS grid constants
const MIN_LAT = DATA_PLATFORM.CONUS_BOUNDS.minLat; // 24
const MAX_LAT = DATA_PLATFORM.CONUS_BOUNDS.maxLat; // 50
const MIN_LNG = DATA_PLATFORM.CONUS_BOUNDS.minLng; // -125
const MAX_LNG = DATA_PLATFORM.CONUS_BOUNDS.maxLng; // -66
const LAT_RANGE = MAX_LAT - MIN_LAT; // 26
const LNG_RANGE = MAX_LNG - MIN_LNG; // 59
const GRID_ROWS = LAT_RANGE + 1; // 27 (lat 24..50 inclusive)
const GRID_COLS = LNG_RANGE + 1; // 60 (lng -125..-66 inclusive)
const GRID_SIZE = GRID_ROWS * GRID_COLS; // 1620

const TILE_SIZE = HRRR.TILE_SIZE; // 256
const TILE_ZOOM_MIN = HRRR.TILE_ZOOM_MIN; // 2
const TILE_ZOOM_MAX = HRRR.TILE_ZOOM_MAX; // 8

const TILE_CACHE_MAX = 500;
const CYCLE_CHECK_INTERVAL_MS = 60_000;

// Valid tile products
export const TILE_PRODUCTS = [
  'flight-cat',
  'clouds-total',
  'clouds-low',
  'clouds-mid',
  'clouds-high',
  'visibility',
  'clouds',
] as const;
export type TileProduct = (typeof TILE_PRODUCTS)[number];

// Flight category numeric encoding (matches HrrrSurface.flight_category strings)
const FCAT_MAP: Record<string, number> = {
  VFR: 0,
  MVFR: 1,
  IFR: 2,
  LIFR: 3,
};

interface ConusRaster {
  initTime: string;
  forecastHour: number;
  cloudTotal: Float32Array;
  cloudLow: Float32Array;
  cloudMid: Float32Array;
  cloudHigh: Float32Array;
  flightCategory: Uint8Array; // 0=VFR,1=MVFR,2=IFR,3=LIFR,255=unknown
  visibilitySm: Float32Array;
}

interface PressureConusRaster {
  initTime: string;
  forecastHour: number;
  pressureLevel: number;
  relativeHumidity: Float32Array; // 1620 values, 0-100%
}

@Injectable()
export class HrrrTileService {
  private readonly logger = new Logger(HrrrTileService.name);

  // Raster cache keyed by forecast hour
  private rasterCache = new Map<number, ConusRaster>();
  private rasterLoadPromises = new Map<number, Promise<ConusRaster | null>>();

  // Pressure-level raster cache keyed by "forecastHour:pressureLevel"
  private pressureRasterCache = new Map<string, PressureConusRaster>();
  private pressureLoadPromises = new Map<
    string,
    Promise<PressureConusRaster | null>
  >();

  // Rendered tile cache
  private tileCache = new Map<string, Buffer>();

  // Cycle tracking
  private lastKnownInitTime: string | null = null;
  private lastCycleCheck = 0;

  // Pre-computed transparent tile
  private readonly transparentTile: Buffer;

  constructor(
    @InjectRepository(HrrrCycle)
    private readonly cycleRepo: Repository<HrrrCycle>,
    @InjectRepository(HrrrSurface)
    private readonly surfaceRepo: Repository<HrrrSurface>,
    @InjectRepository(HrrrPressure)
    private readonly pressureRepo: Repository<HrrrPressure>,
  ) {
    const png = new PNG({ width: TILE_SIZE, height: TILE_SIZE });
    png.data.fill(0);
    this.transparentTile = PNG.sync.write(png);
  }

  /**
   * Renders a tile for the given product/zoom/x/y.
   * Returns a PNG buffer.
   */
  async renderTile(
    product: TileProduct,
    z: number,
    x: number,
    y: number,
    forecastHour: number,
    pressureLevel?: number,
  ): Promise<Buffer> {
    // Check if cycle changed
    await this.checkCycleChange();

    // Quick bounds check: if tile is entirely outside CONUS, return transparent
    const tileBounds = tileToLatLngBounds(z, x, y);
    if (
      tileBounds.maxLat < MIN_LAT ||
      tileBounds.minLat > MAX_LAT ||
      tileBounds.maxLng < MIN_LNG ||
      tileBounds.minLng > MAX_LNG
    ) {
      return this.transparentTile;
    }

    // Check tile cache (include pressure level for clouds product)
    const levelKey = product === 'clouds' ? `:${pressureLevel ?? 850}` : '';
    const cacheKey = `${product}:${forecastHour}${levelKey}:${z}:${x}:${y}`;
    const cached = this.tileCache.get(cacheKey);
    if (cached) return cached;

    let buffer: Buffer;

    if (product === 'clouds') {
      // Pressure-level cloud rendering
      const level = pressureLevel ?? 850;
      const pressureRaster = await this.loadPressureRaster(
        forecastHour,
        level,
      );
      if (!pressureRaster) return this.transparentTile;
      buffer = this.renderPressureTileFromRaster(pressureRaster, z, x, y);
    } else {
      // Surface-based rendering
      const raster = await this.loadRaster(forecastHour);
      if (!raster) return this.transparentTile;
      buffer = this.renderTileFromRaster(product, raster, z, x, y);
    }

    // Cache the rendered tile (evict if over limit)
    if (this.tileCache.size >= TILE_CACHE_MAX) {
      // Evict oldest entries (first quarter)
      const keys = [...this.tileCache.keys()];
      for (let i = 0; i < keys.length / 4; i++) {
        this.tileCache.delete(keys[i]);
      }
    }
    this.tileCache.set(cacheKey, buffer);

    return buffer;
  }

  // --- Raster loading ---

  private async loadRaster(forecastHour: number): Promise<ConusRaster | null> {
    const cached = this.rasterCache.get(forecastHour);
    if (cached) return cached;

    // Concurrency guard: if someone else is already loading this fh, wait for them
    const existing = this.rasterLoadPromises.get(forecastHour);
    if (existing) return existing;

    const promise = this.doLoadRaster(forecastHour);
    this.rasterLoadPromises.set(forecastHour, promise);
    try {
      return await promise;
    } finally {
      this.rasterLoadPromises.delete(forecastHour);
    }
  }

  private async doLoadRaster(
    forecastHour: number,
  ): Promise<ConusRaster | null> {
    const activeCycle = await this.cycleRepo.findOne({
      where: { is_active: true },
    });
    if (!activeCycle) return null;

    const initTime = activeCycle.init_time.toISOString();

    const rows = await this.surfaceRepo.find({
      where: { init_time: activeCycle.init_time, forecast_hour: forecastHour },
    });

    if (rows.length === 0) return null;

    const raster: ConusRaster = {
      initTime,
      forecastHour,
      cloudTotal: new Float32Array(GRID_SIZE),
      cloudLow: new Float32Array(GRID_SIZE),
      cloudMid: new Float32Array(GRID_SIZE),
      cloudHigh: new Float32Array(GRID_SIZE),
      flightCategory: new Uint8Array(GRID_SIZE).fill(255),
      visibilitySm: new Float32Array(GRID_SIZE).fill(-1),
    };

    for (const row of rows) {
      const latIdx = Math.round(row.lat - MIN_LAT);
      const lngIdx = Math.round(row.lng - MIN_LNG);
      if (
        latIdx < 0 ||
        latIdx >= GRID_ROWS ||
        lngIdx < 0 ||
        lngIdx >= GRID_COLS
      ) {
        continue;
      }
      const idx = latIdx * GRID_COLS + lngIdx;

      raster.cloudTotal[idx] = row.cloud_total ?? 0;
      raster.cloudLow[idx] = row.cloud_low ?? 0;
      raster.cloudMid[idx] = row.cloud_mid ?? 0;
      raster.cloudHigh[idx] = row.cloud_high ?? 0;
      raster.flightCategory[idx] =
        FCAT_MAP[row.flight_category] ?? 255;
      raster.visibilitySm[idx] = row.visibility_sm ?? -1;
    }

    this.rasterCache.set(forecastHour, raster);
    this.lastKnownInitTime = initTime;

    this.logger.log(
      `Loaded CONUS raster fh=${forecastHour}: ${rows.length} rows`,
    );

    return raster;
  }

  // --- Pressure raster loading ---

  private async loadPressureRaster(
    forecastHour: number,
    pressureLevel: number,
  ): Promise<PressureConusRaster | null> {
    const key = `${forecastHour}:${pressureLevel}`;
    const cached = this.pressureRasterCache.get(key);
    if (cached) return cached;

    const existing = this.pressureLoadPromises.get(key);
    if (existing) return existing;

    const promise = this.doLoadPressureRaster(forecastHour, pressureLevel);
    this.pressureLoadPromises.set(key, promise);
    try {
      return await promise;
    } finally {
      this.pressureLoadPromises.delete(key);
    }
  }

  private async doLoadPressureRaster(
    forecastHour: number,
    pressureLevel: number,
  ): Promise<PressureConusRaster | null> {
    const activeCycle = await this.cycleRepo.findOne({
      where: { is_active: true },
    });
    if (!activeCycle) return null;

    const initTime = activeCycle.init_time.toISOString();

    const rows = await this.pressureRepo.find({
      where: {
        init_time: activeCycle.init_time,
        forecast_hour: forecastHour,
        pressure_level: pressureLevel,
      },
    });

    if (rows.length === 0) return null;

    const raster: PressureConusRaster = {
      initTime,
      forecastHour,
      pressureLevel,
      relativeHumidity: new Float32Array(GRID_SIZE).fill(-1),
    };

    for (const row of rows) {
      const latIdx = Math.round(row.lat - MIN_LAT);
      const lngIdx = Math.round(row.lng - MIN_LNG);
      if (
        latIdx < 0 ||
        latIdx >= GRID_ROWS ||
        lngIdx < 0 ||
        lngIdx >= GRID_COLS
      ) {
        continue;
      }
      const idx = latIdx * GRID_COLS + lngIdx;
      raster.relativeHumidity[idx] = row.relative_humidity ?? -1;
    }

    this.pressureRasterCache.set(`${forecastHour}:${pressureLevel}`, raster);
    this.lastKnownInitTime = initTime;

    this.logger.log(
      `Loaded pressure raster fh=${forecastHour} level=${pressureLevel}hPa: ${rows.length} rows`,
    );

    return raster;
  }

  // --- Pressure tile rendering ---

  private renderPressureTileFromRaster(
    raster: PressureConusRaster,
    z: number,
    x: number,
    y: number,
  ): Buffer {
    const png = new PNG({ width: TILE_SIZE, height: TILE_SIZE });
    const totalPixels = TILE_SIZE << z;

    for (let py = 0; py < TILE_SIZE; py++) {
      const globalY = y * TILE_SIZE + py;
      const lat = tilePixelYToLat(globalY, totalPixels);

      for (let px = 0; px < TILE_SIZE; px++) {
        const globalX = x * TILE_SIZE + px;
        const lng = tilePixelXToLng(globalX, totalPixels);

        const rgba = this.colorCloudRH(raster.relativeHumidity, lat, lng);

        const idx = (py * TILE_SIZE + px) * 4;
        png.data[idx] = rgba[0];
        png.data[idx + 1] = rgba[1];
        png.data[idx + 2] = rgba[2];
        png.data[idx + 3] = rgba[3];
      }
    }

    return PNG.sync.write(png);
  }

  private colorCloudRH(
    data: Float32Array,
    lat: number,
    lng: number,
  ): [number, number, number, number] {
    if (lat < MIN_LAT || lat > MAX_LAT || lng < MIN_LNG || lng > MAX_LNG) {
      return [0, 0, 0, 0];
    }
    const rh = bilinearSample(data, lat, lng);
    if (rh < 0 || rh < 50) return [0, 0, 0, 0];
    // RH 50-100% → white cloud, alpha 0-210
    const alpha = Math.round(((rh - 50) / 50) * 210);
    if (alpha < 5) return [0, 0, 0, 0];
    return [255, 255, 255, alpha];
  }

  // --- Cycle change detection ---

  private async checkCycleChange(): Promise<void> {
    const now = Date.now();
    if (now - this.lastCycleCheck < CYCLE_CHECK_INTERVAL_MS) return;
    this.lastCycleCheck = now;

    const activeCycle = await this.cycleRepo.findOne({
      where: { is_active: true },
    });
    if (!activeCycle) return;

    const currentInit = activeCycle.init_time.toISOString();
    if (this.lastKnownInitTime && currentInit !== this.lastKnownInitTime) {
      this.logger.log(
        `HRRR cycle changed: ${this.lastKnownInitTime} → ${currentInit}. Evicting caches.`,
      );
      this.rasterCache.clear();
      this.pressureRasterCache.clear();
      this.tileCache.clear();
      this.lastKnownInitTime = currentInit;
    }
  }

  // --- Tile rendering ---

  private renderTileFromRaster(
    product: TileProduct,
    raster: ConusRaster,
    z: number,
    x: number,
    y: number,
  ): Buffer {
    const png = new PNG({ width: TILE_SIZE, height: TILE_SIZE });
    const totalPixels = TILE_SIZE << z; // 256 * 2^z

    for (let py = 0; py < TILE_SIZE; py++) {
      const globalY = y * TILE_SIZE + py;
      const lat = tilePixelYToLat(globalY, totalPixels);

      for (let px = 0; px < TILE_SIZE; px++) {
        const globalX = x * TILE_SIZE + px;
        const lng = tilePixelXToLng(globalX, totalPixels);

        const rgba = this.sampleAndColor(product, raster, lat, lng);

        const idx = (py * TILE_SIZE + px) * 4;
        png.data[idx] = rgba[0];
        png.data[idx + 1] = rgba[1];
        png.data[idx + 2] = rgba[2];
        png.data[idx + 3] = rgba[3];
      }
    }

    return PNG.sync.write(png);
  }

  private sampleAndColor(
    product: TileProduct,
    raster: ConusRaster,
    lat: number,
    lng: number,
  ): [number, number, number, number] {
    // Outside CONUS → transparent
    if (lat < MIN_LAT || lat > MAX_LAT || lng < MIN_LNG || lng > MAX_LNG) {
      return [0, 0, 0, 0];
    }

    switch (product) {
      case 'flight-cat':
        return this.colorFlightCat(raster, lat, lng);
      case 'clouds-total':
        return this.colorCloud(raster.cloudTotal, lat, lng);
      case 'clouds-low':
        return this.colorCloud(raster.cloudLow, lat, lng);
      case 'clouds-mid':
        return this.colorCloud(raster.cloudMid, lat, lng);
      case 'clouds-high':
        return this.colorCloud(raster.cloudHigh, lat, lng);
      case 'visibility':
        return this.colorVisibility(raster, lat, lng);
      default:
        return [0, 0, 0, 0];
    }
  }

  // --- Color maps ---

  private colorFlightCat(
    raster: ConusRaster,
    lat: number,
    lng: number,
  ): [number, number, number, number] {
    // Nearest-neighbor for categorical data
    const latIdx = Math.round(lat - MIN_LAT);
    const lngIdx = Math.round(lng - MIN_LNG);
    if (
      latIdx < 0 ||
      latIdx >= GRID_ROWS ||
      lngIdx < 0 ||
      lngIdx >= GRID_COLS
    ) {
      return [0, 0, 0, 0];
    }

    const cat = raster.flightCategory[latIdx * GRID_COLS + lngIdx];
    switch (cat) {
      case 0: // VFR — transparent
        return [0, 0, 0, 0];
      case 1: // MVFR — blue
        return [33, 150, 243, 160];
      case 2: // IFR — red
        return [255, 23, 68, 160];
      case 3: // LIFR — magenta
        return [224, 64, 251, 160];
      default:
        return [0, 0, 0, 0];
    }
  }

  private colorCloud(
    data: Float32Array,
    lat: number,
    lng: number,
  ): [number, number, number, number] {
    const value = bilinearSample(data, lat, lng);
    if (value < 0) return [0, 0, 0, 0];
    const coverage = Math.min(100, Math.max(0, value));
    const alpha = Math.round((coverage / 100) * 210);
    if (alpha < 5) return [0, 0, 0, 0];
    return [255, 255, 255, alpha];
  }

  private colorVisibility(
    raster: ConusRaster,
    lat: number,
    lng: number,
  ): [number, number, number, number] {
    const visSm = bilinearSample(raster.visibilitySm, lat, lng);
    if (visSm < 0) return [0, 0, 0, 0];

    if (visSm < 1) return [255, 23, 68, 180]; // red
    if (visSm < 3) return [255, 152, 0, 150]; // orange
    if (visSm < 5) return [255, 235, 59, 120]; // yellow
    return [0, 0, 0, 0]; // ≥5sm transparent
  }
}

// --- Web Mercator projection ---

export function tilePixelXToLng(globalX: number, totalPixels: number): number {
  return (globalX / totalPixels) * 360 - 180;
}

export function tilePixelYToLat(globalY: number, totalPixels: number): number {
  const n = Math.PI - (2 * Math.PI * globalY) / totalPixels;
  return (Math.atan(Math.sinh(n)) * 180) / Math.PI;
}

/** Returns the lat/lng bounding box of a tile. */
export function tileToLatLngBounds(
  z: number,
  x: number,
  y: number,
): { minLat: number; maxLat: number; minLng: number; maxLng: number } {
  const n = 1 << z;
  const minLng = (x / n) * 360 - 180;
  const maxLng = ((x + 1) / n) * 360 - 180;
  // Note: y=0 is north, so y gives maxLat and y+1 gives minLat
  const maxLat =
    (Math.atan(Math.sinh(Math.PI - (2 * Math.PI * y) / n)) * 180) / Math.PI;
  const minLat =
    (Math.atan(Math.sinh(Math.PI - (2 * Math.PI * (y + 1)) / n)) * 180) /
    Math.PI;
  return { minLat, maxLat, minLng, maxLng };
}

// --- Bilinear interpolation ---

export function bilinearSample(
  data: Float32Array,
  lat: number,
  lng: number,
): number {
  // Convert to fractional grid coordinates
  const fy = lat - MIN_LAT; // row (0 = lat 24)
  const fx = lng - MIN_LNG; // col (0 = lng -125)

  const x0 = Math.floor(fx);
  const y0 = Math.floor(fy);
  const x1 = x0 + 1;
  const y1 = y0 + 1;

  // Clamp to grid bounds
  const cx0 = Math.max(0, Math.min(GRID_COLS - 1, x0));
  const cx1 = Math.max(0, Math.min(GRID_COLS - 1, x1));
  const cy0 = Math.max(0, Math.min(GRID_ROWS - 1, y0));
  const cy1 = Math.max(0, Math.min(GRID_ROWS - 1, y1));

  const dx = fx - x0;
  const dy = fy - y0;

  const v00 = data[cy0 * GRID_COLS + cx0];
  const v10 = data[cy0 * GRID_COLS + cx1];
  const v01 = data[cy1 * GRID_COLS + cx0];
  const v11 = data[cy1 * GRID_COLS + cx1];

  // Check for sentinel values (-1 means no data)
  if (v00 < 0 || v10 < 0 || v01 < 0 || v11 < 0) {
    // Use nearest-neighbor fallback for cells near data boundaries
    const nearY = Math.round(fy);
    const nearX = Math.round(fx);
    const cny = Math.max(0, Math.min(GRID_ROWS - 1, nearY));
    const cnx = Math.max(0, Math.min(GRID_COLS - 1, nearX));
    return data[cny * GRID_COLS + cnx];
  }

  return (
    v00 * (1 - dx) * (1 - dy) +
    v10 * dx * (1 - dy) +
    v01 * (1 - dx) * dy +
    v11 * dx * dy
  );
}
