import { Injectable, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Between } from 'typeorm';
import { firstValueFrom } from 'rxjs';
import { IMAGERY } from '../config/constants';
import { Advisory } from '../data-platform/entities/advisory.entity';
import { Pirep } from '../data-platform/entities/pirep.entity';
import { Tfr } from '../data-platform/entities/tfr.entity';

function dataMeta(
  updatedAt: Date | null,
): { updatedAt: string | null; ageSeconds: number | null } {
  if (!updatedAt) return { updatedAt: null, ageSeconds: null };
  return {
    updatedAt: updatedAt.toISOString(),
    ageSeconds: Math.round((Date.now() - updatedAt.getTime()) / 1000),
  };
}

@Injectable()
export class ImageryService {
  private readonly logger = new Logger(ImageryService.name);

  // In-memory cache for image proxying only (GFA, prog charts, icing, etc.)
  private cache = new Map<string, { data: any; expiresAt: number }>();

  // API status tracking
  private _totalRequests = 0;
  private _totalErrors = 0;
  private _lastFetchAt = 0;
  private _lastErrorAt = 0;
  private _lastError = '';

  constructor(
    private readonly http: HttpService,
    @InjectRepository(Advisory)
    private readonly advisoryRepo: Repository<Advisory>,
    @InjectRepository(Pirep)
    private readonly pirepRepo: Repository<Pirep>,
    @InjectRepository(Tfr)
    private readonly tfrRepo: Repository<Tfr>,
  ) {}

