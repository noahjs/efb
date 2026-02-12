import { Injectable, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Between } from 'typeorm';
import { Storage } from '@google-cloud/storage';
import * as path from 'path';
import { firstValueFrom } from 'rxjs';
import { AirportsService } from '../airports/airports.service';
import { WEATHER, DATIS, LIVEATC_ATIS } from '../config/constants';
import { WeatherStation } from './entities/weather-station.entity';
import { AtisRecording } from './entities/atis-recording.entity';
import { AtisTranscriptionService } from './atis-transcription.service';
import { Metar } from '../data-platform/entities/metar.entity';
import { Taf } from '../data-platform/entities/taf.entity';
import { WindsAloft } from '../data-platform/entities/winds-aloft.entity';
import { Notam } from '../data-platform/entities/notam.entity';
import { NwsForecast } from '../data-platform/entities/nws-forecast.entity';
import { Atis } from '../data-platform/entities/atis.entity';

interface WindsAloftForecast {
  period: string;
  label: string;
  altitudes: any[];
}

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
export class WeatherService {
  private readonly logger = new Logger(WeatherService.name);

  // In-memory cache for non-polled data (D-ATIS, NWS forecast, nearest lookups)
  private cache = new Map<string, { data: any; expiresAt: number }>();

  // Track in-flight ATIS refreshes to prevent duplicate background work
  private atisRefreshing = new Set<string>();

  // API status tracking
  private _totalRequests = 0;
  private _totalErrors = 0;
  private _lastFetchAt = 0;
  private _lastErrorAt = 0;
  private _lastError = '';

  private readonly NWS_HEADERS = {
    'User-Agent': WEATHER.NWS_USER_AGENT,
    Accept: 'application/geo+json',
  };

  private readonly gcsStorage: Storage | null;
  private readonly gcsBucket: string;

  constructor(
    private readonly http: HttpService,
    private readonly airportsService: AirportsService,
    @InjectRepository(WeatherStation)
    private readonly wxStationRepo: Repository<WeatherStation>,
    @InjectRepository(AtisRecording)
    private readonly atisRecordingRepo: Repository<AtisRecording>,
    private readonly atisTranscription: AtisTranscriptionService,
    @InjectRepository(Metar)
    private readonly metarRepo: Repository<Metar>,
    @InjectRepository(Taf)
    private readonly tafRepo: Repository<Taf>,
    @InjectRepository(WindsAloft)
    private readonly windsAloftRepo: Repository<WindsAloft>,
    @InjectRepository(Notam)
    private readonly notamRepo: Repository<Notam>,
    @InjectRepository(NwsForecast)
    private readonly nwsForecastRepo: Repository<NwsForecast>,
    @InjectRepository(Atis)
    private readonly atisRepo: Repository<Atis>,
  ) {
    this.gcsBucket = process.env.GCS_ATIS_BUCKET || 'efb-atis-dev';
    const keyFilePath =
      process.env.GCS_KEY_FILE ||
      path.resolve(process.cwd(), '..', 'gcs-key.json');

    try {
      this.gcsStorage = new Storage({ keyFilename: keyFilePath });
    } catch {
      this.logger.warn('GCS storage not available for ATIS audio');
      this.gcsStorage = null;
    }
  }

