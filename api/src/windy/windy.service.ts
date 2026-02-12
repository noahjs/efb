import { Injectable, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';
import { PNG } from 'pngjs';
import { WINDS } from '../config/constants';

export interface WindPoint {
  lat: number;
  lng: number;
  direction: number; // degrees (wind FROM)
  speed: number; // knots
  temperature?: number; // celsius
}

export interface WindForecastLevel {
  level: string; // e.g. '850hPa'
  altitudeFt: number;
  winds: Array<{
    timestamp: number;
    direction: number;
    speed: number;
    temperature: number;
    isaDeviation: number;
  }>;
}

export interface PointForecastResult {
  lat: number;
  lng: number;
  model: string;
  levels: WindForecastLevel[];
}

export interface RouteWindLeg {
  fromLat: number;
  fromLng: number;
  toLat: number;
  toLng: number;
  distanceNm: number;
  windDirection: number;
  windSpeed: number;
  headwindComponent: number; // positive = headwind, negative = tailwind
  crosswindComponent: number;
  groundspeed: number;
}

export interface RouteWindResult {
  altitudeFt: number;
  legs: RouteWindLeg[];
  avgWindComponent: number; // negative = headwind avg, positive = tailwind avg
  avgGroundspeed: number;
  totalDistanceNm: number;
}

export interface WindGridResult {
  altitudeFt: number;
  type: 'FeatureCollection';
  features: Array<{
    type: 'Feature';
    geometry: { type: 'Point'; coordinates: [number, number] };
    properties: {
      direction: number;
      speed: number;
      temperature: number;
      rotation: number;
      label: string;
      color: string;
      barbIcon: string;
      speedLabel: string;
      tempLabel: string;
    };
  }>;
}

export interface WindStreamlineResult {
  altitudeFt: number;
  type: 'FeatureCollection';
  features: Array<{
    type: 'Feature';
    geometry: { type: 'LineString'; coordinates: [number, number][] };
    properties: {
      avgSpeed: number;
      color: string;
      speedCategory: string;
    };
  }>;
}

@Injectable()
export class WindyService {
  private readonly logger = new Logger(WindyService.name);
  private cache = new Map<string, { data: any; expiresAt: number }>();

  // API status tracking
  private _totalRequests = 0;
  private _totalErrors = 0;
  private _lastFetchAt = 0;
  private _lastErrorAt = 0;
  private _lastError = '';

  constructor(private readonly http: HttpService) {}

  /**
   * Get wind forecast at a single point for all pressure levels.
   * Uses the batch API internally (batch of 1).
   */
  async getPointForecast(
    lat: number,
    lng: number,
    model?: string,
  ): Promise<PointForecastResult> {
    const results = await this.getBatchForecasts([{ lat, lng }], model);
    return results[0];
  }

  /**
   * Batch-fetch wind forecasts for multiple coordinates in a single API call.
   * Open-Meteo accepts comma-separated lat/lng arrays.
   * Returns results in the same order as the input points.
   */
  async getBatchForecasts(
    points: Array<{ lat: number; lng: number }>,
    model?: string,
  ): Promise<PointForecastResult[]> {
    const useModel = model || WINDS.DEFAULT_MODEL;

    // Check cache first — only fetch uncached points
    const results: (PointForecastResult | null)[] = points.map((p) => {
      const cacheKey = `wind-point:${p.lat.toFixed(2)}:${p.lng.toFixed(2)}:${useModel}`;
      return this.getFromCache(cacheKey) || null;
    });

    const uncachedIndices = results
      .map((r, i) => (r === null ? i : -1))
      .filter((i) => i >= 0);

    if (uncachedIndices.length === 0) {
      return results as PointForecastResult[];
    }

    const uncachedPoints = uncachedIndices.map((i) => points[i]);

    // Build hourly variables list
    const hourlyVars: string[] = [
      'wind_speed_10m',
      'wind_direction_10m',
      'temperature_2m',
    ];
    for (const hPa of WINDS.PRESSURE_LEVELS) {
      hourlyVars.push(
        `wind_speed_${hPa}hPa`,
        `wind_direction_${hPa}hPa`,
        `temperature_${hPa}hPa`,
      );
    }

    const endpoint =
      WINDS.MODEL_ENDPOINTS[useModel] || WINDS.MODEL_ENDPOINTS.gfs_seamless;

    try {
      this._totalRequests++;
      const { data } = await firstValueFrom(
        this.http.get(`${WINDS.API_BASE_URL}${endpoint}`, {
          params: {
            latitude: uncachedPoints.map((p) => p.lat.toFixed(2)).join(','),
            longitude: uncachedPoints.map((p) => p.lng.toFixed(2)).join(','),
            hourly: hourlyVars.join(','),
            wind_speed_unit: 'kn',
            forecast_days: WINDS.FORECAST_DAYS,
            models: useModel,
          },
          timeout: 30000,
        }),
      );

      // Open-Meteo returns an array when multiple points, single object for one point
      const hourlyResults: any[] = Array.isArray(data) ? data : [data];

      for (let idx = 0; idx < uncachedPoints.length; idx++) {
        const p = uncachedPoints[idx];
        const hourly = hourlyResults[idx]?.hourly || hourlyResults[0]?.hourly;
        if (!hourly) continue;

        const times: string[] = hourly.time || [];
        const timestamps = times.map((t: string) =>
          new Date(t + 'Z').getTime(),
        );
        const levels: WindForecastLevel[] = [];

        // Surface level
        {
          const speeds: number[] = hourly.wind_speed_10m || [];
          const dirs: number[] = hourly.wind_direction_10m || [];
          const temps: number[] = hourly.temperature_2m || [];
          const winds = timestamps.map((ts, i) => {
            const speed = Math.round(speeds[i] ?? 0);
            const direction = Math.round(dirs[i] ?? 0);
            const temperature = Math.round((temps[i] ?? 15) * 10) / 10;
            const isaDeviation = Math.round(
              temperature - this.isaTemperature(0),
            );
            return {
              timestamp: ts,
              direction,
              speed,
              temperature,
              isaDeviation,
            };
          });
          levels.push({ level: 'surface', altitudeFt: 0, winds });
        }

        // Pressure levels
        for (const hPa of WINDS.PRESSURE_LEVELS) {
          const speeds: number[] = hourly[`wind_speed_${hPa}hPa`] || [];
          const dirs: number[] = hourly[`wind_direction_${hPa}hPa`] || [];
          const temps: number[] = hourly[`temperature_${hPa}hPa`] || [];
          const altFt = WINDS.LEVEL_ALTITUDES[hPa] || 0;

          const winds = timestamps.map((ts, i) => {
            const speed = Math.round(speeds[i] ?? 0);
            const direction = Math.round(dirs[i] ?? 0);
            const temperature = Math.round((temps[i] ?? 0) * 10) / 10;
            const isaDeviation = Math.round(
              temperature - this.isaTemperature(altFt),
            );
            return {
              timestamp: ts,
              direction,
              speed,
              temperature,
              isaDeviation,
            };
          });
          levels.push({ level: `${hPa}hPa`, altitudeFt: altFt, winds });
        }

        const forecast: PointForecastResult = {
          lat: p.lat,
          lng: p.lng,
          model: useModel,
          levels,
        };

        const cacheKey = `wind-point:${p.lat.toFixed(2)}:${p.lng.toFixed(2)}:${useModel}`;
        this.setCache(cacheKey, forecast, WINDS.CACHE_TTL_POINT_MS);
        results[uncachedIndices[idx]] = forecast;
      }
    } catch (error) {
      this._totalErrors++;
      this._lastErrorAt = Date.now();
      this._lastError = error?.message || String(error);
      this.logger.error(
        `Open-Meteo batch API error for ${uncachedPoints.length} points: ${error.message}`,
      );
    }

    // Fill any remaining nulls with empty forecasts
    return results.map(
      (r, i) =>
        r || {
          lat: points[i].lat,
          lng: points[i].lng,
          model: useModel,
          levels: [
            { level: 'surface', altitudeFt: 0, winds: [] },
            ...WINDS.PRESSURE_LEVELS.map((hPa) => ({
              level: `${hPa}hPa`,
              altitudeFt: WINDS.LEVEL_ALTITUDES[hPa] || 0,
              winds: [],
            })),
          ],
        },
    );
  }

  /**
   * Get wind data along a route at a specific altitude.
   * Samples points every ROUTE_SAMPLE_INTERVAL_NM along the route.
   */
  async getRouteWinds(
    waypoints: Array<{ lat: number; lng: number }>,
    altitudeFt: number,
    tas: number,
  ): Promise<RouteWindResult> {
    if (waypoints.length < 2) {
      return {
        altitudeFt,
        legs: [],
        avgWindComponent: 0,
        avgGroundspeed: tas,
        totalDistanceNm: 0,
      };
    }

    // Sample points along the route
    const samplePoints = this.sampleRoutePoints(
      waypoints,
      WINDS.ROUTE_SAMPLE_INTERVAL_NM,
    );

    // Single batch API call for all sample points
    const forecasts = await this.getBatchForecasts(samplePoints);

    // Build legs with wind data
    const legs: RouteWindLeg[] = [];
    let totalWeightedComponent = 0;
    let totalWeightedGs = 0;
    let totalDistanceNm = 0;

    for (let i = 0; i < samplePoints.length - 1; i++) {
      const from = samplePoints[i];
      const to = samplePoints[i + 1];
      const course = this.bearing(from.lat, from.lng, to.lat, to.lng);
      const distanceNm = this.distanceNm(from.lat, from.lng, to.lat, to.lng);

      // Get wind at the requested altitude (interpolate between pressure levels)
      const wind = this.getWindAtAltitude(forecasts[i], altitudeFt);

      // Compute wind components
      const windAngle =
        ((wind.direction - course + 360) % 360) * (Math.PI / 180);
      const headwindComponent = wind.speed * Math.cos(windAngle);
      const crosswindComponent = wind.speed * Math.sin(windAngle);

      // Wind triangle for groundspeed
      const gs = this.computeGroundspeed(
        tas,
        course,
        wind.direction,
        wind.speed,
      );

      legs.push({
        fromLat: from.lat,
        fromLng: from.lng,
        toLat: to.lat,
        toLng: to.lng,
        distanceNm,
        windDirection: wind.direction,
        windSpeed: wind.speed,
        headwindComponent: Math.round(headwindComponent),
        crosswindComponent: Math.round(crosswindComponent),
        groundspeed: Math.round(gs),
      });

      totalWeightedComponent += headwindComponent * distanceNm;
      totalWeightedGs += gs * distanceNm;
      totalDistanceNm += distanceNm;
    }

    const avgWindComponent =
      totalDistanceNm > 0
        ? Math.round(totalWeightedComponent / totalDistanceNm)
        : 0;
    const avgGroundspeed =
      totalDistanceNm > 0 ? Math.round(totalWeightedGs / totalDistanceNm) : tas;

    return {
      altitudeFt,
      legs,
      avgWindComponent: -avgWindComponent, // negative = headwind for display
      avgGroundspeed,
      totalDistanceNm: Math.round(totalDistanceNm),
    };
  }

  /**
   * Get a grid of wind data for map visualization.
   */
  async getWindGrid(
    bounds: {
      minLat: number;
      maxLat: number;
      minLng: number;
      maxLng: number;
    },
    altitudeFt: number,
    gridSpacingDeg = 1.0,
  ): Promise<WindGridResult> {
    const cacheKey = `wind-grid:${bounds.minLat.toFixed(0)}:${bounds.maxLat.toFixed(0)}:${bounds.minLng.toFixed(0)}:${bounds.maxLng.toFixed(0)}:${altitudeFt}:${gridSpacingDeg}`;
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    const points: Array<{ lat: number; lng: number }> = [];
    for (
      let lat = Math.ceil(bounds.minLat / gridSpacingDeg) * gridSpacingDeg;
      lat <= bounds.maxLat;
      lat += gridSpacingDeg
    ) {
      for (
        let lng = Math.ceil(bounds.minLng / gridSpacingDeg) * gridSpacingDeg;
        lng <= bounds.maxLng;
        lng += gridSpacingDeg
      ) {
        points.push({ lat, lng });
      }
    }

    // Limit grid points to avoid excessive API calls
    const maxPoints = 120;
    const selectedPoints =
      points.length > maxPoints
        ? this.uniformSample(points, maxPoints)
        : points;

    // Single batch API call for all grid points
    const forecasts = await this.getBatchForecasts(selectedPoints);

    const features = forecasts.map((forecast, i) => {
      const wind = this.getWindAtAltitude(forecast, altitudeFt);
      return {
        type: 'Feature' as const,
        geometry: {
          type: 'Point' as const,
          coordinates: [selectedPoints[i].lng, selectedPoints[i].lat] as [
            number,
            number,
          ],
        },
        properties: {
          direction: wind.direction,
          speed: wind.speed,
          temperature: wind.temperature,
          rotation: wind.direction, // for icon rotation
          label: `${Math.round(wind.direction)}/${Math.round(wind.speed)}`,
          color: this.windSpeedColor(wind.speed),
          barbIcon: this.barbIconName(wind.speed),
          speedLabel: `${Math.round(wind.speed)}`,
          tempLabel: `${wind.temperature > 0 ? '+' : ''}${wind.temperature}°`,
        },
      };
    });

    const result: WindGridResult = {
      altitudeFt,
      type: 'FeatureCollection',
      features,
    };

    this.setCache(cacheKey, result, WINDS.CACHE_TTL_GRID_MS);
    return result;
  }

  /**
   * Generate a wind speed heatmap as a PNG image.
   * Uses bilinear interpolation from a ~1° internal wind grid.
   */
  async getWindHeatmapPng(
    bounds: {
      minLat: number;
      maxLat: number;
      minLng: number;
      maxLng: number;
    },
    altitudeFt: number,
    width = 256,
    height = 256,
  ): Promise<Buffer> {
    const cacheKey = `wind-heatmap:${bounds.minLat.toFixed(0)}:${bounds.maxLat.toFixed(0)}:${bounds.minLng.toFixed(0)}:${bounds.maxLng.toFixed(0)}:${altitudeFt}:${width}:${height}`;
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    // Build internal grid at ~1° spacing
    const gridSpacing = 1.0;
    const gridPoints: Array<{ lat: number; lng: number }> = [];
    const gridMinLat =
      Math.floor(bounds.minLat / gridSpacing) * gridSpacing - gridSpacing;
    const gridMaxLat =
      Math.ceil(bounds.maxLat / gridSpacing) * gridSpacing + gridSpacing;
    const gridMinLng =
      Math.floor(bounds.minLng / gridSpacing) * gridSpacing - gridSpacing;
    const gridMaxLng =
      Math.ceil(bounds.maxLng / gridSpacing) * gridSpacing + gridSpacing;

    for (let lat = gridMinLat; lat <= gridMaxLat; lat += gridSpacing) {
      for (let lng = gridMinLng; lng <= gridMaxLng; lng += gridSpacing) {
        gridPoints.push({ lat, lng });
      }
    }

    // Fetch wind data for all grid points
    const forecasts = await this.getBatchForecasts(gridPoints);

    // Build speed lookup grid
    const cols = Math.round((gridMaxLng - gridMinLng) / gridSpacing) + 1;
    const rows = Math.round((gridMaxLat - gridMinLat) / gridSpacing) + 1;
    const speedGrid = new Float32Array(rows * cols);

    for (let i = 0; i < gridPoints.length; i++) {
      const wind = this.getWindAtAltitude(forecasts[i], altitudeFt);
      const row = Math.round((gridPoints[i].lat - gridMinLat) / gridSpacing);
      const col = Math.round((gridPoints[i].lng - gridMinLng) / gridSpacing);
      if (row >= 0 && row < rows && col >= 0 && col < cols) {
        speedGrid[row * cols + col] = wind.speed;
      }
    }

    // Bilinear interpolation helper
    const getSpeed = (lat: number, lng: number): number => {
      const fRow = (lat - gridMinLat) / gridSpacing;
      const fCol = (lng - gridMinLng) / gridSpacing;
      const r0 = Math.floor(fRow);
      const c0 = Math.floor(fCol);
      const r1 = Math.min(r0 + 1, rows - 1);
      const c1 = Math.min(c0 + 1, cols - 1);
      const fr = fRow - r0;
      const fc = fCol - c0;
      const s00 = speedGrid[Math.max(0, r0) * cols + Math.max(0, c0)];
      const s01 = speedGrid[Math.max(0, r0) * cols + c1];
      const s10 = speedGrid[r1 * cols + Math.max(0, c0)];
      const s11 = speedGrid[r1 * cols + c1];
      return (
        s00 * (1 - fr) * (1 - fc) +
        s01 * (1 - fr) * fc +
        s10 * fr * (1 - fc) +
        s11 * fr * fc
      );
    };

    // Render PNG
    const png = new PNG({ width, height });

    for (let py = 0; py < height; py++) {
      for (let px = 0; px < width; px++) {
        const lat =
          bounds.maxLat - (py / height) * (bounds.maxLat - bounds.minLat);
        const lng =
          bounds.minLng + (px / width) * (bounds.maxLng - bounds.minLng);
        const speed = getSpeed(lat, lng);
        const color = this.heatmapColor(speed);
        const idx = (py * width + px) * 4;
        png.data[idx] = color[0];
        png.data[idx + 1] = color[1];
        png.data[idx + 2] = color[2];
        png.data[idx + 3] = 160; // semi-transparent
      }
    }

    const buffer = PNG.sync.write(png);
    this.setCache(cacheKey, buffer, WINDS.CACHE_TTL_GRID_MS);
    return buffer;
  }

  /**
   * Windy-style 10-stop heatmap color gradient.
   * Returns [R, G, B] for a given wind speed in knots.
   */
  private heatmapColor(speedKt: number): [number, number, number] {
    // Gradient stops: [speed, R, G, B]
    const stops: [number, number, number, number][] = [
      [0, 30, 60, 150], // deep blue
      [5, 40, 100, 200], // blue
      [10, 0, 170, 180], // teal
      [15, 50, 190, 80], // green
      [20, 140, 210, 50], // yellow-green
      [30, 255, 220, 0], // yellow
      [40, 255, 165, 0], // orange
      [50, 240, 80, 30], // red
      [65, 180, 20, 20], // dark red
      [80, 150, 0, 150], // purple
    ];

    if (speedKt <= stops[0][0]) return [stops[0][1], stops[0][2], stops[0][3]];
    if (speedKt >= stops[stops.length - 1][0]) {
      const last = stops[stops.length - 1];
      return [last[1], last[2], last[3]];
    }

    for (let i = 0; i < stops.length - 1; i++) {
      if (speedKt >= stops[i][0] && speedKt <= stops[i + 1][0]) {
        const t = (speedKt - stops[i][0]) / (stops[i + 1][0] - stops[i][0]);
        return [
          Math.round(stops[i][1] + (stops[i + 1][1] - stops[i][1]) * t),
          Math.round(stops[i][2] + (stops[i + 1][2] - stops[i][2]) * t),
          Math.round(stops[i][3] + (stops[i + 1][3] - stops[i][3]) * t),
        ];
      }
    }

    return [150, 0, 150]; // fallback
  }

  // --- Helper methods ---

  /**
   * Interpolate wind at a specific altitude from pressure-level data.
   * Uses the nearest available timestamp (current time).
   */
  getWindAtAltitude(
    forecast: PointForecastResult,
    altitudeFt: number,
  ): { direction: number; speed: number; temperature: number } {
    const levels = forecast.levels;
    if (levels.length === 0) return { direction: 0, speed: 0, temperature: 0 };

    // Find the two bounding levels for interpolation
    let lower = levels[0];
    let upper = levels[levels.length - 1];

    for (let i = 0; i < levels.length - 1; i++) {
      if (
        levels[i].altitudeFt <= altitudeFt &&
        levels[i + 1].altitudeFt >= altitudeFt
      ) {
        lower = levels[i];
        upper = levels[i + 1];
        break;
      }
    }

    // Clamp to boundaries
    if (altitudeFt <= lower.altitudeFt) {
      const w = this.getNearestWind(lower);
      return w || { direction: 0, speed: 0, temperature: 0 };
    }
    if (altitudeFt >= upper.altitudeFt) {
      const w = this.getNearestWind(upper);
      return w || { direction: 0, speed: 0, temperature: 0 };
    }

    // Linear interpolation
    const lowerWind = this.getNearestWind(lower);
    const upperWind = this.getNearestWind(upper);
    if (!lowerWind || !upperWind) {
      return lowerWind || upperWind || { direction: 0, speed: 0, temperature: 0 };
    }

    const altRange = upper.altitudeFt - lower.altitudeFt;
    const fraction =
      altRange > 0 ? (altitudeFt - lower.altitudeFt) / altRange : 0;

    // Interpolate speed linearly
    const speed =
      lowerWind.speed + (upperWind.speed - lowerWind.speed) * fraction;

    // Interpolate direction (handling 360/0 wrap)
    const dir = this.interpolateAngle(
      lowerWind.direction,
      upperWind.direction,
      fraction,
    );

    // Interpolate temperature linearly
    const temperature =
      lowerWind.temperature + (upperWind.temperature - lowerWind.temperature) * fraction;

    return {
      direction: Math.round(dir),
      speed: Math.round(speed),
      temperature: Math.round(temperature),
    };
  }

  /**
   * Get the wind entry closest to current time for a level.
   */
  private getNearestWind(
    level: WindForecastLevel,
  ): { direction: number; speed: number; temperature: number } | null {
    if (level.winds.length === 0) return null;
    const now = Date.now();
    let closest = level.winds[0];
    let closestDiff = Math.abs(closest.timestamp - now);
    for (const w of level.winds) {
      const diff = Math.abs(w.timestamp - now);
      if (diff < closestDiff) {
        closest = w;
        closestDiff = diff;
      }
    }
    return {
      direction: closest.direction,
      speed: closest.speed,
      temperature: closest.temperature,
    };
  }

  /**
   * Interpolate between two angles handling the 360/0 wrap.
   */
  private interpolateAngle(a: number, b: number, fraction: number): number {
    let diff = b - a;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    let result = a + diff * fraction;
    if (result < 0) result += 360;
    if (result >= 360) result -= 360;
    return result;
  }

  /**
   * Compute groundspeed using the wind triangle.
   */
  computeGroundspeed(
    tas: number,
    courseDeg: number,
    windDirDeg: number,
    windSpeedKt: number,
  ): number {
    if (windSpeedKt === 0) return tas;
    const courseRad = (courseDeg * Math.PI) / 180;
    const windRad = (windDirDeg * Math.PI) / 180;

    const windAngle = windRad - courseRad;
    const headwind = windSpeedKt * Math.cos(windAngle);
    const crosswind = windSpeedKt * Math.sin(windAngle);

    // Wind correction angle
    const sinWca = crosswind / tas;
    const wca = Math.abs(sinWca) < 1 ? Math.asin(sinWca) : 0;

    const gs = tas * Math.cos(wca) - headwind;
    return Math.max(gs, 0); // floor at 0
  }

  /**
   * Sample points along a route at regular intervals.
   */
  sampleRoutePoints(
    waypoints: Array<{ lat: number; lng: number }>,
    intervalNm: number,
  ): Array<{ lat: number; lng: number }> {
    const result: Array<{ lat: number; lng: number }> = [waypoints[0]];

    let accumulated = 0;
    for (let i = 1; i < waypoints.length; i++) {
      const from = waypoints[i - 1];
      const to = waypoints[i];
      const legDist = this.distanceNm(from.lat, from.lng, to.lat, to.lng);

      accumulated += legDist;
      if (accumulated >= intervalNm || i === waypoints.length - 1) {
        result.push(to);
        accumulated = 0;
      }
    }

    return result;
  }

  /**
   * Uniformly sample N items from an array.
   */
  private uniformSample<T>(arr: T[], n: number): T[] {
    if (arr.length <= n) return arr;
    const step = arr.length / n;
    return Array.from({ length: n }, (_, i) => arr[Math.floor(i * step)]);
  }

  /**
   * Compute great-circle bearing between two points (degrees).
   */
  bearing(lat1: number, lng1: number, lat2: number, lng2: number): number {
    const toRad = Math.PI / 180;
    const dLng = (lng2 - lng1) * toRad;
    const y = Math.sin(dLng) * Math.cos(lat2 * toRad);
    const x =
      Math.cos(lat1 * toRad) * Math.sin(lat2 * toRad) -
      Math.sin(lat1 * toRad) * Math.cos(lat2 * toRad) * Math.cos(dLng);
    const brg = (Math.atan2(y, x) * 180) / Math.PI;
    return (brg + 360) % 360;
  }

  /**
   * Compute great-circle distance between two points (nautical miles).
   */
  distanceNm(lat1: number, lng1: number, lat2: number, lng2: number): number {
    const toRad = Math.PI / 180;
    const dLat = (lat2 - lat1) * toRad;
    const dLng = (lng2 - lng1) * toRad;
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(lat1 * toRad) * Math.cos(lat2 * toRad) * Math.sin(dLng / 2) ** 2;
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return 3440.065 * c; // Earth radius in NM
  }

  /**
   * Return the barb icon name for a given wind speed.
   */
  private barbIconName(speedKt: number): string {
    if (speedKt < 3) return 'barb-calm';
    const rounded = Math.round(speedKt / 5) * 5;
    return `barb-${Math.min(rounded, 80)}`;
  }

  /**
   * Generate wind streamlines for map visualization.
   * Traces particle paths through the wind field from a grid of seed points.
   */
  async getWindStreamlines(
    bounds: {
      minLat: number;
      maxLat: number;
      minLng: number;
      maxLng: number;
    },
    altitudeFt: number,
  ): Promise<WindStreamlineResult> {
    const cacheKey = `wind-streamlines:${bounds.minLat.toFixed(0)}:${bounds.maxLat.toFixed(0)}:${bounds.minLng.toFixed(0)}:${bounds.maxLng.toFixed(0)}:${altitudeFt}`;
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    // Create seed points at 1° spacing (fewer seeds, faster response)
    const seedPoints: Array<{ lat: number; lng: number }> = [];
    for (let lat = Math.ceil(bounds.minLat); lat <= bounds.maxLat; lat += 1.0) {
      for (
        let lng = Math.ceil(bounds.minLng);
        lng <= bounds.maxLng;
        lng += 1.0
      ) {
        seedPoints.push({ lat, lng });
      }
    }

    // Limit seed points
    const maxSeeds = 30;
    const selectedSeeds =
      seedPoints.length > maxSeeds
        ? this.uniformSample(seedPoints, maxSeeds)
        : seedPoints;

    // Fetch forecasts for all unique seed points in parallel (reuses point cache)
    const forecastList: Array<{
      lat: number;
      lng: number;
      forecast: PointForecastResult;
    }> = [];
    const seen = new Set<string>();
    const fetchJobs: Array<{ lat: number; lng: number }> = [];

    for (const p of selectedSeeds) {
      const key = `${p.lat.toFixed(1)},${p.lng.toFixed(1)}`;
      if (!seen.has(key)) {
        seen.add(key);
        fetchJobs.push({ lat: p.lat, lng: p.lng });
      }
    }

    // Single batch API call for all seed points
    const forecasts = await this.getBatchForecasts(fetchJobs);
    fetchJobs.forEach((j, i) =>
      forecastList.push({ lat: j.lat, lng: j.lng, forecast: forecasts[i] }),
    );

    // Nearest-neighbor lookup: find the closest pre-fetched forecast point
    const getNearestForecast = (
      lat: number,
      lng: number,
    ): PointForecastResult => {
      let best = forecastList[0];
      let bestDist = (lat - best.lat) ** 2 + (lng - best.lng) ** 2;
      for (let i = 1; i < forecastList.length; i++) {
        const d =
          (lat - forecastList[i].lat) ** 2 + (lng - forecastList[i].lng) ** 2;
        if (d < bestDist) {
          bestDist = d;
          best = forecastList[i];
        }
      }
      return best.forecast;
    };

    const features: WindStreamlineResult['features'] = [];
    const stepSize = 0.12; // degrees per step
    const numSteps = 10;

    for (const seed of selectedSeeds) {
      const coords: [number, number][] = [[seed.lng, seed.lat]];
      let totalSpeed = 0;
      let currentLat = seed.lat;
      let currentLng = seed.lng;

      for (let step = 0; step < numSteps; step++) {
        // Get wind at current position using nearest pre-fetched forecast
        const forecast = getNearestForecast(currentLat, currentLng);

        const wind = this.getWindAtAltitude(forecast, altitudeFt);
        if (wind.speed < 1) break; // calm — stop tracing

        totalSpeed += wind.speed;

        // Convert wind direction (FROM) to movement direction (TO)
        const moveDir = (wind.direction + 180) % 360;
        const moveRad = (moveDir * Math.PI) / 180;

        // Advance position
        const dLat = stepSize * Math.cos(moveRad);
        const dLng =
          (stepSize * Math.sin(moveRad)) /
          Math.cos((currentLat * Math.PI) / 180);

        currentLat += dLat;
        currentLng += dLng;

        // Stop if we've gone out of bounds
        if (
          currentLat < bounds.minLat - 1 ||
          currentLat > bounds.maxLat + 1 ||
          currentLng < bounds.minLng - 1 ||
          currentLng > bounds.maxLng + 1
        ) {
          break;
        }

        coords.push([currentLng, currentLat]);
      }

      if (coords.length >= 2) {
        const avgSpeed = totalSpeed / (coords.length - 1);
        const color = this.windSpeedColor(avgSpeed);
        let speedCategory = 'light';
        if (avgSpeed >= 50) speedCategory = 'strong';
        else if (avgSpeed >= 30) speedCategory = 'moderate-strong';
        else if (avgSpeed >= 15) speedCategory = 'moderate';

        features.push({
          type: 'Feature',
          geometry: {
            type: 'LineString',
            coordinates: coords,
          },
          properties: {
            avgSpeed: Math.round(avgSpeed),
            color,
            speedCategory,
          },
        });
      }
    }

    const result: WindStreamlineResult = {
      altitudeFt,
      type: 'FeatureCollection',
      features,
    };

    this.setCache(cacheKey, result, WINDS.CACHE_TTL_GRID_MS);
    return result;
  }

  /**
   * Color code wind speed for map visualization.
   */
  private windSpeedColor(speedKt: number): string {
    if (speedKt < 15) return '#4CAF50'; // green
    if (speedKt < 30) return '#FFC107'; // yellow
    if (speedKt < 50) return '#FF9800'; // orange
    return '#F44336'; // red
  }

  /**
   * ISA standard temperature at a given altitude (Celsius).
   * Below 36,089 ft: 15 - 1.98 * (altFt / 1000)
   * At/above 36,089 ft: -56.5 (tropopause)
   */
  private isaTemperature(altFt: number): number {
    if (altFt >= 36089) return -56.5;
    return 15 - 1.98 * (altFt / 1000);
  }

  // --- Cache helpers ---

  getStats() {
    return {
      name: 'Wind Data',
      baseUrl: WINDS.API_BASE_URL,
      cacheEntries: this.cache.size,
      totalRequests: this._totalRequests,
      totalErrors: this._totalErrors,
      lastFetchAt: this._lastFetchAt || null,
      lastErrorAt: this._lastErrorAt || null,
      lastError: this._lastError || null,
    };
  }

  private getFromCache(key: string): any {
    const entry = this.cache.get(key);
    if (entry && entry.expiresAt > Date.now()) return entry.data;
    if (entry) this.cache.delete(key);
    return null;
  }

  private setCache(key: string, data: any, ttlMs: number): void {
    this._lastFetchAt = Date.now();
    this.cache.set(key, { data, expiresAt: Date.now() + ttlMs });
  }
}