  getCatalog() {
    return {
      sections: [
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
          id: 'icing',
          title: 'ICING',
          products: [
            {
              id: 'icing-prob',
              name: 'Icing Probability',
              type: 'icing',
              params: { icingParam: 'prob' },
              forecastHours: [0, 3, 6, 9, 12, 15, 18],
            },
            {
              id: 'icing-sev',
              name: 'Icing Severity',
              type: 'icing',
              params: { icingParam: 'sev' },
              forecastHours: [0, 3, 6, 9, 12, 15, 18],
            },
          ],
        },
        {
          id: 'winds',
          title: 'WINDS ALOFT',
          products: [
            {
              id: 'winds-aloft',
              name: 'Winds & Temperatures Aloft',
              type: 'winds',
            },
          ],
        },
        {
          id: 'convective',
          title: 'CONVECTIVE OUTLOOKS',
          products: [
            {
              id: 'convective-outlook',
              name: 'Convective Outlook',
              type: 'convective',
            },
          ],
        },
        {
          id: 'tfrs',
          title: 'TFRs',
          products: [
            {
              id: 'tfrs',
              name: 'Temporary Flight Restrictions',
              type: 'tfr',
            },
          ],
        },
        {
          id: 'pireps',
          title: 'PILOT WEATHER REPORTS',
          products: [{ id: 'pireps', name: 'PIREPs', type: 'geojson' }],
        },
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
      ],
    };
  }

  // --- Image proxy methods (kept as-is with in-memory cache) ---

  async getGfaImage(
    type: string,
    region: string,
    forecastHour: number,
  ): Promise<Buffer | null> {
    const paddedHour = String(forecastHour).padStart(2, '0');
    const cacheKey = `gfa:${type}:${region}:${paddedHour}`;
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    const url = `${IMAGERY.AWC_BASE_URL}/data/products/gfa/F${paddedHour}_gfa_${type}_${region}.png`;

    try {
      this._totalRequests++;
      const { data } = await firstValueFrom(
        this.http.get(url, { responseType: 'arraybuffer' }),
      );

      const buffer = Buffer.from(data);
      this.setCache(cacheKey, buffer, IMAGERY.CACHE_TTL_GFA_MS);
      return buffer;
    } catch (error) {
      this._totalErrors++;
      this._lastErrorAt = Date.now();
      this._lastError = error?.message || String(error);
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
      type === 'sfc' ? 'F000_wpc_sfc.gif' : `F${paddedHour}_wpc_prog.gif`;
    const url = `${IMAGERY.AWC_BASE_URL}/data/products/progs/${filename}`;

    try {
      this._totalRequests++;
      const { data } = await firstValueFrom(
        this.http.get(url, { responseType: 'arraybuffer' }),
      );

      const buffer = Buffer.from(data);
      this.setCache(cacheKey, buffer, IMAGERY.CACHE_TTL_GFA_MS);
      return buffer;
    } catch (error) {
      this._totalErrors++;
      this._lastErrorAt = Date.now();
      this._lastError = error?.message || String(error);
      this.logger.error(
        `Failed to fetch prog chart: ${type}/F${paddedHour}`,
        error,
      );
      return null;
    }
  }

  async getIcingChart(
    param: string,
    level: string,
    forecastHour: number,
  ): Promise<Buffer | null> {
    const paddedHour = String(forecastHour).padStart(2, '0');
    const cacheKey = `icing:${param}:${level}:${paddedHour}`;
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    const product = forecastHour === 0 ? 'cip' : 'fip';
    const filename = `F${paddedHour}_${product}_${level}_${param}.gif`;
    const url = `${IMAGERY.AWC_BASE_URL}/data/products/icing/${filename}`;

    try {
      this._totalRequests++;
      const { data } = await firstValueFrom(
        this.http.get(url, { responseType: 'arraybuffer' }),
      );

      const buffer = Buffer.from(data);
      this.setCache(cacheKey, buffer, IMAGERY.CACHE_TTL_GFA_MS);
      return buffer;
    } catch (error) {
      this._totalErrors++;
      this._lastErrorAt = Date.now();
      this._lastError = error?.message || String(error);
      this.logger.error(
        `Failed to fetch icing chart: ${param}/${level}/F${paddedHour}`,
        error,
      );
      return null;
    }
  }

  async getWindsAloftChart(
    level: string,
    area: string,
    forecastHour: number,
  ): Promise<Buffer | null> {
    const paddedHour = String(forecastHour).padStart(2, '0');
    const cacheKey = `winds:${level}:${area}:${paddedHour}`;
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    const url = `${IMAGERY.AWC_BASE_URL}/data/products/fax/F${paddedHour}_wind_${level}_${area}.gif`;

    try {
      this._totalRequests++;
      const { data } = await firstValueFrom(
        this.http.get(url, { responseType: 'arraybuffer' }),
      );

      const buffer = Buffer.from(data);
      this.setCache(cacheKey, buffer, IMAGERY.CACHE_TTL_WINDS_MS);
      return buffer;
    } catch (error) {
      this._totalErrors++;
      this._lastErrorAt = Date.now();
      this._lastError = error?.message || String(error);
      this.logger.error(
        `Failed to fetch winds aloft chart: ${level}/${area}/F${paddedHour}`,
        error,
      );
      return null;
    }
  }

  async getConvectiveOutlook(
    day: number,
    type: string,
  ): Promise<Buffer | null> {
    const cacheKey = `convective:${day}:${type}`;
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    let filename: string;
    if (type === 'cat') {
      filename = `day${day}otlk.gif`;
    } else {
      const issuance = day === 1 ? '1200' : '0600';
      filename = `day${day}probotlk_${issuance}_${type}.gif`;
    }

    const url = `${IMAGERY.SPC_BASE_URL}/products/outlook/${filename}`;

    try {
      this._totalRequests++;
      const { data } = await firstValueFrom(
        this.http.get(url, { responseType: 'arraybuffer' }),
      );

      const buffer = Buffer.from(data);
      this.setCache(cacheKey, buffer, IMAGERY.CACHE_TTL_GFA_MS);
      return buffer;
    } catch (error) {
      this._totalErrors++;
      this._lastErrorAt = Date.now();
      this._lastError = error?.message || String(error);
      this.logger.error(
        `Failed to fetch convective outlook: day${day}/${type}`,
        error,
      );
      return null;
    }
  }

  // --- Data methods (now read from DB) ---

  /**
   * Get advisories from database (populated by AdvisoryPoller).
   */
  async getAdvisories(type: string, forecastHour?: number): Promise<any> {
    const typeMap: Record<string, string> = {
      gairmets: 'gairmet',
      sigmets: 'sigmet',
      cwas: 'cwa',
    };

    const dbType = typeMap[type];
    if (!dbType) {
      return { error: `Unknown advisory type: ${type}` };
    }

    const rows = await this.advisoryRepo.find({
      where: { type: dbType },
    });

    const oldestUpdatedAt = rows.length
      ? rows.reduce(
          (oldest, r) =>
            r.updated_at < oldest ? r.updated_at : oldest,
          rows[0].updated_at,
        )
      : null;

    // Reconstruct GeoJSON FeatureCollection
    const features = rows.map((row) => ({
      type: 'Feature',
      geometry: row.geometry,
      properties: row.properties ?? {},
    }));

    return {
      type: 'FeatureCollection',
      features,
      _meta: dataMeta(oldestUpdatedAt),
    };
  }

  /**
   * Get PIREPs from database (populated by PirepPoller).
   */
  async getPireps(bbox?: string, age?: number): Promise<any> {
    let rows: Pirep[];

    if (bbox) {
      const [minLat, minLng, maxLat, maxLng] = bbox.split(',').map(Number);
      rows = await this.pirepRepo.find({
        where: {
          latitude: Between(minLat, maxLat),
          longitude: Between(minLng, maxLng),
        },
      });
    } else {
      rows = await this.pirepRepo.find();
    }

    // Filter by age (hours) if specified
    if (age) {
      const cutoff = new Date(Date.now() - age * 60 * 60 * 1000);
      rows = rows.filter((r) => r.obs_time && r.obs_time >= cutoff);
    }

    const oldestUpdatedAt = rows.length
      ? rows.reduce(
          (oldest, r) =>
            r.updated_at < oldest ? r.updated_at : oldest,
          rows[0].updated_at,
        )
      : null;

    // Reconstruct GeoJSON FeatureCollection
    const features = rows.map((row) => ({
      type: 'Feature',
      geometry: row.geometry ?? {
        type: 'Point',
        coordinates: [row.longitude, row.latitude],
      },
      properties: row.properties ?? {},
    }));

    return {
      type: 'FeatureCollection',
      features,
      _meta: dataMeta(oldestUpdatedAt),
    };
  }

  /**
   * Get TFRs from database (populated by TfrPoller).
   */
  async getTfrs(): Promise<any> {
    const rows = await this.tfrRepo.find();

    const oldestUpdatedAt = rows.length
      ? rows.reduce(
          (oldest, r) =>
            r.updated_at < oldest ? r.updated_at : oldest,
          rows[0].updated_at,
        )
      : null;

    const features = rows.map((row) => ({
      type: 'Feature',
      geometry: row.geometry,
      properties: {
        notamNumber: row.notam_id,
        type: row.type ?? '',
        status: 'active',
        description: row.description ?? '',
        state: row.state ?? '',
        facility: row.facility ?? '',
        color: '#FF5252',
        location: row.properties?.location ?? '',
        effectiveStart: row.effective_start ?? '',
        effectiveEnd: row.effective_end ?? '',
        altitude: row.altitude ?? '',
        reason: row.reason ?? '',
        notamText: row.notam_text ?? '',
      },
    }));

    return {
      type: 'FeatureCollection',
      features,
      _meta: dataMeta(oldestUpdatedAt),
    };
  }

  getStats() {
    return {
      name: 'Imagery',
      baseUrl: IMAGERY.AWC_BASE_URL,
      cacheEntries: this.cache.size,
      totalRequests: this._totalRequests,
      totalErrors: this._totalErrors,
      lastFetchAt: this._lastFetchAt || null,
      lastErrorAt: this._lastErrorAt || null,
      lastError: this._lastError || null,
    };
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
    this._lastFetchAt = Date.now();
    this.cache.set(key, {
      data,
      expiresAt: Date.now() + ttlMs,
    });
  }
}