  async getDatis(
    icao: string,
  ): Promise<{
    status: 'processing' | 'current' | 'error';
    entries: any[] | null;
    _meta: { updatedAt: string | null; ageSeconds: number | null } | null;
  }> {
    const cacheKey = `datis:${icao}`;

    // 1. In-memory cache hit → return immediately
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    // 2. Check DB for persisted ATIS
    const dbRow = await this.atisRepo.findOne({ where: { icao_id: icao } });

    if (dbRow) {
      const entries = dbRow.raw_data as any[] | null;
      const meta = dataMeta(dbRow.fetched_at);

      if (dbRow.status === 'current' && entries) {
        const age = Date.now() - (dbRow.fetched_at?.getTime() ?? 0);
        const ttl =
          dbRow.source === 'liveatc'
            ? LIVEATC_ATIS.CACHE_TTL_MS
            : DATIS.CACHE_TTL_MS;

        if (age < ttl) {
          // Fresh — populate in-memory cache and return
          const result = { status: 'current' as const, entries, _meta: meta };
          this.setCache(cacheKey, result, ttl - age);
          return result;
        }

        // Stale — mark processing, kick off background, return stale data
        await this.atisRepo.update(icao, { status: 'processing' });
        this.refreshAtisBackground(icao);
        return { status: 'processing', entries, _meta: meta };
      }

      if (dbRow.status === 'processing') {
        // Already refreshing — don't start another
        return { status: 'processing', entries, _meta: meta };
      }

      if (dbRow.status === 'error') {
        return { status: 'error', entries, _meta: meta };
      }
    }

    // 3. No DB row — first time for this airport
    const airport = await this.airportsService.findByIdLean(icao);
    const hasDatis = airport?.has_datis ?? false;

    if (hasDatis) {
      // D-ATIS API is fast (~2s) — try it blocking
      try {
        this._totalRequests++;
        const { data } = await firstValueFrom(
          this.http.get(`${DATIS.API_URL}/${icao}`, {
            timeout: DATIS.TIMEOUT_MS,
          }),
        );

        if (Array.isArray(data) && data.length > 0) {
          const tagged = data.map((entry: any) => ({
            ...entry,
            source: 'datis',
          }));
          const now = new Date();
          await this.saveAtisToDb(icao, tagged, 'datis', now, 'current');
          const result = {
            status: 'current' as const,
            entries: tagged,
            _meta: dataMeta(now),
          };
          this.setCache(cacheKey, result, DATIS.CACHE_TTL_MS);
          return result;
        }
      } catch (error) {
        this._totalErrors++;
        this._lastErrorAt = Date.now();
        this._lastError = error?.message || String(error);
        this.logger.warn(`D-ATIS error for ${icao}: ${this._lastError}`);
      }
    }

    // LiveATC-capable or D-ATIS failed — insert processing row, return immediately
    const hasLiveatc = airport?.has_liveatc ?? false;
    if (hasLiveatc || hasDatis) {
      await this.saveAtisToDb(
        icao,
        null,
        hasLiveatc ? 'liveatc' : 'datis',
        null,
        'processing',
      );
      this.refreshAtisBackground(icao);
      return { status: 'processing', entries: null, _meta: null };
    }

    // No ATIS capability at all
    return { status: 'error', entries: null, _meta: null };
  }

  private refreshAtisBackground(icao: string): void {
    if (this.atisRefreshing.has(icao)) return;
    this.atisRefreshing.add(icao);

    (async () => {
      try {
        const airport = await this.airportsService.findByIdLean(icao);
        const hasDatis = airport?.has_datis ?? false;

        if (hasDatis) {
          this._totalRequests++;
          const { data } = await firstValueFrom(
            this.http.get(`${DATIS.API_URL}/${icao}`, {
              timeout: DATIS.TIMEOUT_MS,
            }),
          );
          if (Array.isArray(data) && data.length > 0) {
            const tagged = data.map((entry: any) => ({
              ...entry,
              source: 'datis',
            }));
            const now = new Date();
            await this.saveAtisToDb(icao, tagged, 'datis', now, 'current');
            const result = {
              status: 'current' as const,
              entries: tagged,
              _meta: dataMeta(now),
            };
            this.setCache(`datis:${icao}`, result, DATIS.CACHE_TTL_MS);
            return;
          }
        }

        // Fall back to LiveATC
        const liveatcResult =
          await this.atisTranscription.getTranscribedAtis(icao);
        if (liveatcResult && liveatcResult.length > 0) {
          const now = new Date();
          await this.saveAtisToDb(
            icao,
            liveatcResult,
            'liveatc',
            now,
            'current',
          );
          const result = {
            status: 'current' as const,
            entries: liveatcResult,
            _meta: dataMeta(now),
          };
          this.setCache(
            `datis:${icao}`,
            result,
            LIVEATC_ATIS.CACHE_TTL_MS,
          );
        } else {
          // Transcription failed — mark error, preserve old raw_data
          await this.atisRepo.update(icao, { status: 'error' });
        }
      } catch (error) {
        this.logger.warn(
          `Background ATIS refresh failed for ${icao}: ${error?.message || error}`,
        );
        // Mark error in DB but preserve last good raw_data
        try {
          await this.atisRepo.update(icao, { status: 'error' });
        } catch {
          // ignore
        }
      } finally {
        this.atisRefreshing.delete(icao);
      }
    })();
  }

