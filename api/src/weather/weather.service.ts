import { Injectable, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';
import { AirportsService } from '../airports/airports.service';

interface WindsAloftAltitude {
  altitude: number;
  direction: number | null;
  speed: number | null;
  temperature: number | null;
  lightAndVariable: boolean;
}

interface WindsAloftForecast {
  period: string;
  label: string;
  altitudes: WindsAloftAltitude[];
}

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
  private readonly WINDS_CACHE_TTL_MS = 60 * 60 * 1000; // 60 minutes
  private readonly NOTAM_CACHE_TTL_MS = 30 * 60 * 1000; // 30 minutes
  private readonly GRID_CACHE_TTL_MS = 24 * 60 * 60 * 1000; // 24 hours

  private readonly NWS_BASE = 'https://api.weather.gov';
  private readonly NWS_HEADERS = {
    'User-Agent': '(EFB Flight App, contact@efb.app)',
    Accept: 'application/geo+json',
  };

  constructor(
    private readonly http: HttpService,
    private readonly airportsService: AirportsService,
  ) {}

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

  async getNearestTaf(icao: string): Promise<any> {
    const cacheKey = `nearest-taf:${icao}`;
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    // Try the station itself first
    const directTaf = await this.getTaf(icao);
    if (directTaf) {
      const result = {
        taf: directTaf,
        station: icao,
        isNearby: false,
        distanceNm: 0,
        requestedStation: icao,
      };
      this.setCache(cacheKey, result);
      return result;
    }

    // Look up airport coordinates to search nearby
    const airport = await this.airportsService.findById(icao);
    if (!airport || airport.latitude == null || airport.longitude == null) {
      const result = {
        taf: null,
        station: null,
        isNearby: false,
        distanceNm: null,
        requestedStation: icao,
      };
      this.setCache(cacheKey, result);
      return result;
    }

    // Search nearby airports for one with a TAF
    const nearby = await this.airportsService.findNearby(
      airport.latitude,
      airport.longitude,
      50,
      20,
    );

    for (const candidate of nearby) {
      const candidateIcao = candidate.icao_identifier;
      if (!candidateIcao || candidateIcao === icao) continue;

      const taf = await this.getTaf(candidateIcao);
      if (taf) {
        const result = {
          taf,
          station: candidateIcao,
          isNearby: true,
          distanceNm: Math.round(candidate.distance_nm * 10) / 10,
          requestedStation: icao,
        };
        this.setCache(cacheKey, result);
        return result;
      }
    }

    // No nearby TAF found
    const result = {
      taf: null,
      station: null,
      isNearby: false,
      distanceNm: null,
      requestedStation: icao,
    };
    this.setCache(cacheKey, result);
    return result;
  }

  async getForecast(icao: string): Promise<any> {
    const cacheKey = `forecast:${icao}`;
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    const airport = await this.airportsService.findById(icao);
    if (!airport || airport.latitude == null || airport.longitude == null) {
      return { error: 'Airport not found or missing coordinates', icao };
    }

    try {
      const grid = await this.resolveNwsGrid(
        airport.latitude,
        airport.longitude,
        icao,
      );

      const { data } = await firstValueFrom(
        this.http.get(
          `${this.NWS_BASE}/gridpoints/${grid.gridId}/${grid.gridX},${grid.gridY}/forecast`,
          { headers: this.NWS_HEADERS },
        ),
      );

      const periods = (data?.properties?.periods ?? []).map((p: any) => ({
        name: p.name,
        isDaytime: p.isDaytime,
        temperature: p.temperature,
        temperatureUnit: p.temperatureUnit,
        probabilityOfPrecipitation: p.probabilityOfPrecipitation?.value ?? null,
        windSpeed: p.windSpeed,
        windDirection: p.windDirection,
        shortForecast: p.shortForecast,
        detailedForecast: p.detailedForecast,
      }));

      const result = {
        icao,
        generatedAt: data?.properties?.generatedAt ?? new Date().toISOString(),
        periods,
      };
      this.setCache(cacheKey, result);
      return result;
    } catch (error) {
      this.logger.error(`Failed to fetch forecast for ${icao}`, error);
      return { error: 'Failed to fetch forecast', icao };
    }
  }

  async getWindsAloft(icao: string): Promise<any> {
    const cacheKey = `winds-aloft:${icao}`;
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    // Look up airport to get FAA 3-letter identifier
    const airport = await this.airportsService.findById(icao);
    if (!airport || airport.latitude == null || airport.longitude == null) {
      return {
        station: null,
        icao,
        isNearby: false,
        distanceNm: null,
        requestedStation: icao,
        forecasts: [],
      };
    }

    const faaId = airport.identifier; // 3-letter FAA code

    // Fetch and parse all 3 forecast periods
    const periods: Array<{ fcst: string; label: string }> = [
      { fcst: '06', label: '6-hour' },
      { fcst: '12', label: '12-hour' },
      { fcst: '24', label: '24-hour' },
    ];

    const parsedMaps = await Promise.all(
      periods.map((p) => this.fetchAndParseWinds(p.fcst)),
    );

    // Try direct lookup first
    let stationCode = faaId;
    let isNearby = false;
    let distanceNm = 0;

    const hasDirectData = parsedMaps.some(
      (m) => m.data.has(faaId) && m.data.get(faaId)!.length > 0,
    );

    if (!hasDirectData) {
      // Nearest fallback: search nearby airports
      const nearby = await this.airportsService.findNearby(
        airport.latitude,
        airport.longitude,
        100,
        50,
      );

      let found = false;
      for (const candidate of nearby) {
        const candidateId = candidate.identifier;
        if (!candidateId || candidateId === faaId) continue;

        const candidateHasData = parsedMaps.some(
          (m) => m.data.has(candidateId) && m.data.get(candidateId)!.length > 0,
        );

        if (candidateHasData) {
          stationCode = candidateId;
          isNearby = true;
          distanceNm = Math.round(candidate.distance_nm * 10) / 10;
          found = true;
          break;
        }
      }

      if (!found) {
        const result = {
          station: null,
          icao,
          isNearby: false,
          distanceNm: null,
          requestedStation: icao,
          forecasts: [],
        };
        this.setCache(cacheKey, result, this.WINDS_CACHE_TTL_MS);
        return result;
      }
    }

    // Assemble forecasts
    const forecasts: WindsAloftForecast[] = periods.map((p, i) => {
      const altitudes = parsedMaps[i].data.get(stationCode) ?? [];
      return {
        period: p.fcst,
        label: p.label,
        altitudes,
      };
    });

    const result = {
      station: stationCode,
      icao,
      isNearby,
      distanceNm,
      requestedStation: icao,
      forecasts,
    };

    this.setCache(cacheKey, result, this.WINDS_CACHE_TTL_MS);
    return result;
  }

  private async fetchAndParseWinds(
    fcst: string,
  ): Promise<{ data: Map<string, WindsAloftAltitude[]> }> {
    const cacheKey = `winds-parsed:${fcst}`;
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    try {
      const { data } = await firstValueFrom(
        this.http.get(`${this.AWC_BASE}/windtemp`, {
          params: { region: 'us', level: 'low', fcst },
          responseType: 'text',
          transformResponse: [(d: any) => d], // prevent JSON parsing
        }),
      );

      const parsed = this.parseWindsAloftText(data as string);
      const result = { data: parsed };
      this.setCache(cacheKey, result, this.WINDS_CACHE_TTL_MS);
      return result;
    } catch (error) {
      this.logger.error(`Failed to fetch winds aloft for fcst=${fcst}`, error);
      return { data: new Map() };
    }
  }

  private parseWindsAloftText(
    rawText: string,
  ): Map<string, WindsAloftAltitude[]> {
    const result = new Map<string, WindsAloftAltitude[]>();
    const lines = rawText.split('\n');

    // Find the FT header line that defines altitude columns
    let headerIndex = -1;
    let altitudes: number[] = [];
    let colPositions: Array<{ start: number; end: number }> = [];

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      if (/^\s*FT\s/.test(line) || /^\s*FT\s*3000/.test(line)) {
        headerIndex = i;

        // Parse altitude values from header
        const matches = [...line.matchAll(/\d+/g)];
        altitudes = matches.map((m) => parseInt(m[0], 10));

        // Determine column positions by finding each altitude number's position
        colPositions = matches.map((m, idx) => {
          const start = m.index;
          const end =
            idx < matches.length - 1
              ? matches[idx + 1].index
              : line.length + 10;
          return { start, end };
        });
        break;
      }
    }

    if (headerIndex === -1 || altitudes.length === 0) {
      return result;
    }

    // Parse station data lines (lines after the header)
    for (let i = headerIndex + 1; i < lines.length; i++) {
      const line = lines[i];
      if (line.trim().length === 0) continue;

      // Station code is at the beginning of the line (3 letters)
      const stationMatch = line.match(/^([A-Z]{3})\s/);
      if (!stationMatch) continue;

      const station = stationMatch[1];
      const stationAltitudes: WindsAloftAltitude[] = [];

      for (let j = 0; j < altitudes.length; j++) {
        const alt = altitudes[j];
        const { start, end } = colPositions[j];
        const rawValue = line
          .substring(start, Math.min(end, line.length))
          .trim();

        const decoded = this.decodeWindValue(rawValue, alt);
        stationAltitudes.push({
          altitude: alt,
          ...decoded,
        });
      }

      result.set(station, stationAltitudes);
    }

    return result;
  }

  private decodeWindValue(
    raw: string,
    altitude: number,
  ): {
    direction: number | null;
    speed: number | null;
    temperature: number | null;
    lightAndVariable: boolean;
  } {
    if (!raw || raw.trim() === '') {
      return {
        direction: null,
        speed: null,
        temperature: null,
        lightAndVariable: false,
      };
    }

    // Light and variable
    if (raw.startsWith('9900')) {
      let temperature: number | null = null;
      if (raw.length > 4) {
        const tempPart = raw.substring(4);
        const tempMatch = tempPart.match(/([+-]?\d+)/);
        if (tempMatch) {
          temperature = parseInt(tempMatch[1], 10);
        }
      }
      return {
        direction: null,
        speed: null,
        temperature,
        lightAndVariable: true,
      };
    }

    // Need at least 4 chars for DDHH
    if (raw.length < 4) {
      return {
        direction: null,
        speed: null,
        temperature: null,
        lightAndVariable: false,
      };
    }

    let dd = parseInt(raw.substring(0, 2), 10);
    let hh = parseInt(raw.substring(2, 4), 10);
    let temperature: number | null = null;

    // Speed >= 100kts: DD += 50
    if (dd >= 51 && dd <= 86) {
      dd -= 50;
      hh += 100;
    }

    const direction = dd * 10;
    const speed = hh;

    // Parse temperature
    if (altitude === 3000) {
      // No temperature at 3000ft
      temperature = null;
    } else if (altitude > 24000) {
      // Above 24000: DDHHTT (6 digits, temp always negative)
      if (raw.length >= 6) {
        const tt = parseInt(raw.substring(4, 6), 10);
        temperature = -tt;
      }
    } else {
      // 6000-24000: DDHH+TT or DDHH-TT (explicit sign)
      const tempPart = raw.substring(4);
      if (tempPart.length > 0) {
        const tempMatch = tempPart.match(/([+-]?\d+)/);
        if (tempMatch) {
          temperature = parseInt(tempMatch[1], 10);
        }
      }
    }

    return { direction, speed, temperature, lightAndVariable: false };
  }

  async getNotams(icao: string): Promise<any> {
    const cacheKey = `notams:${icao}`;
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    // Look up FAA identifier (e.g. KAPA -> APA)
    const airport = await this.airportsService.findById(icao);
    const faaId = airport?.identifier ?? icao.replace(/^K/, '');

    try {
      const params = new URLSearchParams();
      params.append('searchType', '0');
      params.append('designatorsForLocation', faaId);
      params.append('designatorForAccountable', '');
      params.append('latDegrees', '');
      params.append('latMinutes', '0');
      params.append('latSeconds', '0');
      params.append('longDegrees', '');
      params.append('longMinutes', '0');
      params.append('longSeconds', '0');
      params.append('radius', '10');
      params.append('sortColumns', '5 false');
      params.append('sortDirection', 'true');
      params.append('designatorForNotamNumberSearch', '');
      params.append('notamNumber', '');
      params.append('radiusSearchOnDesignator', 'false');
      params.append('radiusSearchDesignator', '');
      params.append('latitudeDirection', 'N');
      params.append('longitudeDirection', 'W');
      params.append('freeFormText', '');
      params.append('flightPathText', '');
      params.append('flightPathDivertAirfields', '');
      params.append('flightPathBuffer', '4');
      params.append('flightPathIncludeNavaids', 'true');
      params.append('flightPathIncludeArtcc', 'false');
      params.append('flightPathIncludeTfr', 'true');
      params.append('flightPathIncludeRegulatory', 'false');
      params.append('flightPathResultsType', 'All NOTAMs');
      params.append('archiveDate', '');
      params.append('archiveDesignator', '');
      params.append('offset', '0');
      params.append('notamsOnly', 'false');
      params.append('filters', '');

      const { data } = await firstValueFrom(
        this.http.post(
          'https://notams.aim.faa.gov/notamSearch/search',
          params.toString(),
          {
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
              Accept: 'application/json, text/plain, */*',
              Origin: 'https://notams.aim.faa.gov',
              Referer: 'https://notams.aim.faa.gov/notamSearch/',
            },
            timeout: 30000,
          },
        ),
      );

      const rawList = data?.notamList ?? [];

      const notams = rawList
        .filter((n: any) => !n.cancelledOrExpired)
        .map((n: any) => ({
          id: n.notamNumber ?? '',
          type: n.keyword ?? '',
          icaoId: n.icaoId ?? icao,
          facilityDesignator: n.facilityDesignator ?? '',
          text: n.traditionalMessageFrom4thWord ?? n.traditionalMessage ?? '',
          effectiveStart: this.parseNotamDate(n.startDate),
          effectiveEnd: this.parseNotamDate(n.endDate),
          classification: n.featureName ?? '',
          isExpired: false,
        }));

      const result = {
        icao,
        count: notams.length,
        notams,
      };

      this.setCache(cacheKey, result, this.NOTAM_CACHE_TTL_MS);
      return result;
    } catch (error) {
      this.logger.error(`Failed to fetch NOTAMs for ${icao}`, error);
      return { icao, count: 0, notams: [], error: 'Failed to fetch NOTAMs' };
    }
  }

  /**
   * Parse FAA NOTAM date format "MM/DD/YYYY HHMM" to ISO 8601.
   */
  private parseNotamDate(dateStr: string | null | undefined): string | null {
    if (!dateStr) return null;
    // Handle "MM/DD/YYYY HHMM" or "MM/DD/YYYY HHMMest" formats
    const clean = dateStr.replace(/EST$/i, '').trim();
    const match = clean.match(/^(\d{2})\/(\d{2})\/(\d{4})\s+(\d{2})(\d{2})$/);
    if (!match) return null;
    const [, month, day, year, hour, minute] = match;
    return `${year}-${month}-${day}T${hour}:${minute}:00Z`;
  }

  private async resolveNwsGrid(
    lat: number,
    lon: number,
    icao: string,
  ): Promise<{ gridId: string; gridX: number; gridY: number }> {
    const cacheKey = `nws-grid:${icao}`;
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    const { data } = await firstValueFrom(
      this.http.get(
        `${this.NWS_BASE}/points/${lat.toFixed(4)},${lon.toFixed(4)}`,
        { headers: this.NWS_HEADERS },
      ),
    );

    const grid = {
      gridId: data.properties.gridId,
      gridX: data.properties.gridX,
      gridY: data.properties.gridY,
    };
    this.setCache(cacheKey, grid, this.GRID_CACHE_TTL_MS);
    return grid;
  }

  private getFromCache(key: string): any | null {
    const entry = this.cache.get(key);
    if (entry && entry.expiresAt > Date.now()) {
      return entry.data;
    }
    this.cache.delete(key);
    return null;
  }

  private setCache(key: string, data: any, ttlMs?: number): void {
    this.cache.set(key, {
      data,
      expiresAt: Date.now() + (ttlMs ?? this.CACHE_TTL_MS),
    });
  }
}
