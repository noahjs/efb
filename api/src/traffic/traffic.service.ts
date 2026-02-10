import { Injectable, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';
import { TRAFFIC } from '../config/constants';

export interface TrafficResponse {
  targets: any[];
  count: number;
  source: string;
  cachedAt: number;
}

@Injectable()
export class TrafficService {
  private readonly logger = new Logger(TrafficService.name);

  // In-memory cache: key -> { data, expiresAt }
  private cache = new Map<string, { data: TrafficResponse; expiresAt: number }>();

  constructor(private readonly http: HttpService) {}

  async getTrafficNearby(
    lat: number,
    lon: number,
    radiusNm: number,
  ): Promise<TrafficResponse> {
    // Round to 2 decimals for cache key
    const keyLat = lat.toFixed(2);
    const keyLon = lon.toFixed(2);
    const keyRadius = Math.round(radiusNm);
    const cacheKey = `${keyLat}:${keyLon}:${keyRadius}`;

    const cached = this.cache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) {
      return cached.data;
    }
    this.cache.delete(cacheKey);

    try {
      const url = `${TRAFFIC.AIRPLANES_LIVE_BASE_URL}/point/${lat}/${lon}/${radiusNm}`;
      const { data } = await firstValueFrom(
        this.http.get(url, { timeout: TRAFFIC.TIMEOUT_MS }),
      );

      const aircraft = Array.isArray(data?.ac) ? data.ac : [];
      const now = Date.now();

      const targets = aircraft
        .filter((ac: any) => {
          // Filter out ground vehicles (emitter categories C1/C2 = 17/18)
          const cat = ac.category;
          if (cat === 'C1' || cat === 'C2') return false;
          // Must have a position
          if (ac.lat == null || ac.lon == null) return false;
          return true;
        })
        .map((ac: any) => {
          const seen = ac.seen ?? 0;
          return {
            icaoHex: ac.hex ?? '',
            callsign: (ac.flight ?? '').trim(),
            latitude: ac.lat,
            longitude: ac.lon,
            altitude: ac.alt_baro === 'ground' ? 0 : (ac.alt_baro ?? 0),
            groundspeed: Math.round(ac.gs ?? 0),
            track: Math.round(ac.track ?? 0),
            verticalRate: Math.round(ac.baro_rate ?? 0),
            emitterCategory: ac.category ?? '',
            isAirborne: ac.alt_baro !== 'ground',
            positionAgeSeconds: seen,
            lastSeen: now - seen * 1000,
          };
        });

      const result: TrafficResponse = {
        targets,
        count: targets.length,
        source: 'airplanes_live',
        cachedAt: now,
      };

      this.cache.set(cacheKey, {
        data: result,
        expiresAt: now + TRAFFIC.CACHE_TTL_MS,
      });

      return result;
    } catch (error) {
      this.logger.error(
        `Failed to fetch traffic near ${lat},${lon} r=${radiusNm}`,
        error,
      );
      return { targets: [], count: 0, source: 'airplanes_live', cachedAt: Date.now() };
    }
  }
}