  private async saveAtisToDb(
    icao: string,
    entries: any[] | null,
    source: string,
    fetchedAt: Date | null,
    status: 'processing' | 'current' | 'error',
  ): Promise<void> {
    try {
      const firstText = entries?.[0]?.datis ?? '';
      const letterMatch = firstText.match(
        /INFORMATION\s+([A-Z])\b|ATIS\s+INFO(?:RMATION)?\s+([A-Z])\b/i,
      );
      const letter = letterMatch
        ? (letterMatch[1] || letterMatch[2]).toUpperCase()
        : null;

      const type = entries?.[0]?.type ?? 'combined';

      const row: any = {
        icao_id: icao,
        source,
        type,
        status,
      };

      // Only overwrite raw_data/text/letter when we have actual entries
      if (entries) {
        row.datis_text = firstText;
        row.letter = letter;
        row.raw_data = entries;
        row.fetched_at = fetchedAt;
      } else if (status === 'processing') {
        // For initial processing row with no prior data
        const existing = await this.atisRepo.findOne({
          where: { icao_id: icao },
        });
        if (!existing) {
          row.datis_text = null;
          row.letter = null;
          row.raw_data = null;
          row.fetched_at = null;
        }
      }

      await this.atisRepo.upsert(row, ['icao_id']);
    } catch (error) {
      this.logger.warn(
        `Failed to save ATIS to DB for ${icao}: ${error?.message || error}`,
      );
    }
  }

  /**
   * Get METAR from database (populated by MetarPoller).
   */
  async getMetar(icao: string): Promise<any> {
    const row = await this.metarRepo.findOne({ where: { icao_id: icao } });
    if (!row) return null;
    // Return the raw AWC response with staleness metadata
    return { ...row.raw_data, _meta: dataMeta(row.updated_at) };
  }

  /**
   * Get TAF from database (populated by TafPoller).
   */
  async getTaf(icao: string): Promise<any> {
    const row = await this.tafRepo.findOne({ where: { icao_id: icao } });
    if (!row) return null;
    return { ...row.raw_data, _meta: dataMeta(row.updated_at) };
  }

  /**
   * Get bulk METARs from database by spatial bounds.
   * No more cache misses on pan — always a simple DB query.
   */
  async getBulkMetars(bounds: {
    minLat: number;
    maxLat: number;
    minLng: number;
    maxLng: number;
  }): Promise<any> {
    const rows = await this.metarRepo.find({
      where: {
        latitude: Between(bounds.minLat, bounds.maxLat),
        longitude: Between(bounds.minLng, bounds.maxLng),
      },
    });
    const oldestUpdatedAt = rows.length
      ? rows.reduce(
          (oldest, r) =>
            r.updated_at < oldest ? r.updated_at : oldest,
          rows[0].updated_at,
        )
      : null;
    return {
      data: rows.map((r) => r.raw_data),
      _meta: dataMeta(oldestUpdatedAt),
    };
  }

  async getNearestMetar(icao: string): Promise<any> {
    const cacheKey = `nearest-metar:${icao}`;
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    const airport = await this.airportsService.findById(icao);
    const resolvedIcao = airport?.icao_identifier || icao;

    const directMetar = await this.getMetar(resolvedIcao);
    if (directMetar) {
      const result = {
        metar: directMetar,
        station: resolvedIcao,
        isNearby: false,
        distanceNm: 0,
        requestedStation: icao,
        awos: null,
      };
      this.setCache(cacheKey, result);
      return result;
    }

    let awos: {
      name: string;
      frequency: string | null;
      phone: string | null;
    } | null = null;
    if (airport?.frequencies) {
      const awosFreq = airport.frequencies.find(
        (f) => f.type === 'AWOS' || f.type === 'ASOS',
      );
      if (awosFreq) {
        awos = {
          name: awosFreq.name || awosFreq.type,
          frequency: awosFreq.frequency || null,
          phone: awosFreq.phone || null,
        };
      }
    }

    if (!airport || airport.latitude == null || airport.longitude == null) {
      const result = {
        metar: null,
        station: null,
        isNearby: false,
        distanceNm: null,
        requestedStation: icao,
        awos,
      };
      this.setCache(cacheKey, result);
      return result;
    }

    const nearby = await this.airportsService.findNearby(
      airport.latitude,
      airport.longitude,
      WEATHER.METAR_SEARCH_RADIUS_NM,
      WEATHER.METAR_SEARCH_LIMIT,
    );

    const faaId = airport.identifier;

    for (const candidate of nearby) {
      const candidateIcao = candidate.icao_identifier;
      if (!candidateIcao || candidateIcao === resolvedIcao) continue;
      if (candidate.identifier === faaId) continue;

      const metar = await this.getMetar(candidateIcao);
      if (metar) {
        const result = {
          metar,
          station: candidateIcao,
          isNearby: true,
          distanceNm: Math.round(candidate.distance_nm * 10) / 10,
          requestedStation: icao,
          awos,
        };
        this.setCache(cacheKey, result);
        return result;
      }
    }

    const result = {
      metar: null,
      station: null,
      isNearby: false,
      distanceNm: null,
      requestedStation: icao,
      awos,
    };
    this.setCache(cacheKey, result);
    return result;
  }

