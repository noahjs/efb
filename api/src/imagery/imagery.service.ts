import { Injectable, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';

@Injectable()
export class ImageryService {
  private readonly logger = new Logger(ImageryService.name);
  private readonly AWC_BASE = 'https://aviationweather.gov';
  private readonly TFR_BASE = 'https://tfr.faa.gov';

  // Simple in-memory cache: key -> { data, expiresAt }
  private cache = new Map<string, { data: any; expiresAt: number }>();
  private readonly GFA_CACHE_TTL_MS = 30 * 60 * 1000; // 30 minutes
  private readonly ADVISORY_CACHE_TTL_MS = 10 * 60 * 1000; // 10 minutes
  private readonly TFR_CACHE_TTL_MS = 15 * 60 * 1000; // 15 minutes

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
    const url = `${this.AWC_BASE}/data/products/icing/${filename}`;

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
        `Failed to fetch icing chart: ${param}/${level}/F${paddedHour}`,
        error,
      );
      return null;
    }
  }

  async getAdvisories(type: string, forecastHour?: number): Promise<any> {
    const cacheKey =
      forecastHour != null
        ? `advisory:${type}:${forecastHour}`
        : `advisory:${type}`;
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

    const params: Record<string, any> = { format: 'geojson' };
    // G-AIRMETs support a forecast hour parameter (0, 3, 6, 9, 12)
    if (type === 'gairmets' && forecastHour != null) {
      params.fore = forecastHour;
    }

    try {
      const { data } = await firstValueFrom(
        this.http.get(`${this.AWC_BASE}/api/data/${endpoint}`, { params }),
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

  async getTfrs(): Promise<any> {
    const cacheKey = 'tfrs';
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    try {
      // Fetch GeoJSON polygons from FAA GeoServer WFS and metadata from TFR API in parallel
      const [wfsResponse, listResponse] = await Promise.all([
        firstValueFrom(
          this.http.get(
            `${this.TFR_BASE}/geoserver/TFR/ows`,
            {
              params: {
                service: 'WFS',
                version: '1.1.0',
                request: 'GetFeature',
                typeName: 'TFR:V_TFR_LOC',
                maxFeatures: 300,
                outputFormat: 'application/json',
                srsname: 'EPSG:4326',
              },
              timeout: 30000,
            },
          ),
        ),
        firstValueFrom(
          this.http.get(`${this.TFR_BASE}/tfrapi/getTfrList`, {
            timeout: 15000,
          }),
        ).catch(() => ({ data: [] })),
      ]);

      const wfsData = wfsResponse.data;
      const listData: any[] = Array.isArray(listResponse.data)
        ? listResponse.data
        : [];

      // Build lookup from NOTAM ID → list metadata
      const listMap = new Map<string, any>();
      for (const entry of listData) {
        if (entry.notam_id) {
          listMap.set(entry.notam_id, entry);
        }
      }

      // Collect unique NOTAM IDs from WFS features
      const wfsFeatures: any[] = wfsData.features ?? [];
      const notamIds = new Set<string>();
      for (const feature of wfsFeatures) {
        const notamKey = feature.properties?.NOTAM_KEY ?? '';
        const notamId = notamKey.split('-')[0];
        if (notamId) notamIds.add(notamId);
      }

      // Fetch full web text for all TFRs in parallel (batched, 10 at a time)
      const webTextMap = new Map<string, Record<string, string>>();
      const ids = Array.from(notamIds);
      const batchSize = 10;
      for (let i = 0; i < ids.length; i += batchSize) {
        const batch = ids.slice(i, i + batchSize);
        const results = await Promise.allSettled(
          batch.map((id) =>
            firstValueFrom(
              this.http.get(`${this.TFR_BASE}/tfrapi/getWebText`, {
                params: { notamId: id },
                timeout: 10000,
              }),
            ),
          ),
        );
        for (let j = 0; j < batch.length; j++) {
          const result = results[j];
          if (result.status === 'fulfilled' && Array.isArray(result.value.data)) {
            const html = result.value.data[0]?.text ?? '';
            webTextMap.set(batch[j], this.parseTfrWebText(html));
          }
        }
      }

      // Enrich WFS features with metadata, web text, and color
      const features = wfsFeatures.map((feature: any) => {
        const props = feature.properties ?? {};
        const notamKey = props.NOTAM_KEY ?? '';
        // NOTAM_KEY format: "6/1344-1-FDC-F" → notam_id is "6/1344"
        const notamId = notamKey.split('-')[0];
        const meta = listMap.get(notamId);
        const webText = webTextMap.get(notamId) ?? {};

        const title = props.TITLE ?? '';
        const description = meta?.description ?? title;
        const status = 'active'; // WFS only returns currently active TFRs
        const color = status === 'active' ? '#FF5252' : '#FFC107';

        return {
          type: 'Feature',
          geometry: feature.geometry,
          properties: {
            notamNumber: notamId,
            type: props.LEGAL ?? meta?.type ?? '',
            status,
            description,
            state: props.STATE ?? meta?.state ?? '',
            facility: props.CNS_LOCATION_ID ?? meta?.facility ?? '',
            color,
            // Fields from web text
            location: webText.location ?? '',
            effectiveStart: webText.effectiveStart ?? '',
            effectiveEnd: webText.effectiveEnd ?? '',
            altitude: webText.altitude ?? '',
            reason: webText.reason ?? '',
            notamText: webText.notamText ?? '',
          },
        };
      });

      const geojson = { type: 'FeatureCollection', features };
      this.setCache(cacheKey, geojson, this.TFR_CACHE_TTL_MS);
      return geojson;
    } catch (error) {
      this.logger.error('Failed to fetch TFRs', error);
      return { type: 'FeatureCollection', features: [] };
    }
  }

  /** Parse HTML from getWebText into structured fields. */
  private parseTfrWebText(html: string): Record<string, string> {
    const result: Record<string, string> = {};
    if (!html) return result;

    // Strip HTML tags
    const stripHtml = (s: string) =>
      s.replace(/<[^>]+>/g, '').replace(/&[a-z]+;/g, ' ').replace(/\s+/g, ' ').trim();

    // Extract table rows: <TR>...<TD>label</TD><TD>value</TD>...</TR>
    const rowRegex = /<TR[^>]*>([\s\S]*?)<\/TR>/gi;
    let match: RegExpExecArray | null;

    while ((match = rowRegex.exec(html)) !== null) {
      const row = match[1];
      const cells = [...row.matchAll(/<TD[^>]*>([\s\S]*?)<\/TD>/gi)].map((m) =>
        stripHtml(m[1]),
      );

      // Handle single-cell rows with "Label: Value" pattern (e.g. "Altitude: ...")
      if (cells.length === 1 || (cells.length >= 1 && cells.filter((c) => c).length === 1)) {
        const text = cells.find((c) => c) ?? '';
        const altMatch = text.match(/^Altitude:\s*(.+)/i);
        if (altMatch) {
          result.altitude = altMatch[1].trim();
          continue;
        }
      }

      if (cells.length < 2) continue;

      const label = cells.slice(0, -1).join(' ').replace(/\s+/g, ' ').trim().toLowerCase();
      const value = cells[cells.length - 1];

      if (label.includes('location') && !label.includes('latitude')) {
        result.location = value;
      } else if (label.includes('beginning date')) {
        result.effectiveStart = value;
      } else if (label.includes('ending date')) {
        result.effectiveEnd = value;
      } else if (label.includes('altitude')) {
        result.altitude = value;
      } else if (label.includes('reason')) {
        result.reason = value;
      }
    }

    // Extract the operational text — typically in the restrictions section
    // Look for the long NOTAM text block (starts with "No " or "EXC " or contains operational text)
    const textCells = [...html.matchAll(/<TD[^>]*>([\s\S]*?)<\/TD>/gi)]
      .map((m) => stripHtml(m[1]))
      .filter((t) => t.length > 200);
    if (textCells.length > 0) {
      result.notamText = textCells[0];
    }

    return result;
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
