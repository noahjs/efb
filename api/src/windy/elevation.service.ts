import { Injectable, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';
import { ELEVATION } from '../config/constants';
import { WindyService } from './windy.service';

export interface RouteProfilePoint {
  lat: number;
  lng: number;
  distanceNm: number;
  elevationFt: number;
  headwindComponent: number;
  crosswindComponent: number;
  windDirection: number;
  windSpeed: number;
  groundspeed: number;
}

export interface WaypointMarker {
  identifier: string;
  distanceNm: number;
}

export interface WindLayerSegment {
  distanceNm: number;
  headwindComponent: number;
  windDirection: number;
  windSpeed: number;
}

export interface WindLayer {
  altitudeFt: number;
  segments: WindLayerSegment[];
}

export interface RouteProfileResult {
  points: RouteProfilePoint[];
  cruiseAltitudeFt: number;
  totalDistanceNm: number;
  maxTerrainFt: number;
  departureElevationFt: number;
  destinationElevationFt: number;
  waypointMarkers: WaypointMarker[];
  windLayers: WindLayer[];
}

@Injectable()
export class ElevationService {
  private readonly logger = new Logger(ElevationService.name);
  private cache = new Map<string, { data: number; expiresAt: number }>();

  // API status tracking
  private _totalRequests = 0;
  private _totalErrors = 0;
  private _lastFetchAt = 0;
  private _lastErrorAt = 0;
  private _lastError = '';

  constructor(
    private readonly http: HttpService,
    private readonly windyService: WindyService,
  ) {}

  /**
   * Fetch elevations for an array of lat/lng points from Open-Meteo.
   * Batches in chunks of MAX_POINTS_PER_REQUEST with delay between batches.
   * Converts meters to feet. Results are cached for 24 hours.
   */
  async getElevations(
    points: Array<{ lat: number; lng: number }>,
  ): Promise<number[]> {
    if (points.length === 0) return [];

    const results: number[] = new Array(points.length).fill(0);

    // Check cache first, collect uncached
    const uncached: Array<{ globalIdx: number; lat: number; lng: number }> = [];

    for (let i = 0; i < points.length; i++) {
      const p = points[i];
      const cacheKey = `elev:${p.lat.toFixed(3)}:${p.lng.toFixed(3)}`;
      const cached = this.getFromCache(cacheKey);
      if (cached !== null) {
        results[i] = cached;
      } else {
        uncached.push({ globalIdx: i, lat: p.lat, lng: p.lng });
      }
    }

    if (uncached.length === 0) return results;

    // Batch uncached points, with delay between batches to avoid 429
    const chunkSize = ELEVATION.MAX_POINTS_PER_REQUEST;
    for (let start = 0; start < uncached.length; start += chunkSize) {
      // Delay between batches (not before the first one)
      if (start > 0) {
        await new Promise((r) => setTimeout(r, ELEVATION.REQUEST_DELAY_MS));
      }

      const chunk = uncached.slice(start, start + chunkSize);

      try {
        this._totalRequests++;
        this._lastFetchAt = Date.now();

        const { data } = await firstValueFrom(
          this.http.get(ELEVATION.API_URL, {
            params: {
              latitude: chunk.map((p) => p.lat.toFixed(4)).join(','),
              longitude: chunk.map((p) => p.lng.toFixed(4)).join(','),
            },
            timeout: 15000,
          }),
        );

        const elevations: number[] = data.elevation || [];

        for (let j = 0; j < chunk.length; j++) {
          const entry = chunk[j];
          const elevM = elevations[j] ?? 0;
          const elevFt = Math.round(elevM * 3.28084);
          results[entry.globalIdx] = elevFt;

          const cacheKey = `elev:${entry.lat.toFixed(3)}:${entry.lng.toFixed(3)}`;
          this.setCache(cacheKey, elevFt, ELEVATION.CACHE_TTL_MS);
        }
      } catch (error) {
        this._totalErrors++;
        this._lastErrorAt = Date.now();
        this._lastError = error?.message || String(error);
        this.logger.error(
          `Elevation API error for ${chunk.length} points: ${error.message}`,
        );

        // On 429, wait longer and retry once
        if (error?.response?.status === 429) {
          this.logger.warn('Rate limited — retrying after 2s delay');
          await new Promise((r) => setTimeout(r, 2000));
          try {
            const { data } = await firstValueFrom(
              this.http.get(ELEVATION.API_URL, {
                params: {
                  latitude: chunk.map((p) => p.lat.toFixed(4)).join(','),
                  longitude: chunk.map((p) => p.lng.toFixed(4)).join(','),
                },
                timeout: 15000,
              }),
            );
            const elevations: number[] = data.elevation || [];
            for (let j = 0; j < chunk.length; j++) {
              const entry = chunk[j];
              const elevM = elevations[j] ?? 0;
              const elevFt = Math.round(elevM * 3.28084);
              results[entry.globalIdx] = elevFt;

              const cacheKey = `elev:${entry.lat.toFixed(3)}:${entry.lng.toFixed(3)}`;
              this.setCache(cacheKey, elevFt, ELEVATION.CACHE_TTL_MS);
            }
          } catch (retryErr) {
            this.logger.error(`Elevation retry also failed: ${retryErr.message}`);
          }
        }
      }
    }

    return results;
  }

  /**
   * Build a full route profile: terrain elevation + wind data at each sample point.
   */
  async getRouteProfile(
    waypoints: Array<{ lat: number; lng: number }>,
    altitudeFt: number,
    tas: number,
    waypointIdentifiers?: string[],
  ): Promise<RouteProfileResult> {
    if (waypoints.length < 2) {
      return {
        points: [],
        cruiseAltitudeFt: altitudeFt,
        totalDistanceNm: 0,
        maxTerrainFt: 0,
        departureElevationFt: 0,
        destinationElevationFt: 0,
        waypointMarkers: [],
        windLayers: [],
      };
    }

    // Sample the route at fine intervals for smooth terrain
    const samplePoints = this.sampleRouteDetailed(
      waypoints,
      ELEVATION.SAMPLE_INTERVAL_NM,
    );

    // Fetch elevation and wind data in parallel
    const [elevations, forecasts] = await Promise.all([
      this.getElevations(samplePoints),
      this.windyService.getBatchForecasts(samplePoints),
    ]);

    // Compute cumulative distance and wind components
    const points: RouteProfilePoint[] = [];
    let cumulativeDistance = 0;

    for (let i = 0; i < samplePoints.length; i++) {
      const p = samplePoints[i];

      if (i > 0) {
        cumulativeDistance += this.windyService.distanceNm(
          samplePoints[i - 1].lat,
          samplePoints[i - 1].lng,
          p.lat,
          p.lng,
        );
      }

      const wind = this.windyService.getWindAtAltitude(
        forecasts[i],
        altitudeFt,
      );

      // Course to next point (or from previous if last)
      let course = 0;
      if (i < samplePoints.length - 1) {
        course = this.windyService.bearing(
          p.lat,
          p.lng,
          samplePoints[i + 1].lat,
          samplePoints[i + 1].lng,
        );
      } else if (i > 0) {
        course = this.windyService.bearing(
          samplePoints[i - 1].lat,
          samplePoints[i - 1].lng,
          p.lat,
          p.lng,
        );
      }

      const windAngle =
        ((wind.direction - course + 360) % 360) * (Math.PI / 180);
      const headwindComponent = Math.round(wind.speed * Math.cos(windAngle));
      const crosswindComponent = Math.round(wind.speed * Math.sin(windAngle));
      const gs = this.windyService.computeGroundspeed(
        tas,
        course,
        wind.direction,
        wind.speed,
      );

      points.push({
        lat: p.lat,
        lng: p.lng,
        distanceNm: Math.round(cumulativeDistance * 10) / 10,
        elevationFt: elevations[i],
        headwindComponent,
        crosswindComponent,
        windDirection: wind.direction,
        windSpeed: wind.speed,
        groundspeed: Math.round(gs),
      });
    }

    const totalDistanceNm =
      points.length > 0 ? points[points.length - 1].distanceNm : 0;
    const maxTerrainFt = Math.max(...elevations, 0);

    // Map waypoint identifiers to distance positions along the route
    const waypointMarkers: WaypointMarker[] = [];
    if (waypointIdentifiers && waypointIdentifiers.length > 0) {
      let wpDistance = 0;
      for (let w = 0; w < waypoints.length; w++) {
        if (w > 0) {
          wpDistance += this.windyService.distanceNm(
            waypoints[w - 1].lat,
            waypoints[w - 1].lng,
            waypoints[w].lat,
            waypoints[w].lng,
          );
        }
        const identifier =
          w < waypointIdentifiers.length
            ? waypointIdentifiers[w]
            : `WP${w + 1}`;
        waypointMarkers.push({
          identifier,
          distanceNm: Math.round(wpDistance * 10) / 10,
        });
      }
    }

    // --- Build wind layers at multiple altitudes ---
    const altCeiling = Math.max(altitudeFt + 3000, maxTerrainFt + 3000);
    const windLayerAltitudes: number[] = [];
    for (let a = 3000; a <= altCeiling; a += 3000) {
      windLayerAltitudes.push(a);
    }

    // Sample fewer distance positions for wind grid (~5-8 pills per row)
    const windSampleStep = Math.max(15, totalDistanceNm / 8);
    const windPositions: number[] = [];
    for (
      let d = windSampleStep;
      d < totalDistanceNm - windSampleStep / 2;
      d += windSampleStep
    ) {
      windPositions.push(d);
    }

    // Precompute course at each profile point
    const courses: number[] = [];
    for (let i = 0; i < samplePoints.length; i++) {
      if (i < samplePoints.length - 1) {
        courses.push(
          this.windyService.bearing(
            samplePoints[i].lat,
            samplePoints[i].lng,
            samplePoints[i + 1].lat,
            samplePoints[i + 1].lng,
          ),
        );
      } else if (i > 0) {
        courses.push(courses[i - 1]);
      } else {
        courses.push(0);
      }
    }

    const windLayers: WindLayer[] = windLayerAltitudes.map((layerAlt) => {
      const segments: WindLayerSegment[] = windPositions.map((targetDist) => {
        // Find nearest profile sample point
        let nearestIdx = 0;
        let bestDiff = Infinity;
        for (let i = 0; i < points.length; i++) {
          const diff = Math.abs(points[i].distanceNm - targetDist);
          if (diff < bestDiff) {
            bestDiff = diff;
            nearestIdx = i;
          }
        }

        const wind = this.windyService.getWindAtAltitude(
          forecasts[nearestIdx],
          layerAlt,
        );
        const course = courses[nearestIdx];
        const windAngle =
          ((wind.direction - course + 360) % 360) * (Math.PI / 180);
        const headwindComponent = Math.round(
          wind.speed * Math.cos(windAngle),
        );

        return {
          distanceNm: Math.round(targetDist * 10) / 10,
          headwindComponent,
          windDirection: wind.direction,
          windSpeed: wind.speed,
        };
      });

      return { altitudeFt: layerAlt, segments };
    });

    return {
      points,
      cruiseAltitudeFt: altitudeFt,
      totalDistanceNm: Math.round(totalDistanceNm),
      maxTerrainFt,
      departureElevationFt: elevations[0] ?? 0,
      destinationElevationFt: elevations[elevations.length - 1] ?? 0,
      waypointMarkers,
      windLayers,
    };
  }

  /**
   * Sample points along a route at fine intervals, interpolating between waypoints.
   */
  private sampleRouteDetailed(
    waypoints: Array<{ lat: number; lng: number }>,
    intervalNm: number,
  ): Array<{ lat: number; lng: number }> {
    const result: Array<{ lat: number; lng: number }> = [];

    for (let i = 0; i < waypoints.length - 1; i++) {
      const from = waypoints[i];
      const to = waypoints[i + 1];
      const legDist = this.windyService.distanceNm(
        from.lat,
        from.lng,
        to.lat,
        to.lng,
      );

      const numSamples = Math.max(1, Math.ceil(legDist / intervalNm));

      for (let s = 0; s < numSamples; s++) {
        const fraction = s / numSamples;
        result.push({
          lat: from.lat + (to.lat - from.lat) * fraction,
          lng: from.lng + (to.lng - from.lng) * fraction,
        });
      }
    }

    // Always include the last waypoint
    result.push(waypoints[waypoints.length - 1]);

    return result;
  }

  // --- Stats ---

  getStats() {
    return {
      name: 'Elevation',
      baseUrl: ELEVATION.API_URL,
      cacheEntries: this.cache.size,
      totalRequests: this._totalRequests,
      totalErrors: this._totalErrors,
      lastFetchAt: this._lastFetchAt || null,
      lastErrorAt: this._lastErrorAt || null,
      lastError: this._lastError || null,
    };
  }

  // --- Cache helpers ---

  private getFromCache(key: string): number | null {
    const entry = this.cache.get(key);
    if (entry && entry.expiresAt > Date.now()) return entry.data;
    if (entry) this.cache.delete(key);
    return null;
  }

  private setCache(key: string, data: number, ttlMs: number): void {
    this.cache.set(key, { data, expiresAt: Date.now() + ttlMs });
  }
}