  async getNearestTaf(icao: string): Promise<any> {
    const cacheKey = `nearest-taf:${icao}`;
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    const airport = await this.airportsService.findById(icao);
    const resolvedIcao = airport?.icao_identifier || icao;

    const directTaf = await this.getTaf(resolvedIcao);
    if (directTaf) {
      const result = {
        taf: directTaf,
        station: resolvedIcao,
        isNearby: false,
        distanceNm: 0,
        requestedStation: icao,
      };
      this.setCache(cacheKey, result);
      return result;
    }

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

    const faaId = airport.identifier;
    const nearby = await this.airportsService.findNearby(
      airport.latitude,
      airport.longitude,
      WEATHER.TAF_SEARCH_RADIUS_NM,
      WEATHER.TAF_SEARCH_LIMIT,
    );

    for (const candidate of nearby) {
      const candidateIcao = candidate.icao_identifier;
      if (!candidateIcao || candidateIcao === resolvedIcao) continue;
      if (candidate.identifier === faaId) continue;

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

  /**
   * Get NWS forecast — check DB first (cached by nws_grid_poll),
   * fall back to live API call and store result.
   */
  async getForecast(icao: string): Promise<any> {
    // Check DB first
    const cached = await this.nwsForecastRepo.findOne({
      where: { icao_id: icao },
    });

    // If fresh enough (< 30 min), return from DB
    if (cached?.forecast_data) {
      const age = Date.now() - new Date(cached.updated_at).getTime();
      if (age < 30 * 60 * 1000) {
        return cached.forecast_data;
      }
    }

    const airport = await this.airportsService.findById(icao);
    if (!airport || airport.latitude == null || airport.longitude == null) {
      return { error: 'Airport not found or missing coordinates', icao };
    }

    try {
      this._totalRequests++;

      // Use stored grid mapping if available, otherwise resolve via NWS
      let gridId: string;
      let gridX: number;
      let gridY: number;

      if (cached?.grid_id && cached?.grid_x != null && cached?.grid_y != null) {
        gridId = cached.grid_id;
        gridX = cached.grid_x;
        gridY = cached.grid_y;
      } else {
        const grid = await this.resolveNwsGrid(
          airport.latitude,
          airport.longitude,
        );
        gridId = grid.gridId;
        gridX = grid.gridX;
        gridY = grid.gridY;
      }

      const { data } = await firstValueFrom(
        this.http.get(
          `${WEATHER.NWS_BASE_URL}/gridpoints/${gridId}/${gridX},${gridY}/forecast`,
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

      // Store in DB for future use
      await this.nwsForecastRepo.upsert(
        {
          icao_id: icao,
          grid_id: gridId,
          grid_x: gridX,
          grid_y: gridY,
          forecast_data: result as any,
        },
        ['icao_id'],
      );

      return result;
    } catch (error) {
      this._totalErrors++;
      this._lastErrorAt = Date.now();
      this._lastError = error?.message || String(error);
      this.logger.error(`Failed to fetch forecast for ${icao}`, error);

      // Return stale data if available
      if (cached?.forecast_data) return cached.forecast_data;
      return { error: 'Failed to fetch forecast', icao };
    }
  }

  /**
   * Get winds aloft from database (populated by WindsAloftPoller).
   */
  async getWindsAloft(icao: string): Promise<any> {
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

    const faaId = airport.identifier;

    const periods = [
      { fcst: '06', label: '6-hour' },
      { fcst: '12', label: '12-hour' },
      { fcst: '24', label: '24-hour' },
    ];

    // Try direct lookup
    const directRows = await this.windsAloftRepo.find({
      where: { station_code: faaId },
    });

    let stationCode = faaId;
    let isNearby = false;
    let distanceNm = 0;

    if (directRows.length === 0) {
      // Nearest fallback: search nearby airports
      const nearby = await this.airportsService.findNearby(
        airport.latitude,
        airport.longitude,
        WEATHER.WINDS_SEARCH_RADIUS_NM,
        WEATHER.WINDS_SEARCH_LIMIT,
      );

      let found = false;
      for (const candidate of nearby) {
        const candidateId = candidate.identifier;
        if (!candidateId || candidateId === faaId) continue;

        const candidateRows = await this.windsAloftRepo.find({
          where: { station_code: candidateId },
        });

        if (candidateRows.length > 0) {
          stationCode = candidateId;
          isNearby = true;
          distanceNm = Math.round(candidate.distance_nm * 10) / 10;
          found = true;
          break;
        }
      }

      if (!found) {
        return {
          station: null,
          icao,
          isNearby: false,
          distanceNm: null,
          requestedStation: icao,
          forecasts: [],
        };
      }
    }

    // Build up rows for final station
    const rows =
      stationCode === faaId
        ? directRows
        : await this.windsAloftRepo.find({
            where: { station_code: stationCode },
          });

    const rowMap = new Map<string, any>();
    for (const row of rows) {
      rowMap.set(row.forecast_period, row.altitudes);
    }

    const forecasts: WindsAloftForecast[] = periods.map((p) => ({
      period: p.fcst,
      label: p.label,
      altitudes: rowMap.get(p.fcst) ?? [],
    }));

    const oldestUpdatedAt = rows.length
      ? rows.reduce(
          (oldest, r) =>
            r.updated_at < oldest ? r.updated_at : oldest,
          rows[0].updated_at,
        )
      : null;

    return {
      station: stationCode,
      icao,
      isNearby,
      distanceNm,
      requestedStation: icao,
      forecasts,
      _meta: dataMeta(oldestUpdatedAt),
    };
  }

  /**
   * Get NOTAMs from database (populated by NotamPoller for top airports).
   * Falls back to live API call for non-polled airports, stores result in DB.
   */
  async getNotams(icao: string): Promise<any> {
    const airport = await this.airportsService.findById(icao);
    const faaId = airport?.identifier ?? icao.replace(/^K/, '');

    // Check DB first
    const dbNotams = await this.notamRepo.find({
      where: { airport_id: faaId },
    });

    if (dbNotams.length > 0) {
      // Check staleness — if the most recent update is within 30 min, serve from DB
      const mostRecent = dbNotams.reduce((latest, n) =>
        new Date(n.updated_at) > new Date(latest.updated_at) ? n : latest,
      );
      const age = Date.now() - new Date(mostRecent.updated_at).getTime();

      if (age < WEATHER.CACHE_TTL_NOTAM_MS) {
        const notams = dbNotams.map((n) => ({
          id: n.notam_number,
          type: n.keyword ?? '',
          icaoId: icao,
          facilityDesignator: '',
          text: n.text ?? '',
          fullText: n.full_text ?? '',
          effectiveStart: n.effective_start,
          effectiveEnd: n.effective_end,
          classification: n.classification ?? '',
          isExpired: false,
        }));

        return { icao, count: notams.length, notams };
      }
    }

    // On-demand fetch for non-polled or stale airports
    try {
      this._totalRequests++;
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
      params.append('radius', WEATHER.NOTAM_SEARCH_RADIUS_NM);
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
        this.http.post(WEATHER.NOTAM_API_URL, params.toString(), {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
            Accept: 'application/json, text/plain, */*',
            'Accept-Language': 'en-US,en;q=0.9',
            Origin: 'https://notams.aim.faa.gov',
            Referer: 'https://notams.aim.faa.gov/notamSearch/',
            'Sec-Fetch-Dest': 'empty',
            'Sec-Fetch-Mode': 'cors',
            'Sec-Fetch-Site': 'same-origin',
          },
          timeout: WEATHER.TIMEOUT_NOTAM_MS,
        }),
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
          fullText: n.traditionalMessage ?? '',
          effectiveStart: this.parseNotamDate(n.startDate),
          effectiveEnd: this.parseNotamDate(n.endDate),
          classification: n.featureName ?? '',
          isExpired: false,
        }));

      // Store in DB for subsequent requests
      if (notams.length > 0) {
        const entities = notams
          .filter((n) => n.id)
          .map((n) => {
            const entity = new Notam();
            entity.notam_number = n.id;
            entity.airport_id = faaId;
            entity.text = n.text;
            entity.full_text = n.fullText;
            entity.keyword = n.type;
            entity.classification = n.classification;
            entity.effective_start = n.effectiveStart;
            entity.effective_end = n.effectiveEnd;
            return entity;
          });

        await this.notamRepo.manager.transaction(async (em) => {
          await em.delete(Notam, { airport_id: faaId });
          await em.save(Notam, entities);
        });
      }

      return { icao, count: notams.length, notams };
    } catch (error) {
      this._totalErrors++;
      this._lastErrorAt = Date.now();
      this._lastError = error?.message || String(error);
      this.logger.error(`Failed to fetch NOTAMs for ${icao}`, error);

      // Return stale DB data if available
      if (dbNotams.length > 0) {
        const notams = dbNotams.map((n) => ({
          id: n.notam_number,
          type: n.keyword ?? '',
          icaoId: icao,
          facilityDesignator: '',
          text: n.text ?? '',
          fullText: n.full_text ?? '',
          effectiveStart: n.effective_start,
          effectiveEnd: n.effective_end,
          classification: n.classification ?? '',
          isExpired: false,
        }));
        return { icao, count: notams.length, notams };
      }

      return { icao, count: 0, notams: [], error: 'Failed to fetch NOTAMs' };
    }
  }

