import { Injectable, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';

interface MetarResponse {
  raw: string;
  icao: string;
  flight_category: string;
  temperature: number | null;
  dewpoint: number | null;
  wind_direction: number | null;
  wind_speed: number | null;
  wind_gust: number | null;
  visibility: number | null;
  altimeter: number | null;
  clouds: Array<{ cover: string; base: number | null }>;
  observed: string;
}

@Injectable()
export class WeatherService {
  private readonly logger = new Logger(WeatherService.name);
  private readonly AWC_BASE = 'https://aviationweather.gov/api/data';

  // Simple in-memory cache: key -> { data, expiresAt }
  private cache = new Map<string, { data: any; expiresAt: number }>();
  private readonly CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

  constructor(private readonly http: HttpService) {}

  async getMetar(icao: string): Promise<any> {
    const cacheKey = `metar:${icao}`;
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    try {
      const { data } = await firstValueFrom(
        this.http.get(`${this.AWC_BASE}/metar`, {
          params: { ids: icao, format: 'json' },
        }),
      );

      const result = Array.isArray(data) && data.length > 0 ? data[0] : null;
      if (result) {
        this.setCache(cacheKey, result);
      }
      return result;
    } catch (error) {
      this.logger.error(`Failed to fetch METAR for ${icao}`, error);
      return null;
    }
  }

  async getTaf(icao: string): Promise<any> {
    const cacheKey = `taf:${icao}`;
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    try {
      const { data } = await firstValueFrom(
        this.http.get(`${this.AWC_BASE}/taf`, {
          params: { ids: icao, format: 'json' },
        }),
      );

      const result = Array.isArray(data) && data.length > 0 ? data[0] : null;
      if (result) {
        this.setCache(cacheKey, result);
      }
      return result;
    } catch (error) {
      this.logger.error(`Failed to fetch TAF for ${icao}`, error);
      return null;
    }
  }

  async getBulkMetars(bounds: {
    minLat: number;
    maxLat: number;
    minLng: number;
    maxLng: number;
  }): Promise<any[]> {
    const cacheKey = `metars:${bounds.minLat},${bounds.maxLat},${bounds.minLng},${bounds.maxLng}`;
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    try {
      // AWC allows bounding box queries using a special format
      const bbox = `${bounds.minLng},${bounds.minLat},${bounds.maxLng},${bounds.maxLat}`;
      const { data } = await firstValueFrom(
        this.http.get(`${this.AWC_BASE}/metar`, {
          params: { bbox, format: 'json' },
        }),
      );

      const result = Array.isArray(data) ? data : [];
      this.setCache(cacheKey, result);
      return result;
    } catch (error) {
      this.logger.error('Failed to fetch bulk METARs', error);
      return [];
    }
  }

  private getFromCache(key: string): any | null {
    const entry = this.cache.get(key);
    if (entry && entry.expiresAt > Date.now()) {
      return entry.data;
    }
    this.cache.delete(key);
    return null;
  }

  private setCache(key: string, data: any): void {
    this.cache.set(key, {
      data,
      expiresAt: Date.now() + this.CACHE_TTL_MS,
    });
  }
}
