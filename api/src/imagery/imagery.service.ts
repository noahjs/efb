import { Injectable, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';

@Injectable()
export class ImageryService {
  private readonly logger = new Logger(ImageryService.name);
  private readonly AWC_BASE = 'https://aviationweather.gov';

  // Simple in-memory cache: key -> { data, expiresAt }
  private cache = new Map<string, { data: any; expiresAt: number }>();
  private readonly GFA_CACHE_TTL_MS = 30 * 60 * 1000; // 30 minutes
  private readonly ADVISORY_CACHE_TTL_MS = 10 * 60 * 1000; // 10 minutes

  constructor(private readonly http: HttpService) {}

  getCatalog() {
    return {
      sections: [
        {
          id: 'gfa',
          title: 'GRAPHICAL AVIATION FORECASTS',
          products: [
            {
              id: 'gfa-clouds-us',
              name: 'CONUS Cloud',
              type: 'gfa',
              params: { gfaType: 'clouds', region: 'us' },
              forecastHours: [3, 6, 9, 12, 15, 18],
            },
            {
              id: 'gfa-sfc-us',
              name: 'CONUS Surface',
              type: 'gfa',
              params: { gfaType: 'sfc', region: 'us' },
              forecastHours: [3, 6, 9, 12, 15, 18],
            },
            {
              id: 'gfa-clouds-ne',
              name: 'Northeast Cloud',
              type: 'gfa',
              params: { gfaType: 'clouds', region: 'ne' },
              forecastHours: [3, 6, 9, 12, 15, 18],
            },
            {
              id: 'gfa-sfc-ne',
              name: 'Northeast Surface',
              type: 'gfa',
              params: { gfaType: 'sfc', region: 'ne' },
              forecastHours: [3, 6, 9, 12, 15, 18],
            },
            {
              id: 'gfa-clouds-e',
              name: 'East Cloud',
              type: 'gfa',
              params: { gfaType: 'clouds', region: 'e' },
              forecastHours: [3, 6, 9, 12, 15, 18],
            },
            {
              id: 'gfa-sfc-e',
              name: 'East Surface',
              type: 'gfa',
              params: { gfaType: 'sfc', region: 'e' },
              forecastHours: [3, 6, 9, 12, 15, 18],
            },
            {
              id: 'gfa-clouds-se',
              name: 'Southeast Cloud',
              type: 'gfa',
              params: { gfaType: 'clouds', region: 'se' },
              forecastHours: [3, 6, 9, 12, 15, 18],
            },
            {
              id: 'gfa-sfc-se',
              name: 'Southeast Surface',
              type: 'gfa',
              params: { gfaType: 'sfc', region: 'se' },
              forecastHours: [3, 6, 9, 12, 15, 18],
            },
            {
              id: 'gfa-clouds-nc',
              name: 'North Central Cloud',
              type: 'gfa',
              params: { gfaType: 'clouds', region: 'nc' },
              forecastHours: [3, 6, 9, 12, 15, 18],
            },
            {
              id: 'gfa-sfc-nc',
              name: 'North Central Surface',
              type: 'gfa',
              params: { gfaType: 'sfc', region: 'nc' },
              forecastHours: [3, 6, 9, 12, 15, 18],
            },
            {
              id: 'gfa-clouds-c',
              name: 'Central Cloud',
              type: 'gfa',
              params: { gfaType: 'clouds', region: 'c' },
              forecastHours: [3, 6, 9, 12, 15, 18],
            },
            {
              id: 'gfa-sfc-c',
              name: 'Central Surface',
              type: 'gfa',
              params: { gfaType: 'sfc', region: 'c' },
              forecastHours: [3, 6, 9, 12, 15, 18],
            },
            {
              id: 'gfa-clouds-sc',
              name: 'South Central Cloud',
              type: 'gfa',
              params: { gfaType: 'clouds', region: 'sc' },
              forecastHours: [3, 6, 9, 12, 15, 18],
            },
            {
              id: 'gfa-sfc-sc',
              name: 'South Central Surface',
              type: 'gfa',
              params: { gfaType: 'sfc', region: 'sc' },
              forecastHours: [3, 6, 9, 12, 15, 18],
            },
            {
              id: 'gfa-clouds-nw',
              name: 'Northwest Cloud',
              type: 'gfa',
              params: { gfaType: 'clouds', region: 'nw' },
              forecastHours: [3, 6, 9, 12, 15, 18],
            },
            {
              id: 'gfa-sfc-nw',
              name: 'Northwest Surface',
              type: 'gfa',
              params: { gfaType: 'sfc', region: 'nw' },
              forecastHours: [3, 6, 9, 12, 15, 18],
            },
            {
              id: 'gfa-clouds-w',
              name: 'West Cloud',
              type: 'gfa',
              params: { gfaType: 'clouds', region: 'w' },
              forecastHours: [3, 6, 9, 12, 15, 18],
            },
            {
              id: 'gfa-sfc-w',
              name: 'West Surface',
              type: 'gfa',
              params: { gfaType: 'sfc', region: 'w' },
              forecastHours: [3, 6, 9, 12, 15, 18],
            },
            {
              id: 'gfa-clouds-sw',
              name: 'Southwest Cloud',
              type: 'gfa',
              params: { gfaType: 'clouds', region: 'sw' },
              forecastHours: [3, 6, 9, 12, 15, 18],
            },
            {
              id: 'gfa-sfc-sw',
              name: 'Southwest Surface',
              type: 'gfa',
              params: { gfaType: 'sfc', region: 'sw' },
              forecastHours: [3, 6, 9, 12, 15, 18],
            },
          ],
        },
        {
          id: 'advisories',
          title: 'ADVISORIES',
          products: [
            { id: 'gairmets', name: 'Graphical AIRMETs', type: 'geojson' },
            { id: 'sigmets', name: 'SIGMETs', type: 'geojson' },
            {
              id: 'cwas',
              name: 'Center Weather Advisories',
              type: 'geojson',
            },
          ],
        },
        {
          id: 'prog',
          title: 'PROGNOSTIC CHARTS',
          products: [
            {
              id: 'prog-sfc',
              name: 'Surface Analysis',
              type: 'prog',
              params: { progType: 'sfc' },
              forecastHours: [0],
            },
            {
              id: 'prog-low',
              name: 'Low-Level Prog',
              type: 'prog',
              params: { progType: 'low' },
              forecastHours: [6, 12, 18, 24, 30, 36, 48, 60],
            },
          ],
        },
        {
          id: 'pireps',
          title: 'PILOT WEATHER REPORTS',
          products: [
            { id: 'pireps', name: 'PIREPs', type: 'geojson' },
          ],
        },
      ],
    };
  }

  async getGfaImage(
    type: string,
    region: string,
    forecastHour: number,
  ): Promise<Buffer | null> {
    const paddedHour = String(forecastHour).padStart(2, '0');
    const cacheKey = `gfa:${type}:${region}:${paddedHour}`;
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    const url = `${this.AWC_BASE}/data/products/gfa/F${paddedHour}_gfa_${type}_${region}.png`;

    try {
      const { data } = await firstValueFrom(
        this.http.get(url, {
          responseType: 'arraybuffer',
        }),
      );

      const buffer = Buffer.from(data);
      this.setCache(cacheKey, buffer, this.GFA_CACHE_TTL_MS);
      return buffer;
    } catch (error) {
      this.logger.error(
        `Failed to fetch GFA image: ${type}/${region}/F${paddedHour}`,
        error,
      );
      return null;
    }
  }

  async getProgChart(
    type: string,
    forecastHour: number,
  ): Promise<Buffer | null> {
    const paddedHour = String(forecastHour).padStart(3, '0');
    const cacheKey = `prog:${type}:${paddedHour}`;
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    const filename =
      type === 'sfc'
        ? 'F000_wpc_sfc.gif'
        : `F${paddedHour}_wpc_prog.gif`;
    const url = `${this.AWC_BASE}/data/products/progs/${filename}`;

    try {
      const { data } = await firstValueFrom(
        this.http.get(url, {
          responseType: 'arraybuffer',
        }),
      );

      const buffer = Buffer.from(data);
      this.setCache(cacheKey, buffer, this.GFA_CACHE_TTL_MS);
      return buffer;
    } catch (error) {
      this.logger.error(
        `Failed to fetch prog chart: ${type}/F${paddedHour}`,
        error,
      );
      return null;
    }
  }

  async getAdvisories(type: string): Promise<any> {
    const cacheKey = `advisory:${type}`;
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    // Map our types to AWC endpoints
    const endpointMap: Record<string, string> = {
      gairmets: 'gairmet',
      sigmets: 'airsigmet',
      cwas: 'cwa',
    };

    const endpoint = endpointMap[type];
    if (!endpoint) {
      return { error: `Unknown advisory type: ${type}` };
    }

    try {
      const { data } = await firstValueFrom(
        this.http.get(`${this.AWC_BASE}/api/data/${endpoint}`, {
          params: { format: 'geojson' },
        }),
      );

      this.setCache(cacheKey, data, this.ADVISORY_CACHE_TTL_MS);
      return data;
    } catch (error) {
      this.logger.error(`Failed to fetch advisories: ${type}`, error);
      return { type: 'FeatureCollection', features: [] };
    }
  }

  async getPireps(bbox?: string, age?: number): Promise<any> {
    const effectiveBbox = bbox ?? '20,-130,55,-60';
    const effectiveAge = age ?? 2;
    const cacheKey = `pireps:${effectiveBbox}:${effectiveAge}`;
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    try {
      const { data } = await firstValueFrom(
        this.http.get(`${this.AWC_BASE}/api/data/pirep`, {
          params: {
            format: 'geojson',
            bbox: effectiveBbox,
            age: effectiveAge,
          },
        }),
      );

      this.setCache(cacheKey, data, this.ADVISORY_CACHE_TTL_MS);
      return data;
    } catch (error) {
      this.logger.error('Failed to fetch PIREPs', error);
      return { type: 'FeatureCollection', features: [] };
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

  private setCache(key: string, data: any, ttlMs: number): void {
    this.cache.set(key, {
      data,
      expiresAt: Date.now() + ttlMs,
    });
  }
}