  private parseNotamDate(dateStr: string | null | undefined): string | null {
    if (!dateStr) return null;
    const clean = dateStr.replace(/EST$/i, '').trim();
    const match = clean.match(/^(\d{2})\/(\d{2})\/(\d{4})\s+(\d{2})(\d{2})$/);
    if (!match) return null;
    const [, month, day, year, hour, minute] = match;
    return `${year}-${month}-${day}T${hour}:${minute}:00Z`;
  }

  private async resolveNwsGrid(
    lat: number,
    lon: number,
  ): Promise<{ gridId: string; gridX: number; gridY: number }> {
    this._totalRequests++;
    const { data } = await firstValueFrom(
      this.http.get(
        `${WEATHER.NWS_BASE_URL}/points/${lat.toFixed(4)},${lon.toFixed(4)}`,
        { headers: this.NWS_HEADERS },
      ),
    );

    return {
      gridId: data.properties.gridId,
      gridX: data.properties.gridX,
      gridY: data.properties.gridY,
    };
  }

  async getWxStationsInBounds(bounds: {
    minLat: number;
    maxLat: number;
    minLng: number;
    maxLng: number;
  }): Promise<WeatherStation[]> {
    return this.wxStationRepo.find({
      where: {
        latitude: Between(bounds.minLat, bounds.maxLat),
        longitude: Between(bounds.minLng, bounds.maxLng),
      },
    });
  }

  async getWxStation(icaoId: string): Promise<WeatherStation | null> {
    return this.wxStationRepo.findOne({
      where: { icao_id: icaoId },
    });
  }

  async getAtisAudioUrl(icao: string): Promise<{ url: string } | null> {
    if (!this.gcsStorage) return null;

    const recording = await this.atisRecordingRepo.findOne({
      where: { icao: icao.toUpperCase() },
      order: { recorded_at: 'DESC' },
    });

    if (!recording) return null;

    const file = this.gcsStorage.bucket(this.gcsBucket).file(recording.gcs_key);
    const [url] = await file.getSignedUrl({
      action: 'read',
      expires: Date.now() + 3600 * 1000,
    });

    return { url };
  }

  getStats() {
    return {
      name: 'Weather',
      baseUrl: WEATHER.AWC_BASE_URL,
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

  private setCache(key: string, data: any, ttlMs?: number): void {
    this._lastFetchAt = Date.now();
    this.cache.set(key, {
      data,
      expiresAt: Date.now() + (ttlMs ?? WEATHER.CACHE_TTL_METAR_MS),
    });
  }
}
