import { Injectable } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { firstValueFrom } from 'rxjs';
import { BasePoller, PollerResult } from './base.poller';
import { WindGrid } from '../entities/wind-grid.entity';
import { WINDS } from '../../config/constants';

// CONUS bounds at 1-degree spacing
const LAT_MIN = 24;
const LAT_MAX = 50;
const LNG_MIN = -125;
const LNG_MAX = -66;

// Retry config — mirrors elevation.service.ts pattern
const MAX_RETRIES = 3;
const BASE_BACKOFF_MS = 5000; // 5s, 10s, 20s
const BATCH_DELAY_MS = 1500; // 1.5s between batches (lower with proxy)

const SCRAPINGBEE_BASE = 'https://app.scrapingbee.com/api/v1';

@Injectable()
export class WindGridPoller extends BasePoller {
  constructor(
    private readonly http: HttpService,
    @InjectRepository(WindGrid)
    private readonly windGridRepo: Repository<WindGrid>,
  ) {
    super('WindGridPoller');
  }

  async execute(): Promise<PollerResult> {
    const apiKey = process.env.SCRAPINGBEE_API_KEY;
    if (!apiKey) {
      this.logger.warn(
        'SCRAPINGBEE_API_KEY not set — calling Open-Meteo directly (may hit rate limits)',
      );
    }

    // Generate all CONUS grid points at 1-degree spacing
    const points: Array<{ lat: number; lng: number }> = [];
    for (let lat = LAT_MIN; lat <= LAT_MAX; lat++) {
      for (let lng = LNG_MIN; lng <= LNG_MAX; lng++) {
        points.push({ lat, lng });
      }
    }

    const model = WINDS.DEFAULT_MODEL;
    const endpoint =
      WINDS.MODEL_ENDPOINTS[model] || WINDS.MODEL_ENDPOINTS.gfs_seamless;

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

    let totalUpdated = 0;
    let errors = 0;
    let lastError = '';

    const batchSize = 50;
    const totalBatches = Math.ceil(points.length / batchSize);
    let currentDelay = BATCH_DELAY_MS;

    for (let i = 0; i < points.length; i += batchSize) {
      const batch = points.slice(i, i + batchSize);
      const batchNum = Math.floor(i / batchSize) + 1;

      // Wait between batches
      if (i > 0) {
        await new Promise((r) => setTimeout(r, currentDelay));
      }

      const result = await this.fetchBatchWithRetry(
        batch,
        endpoint,
        hourlyVars,
        model,
        batchNum,
        totalBatches,
        apiKey,
      );

      if (result.success) {
        totalUpdated += result.records;
        // Successful request — use normal delay
        currentDelay = BATCH_DELAY_MS;
      } else {
        errors++;
        lastError = result.error!;
        // After a failed batch (even after retries), increase delay
        // for subsequent batches to let rate limits cool down
        currentDelay = Math.min(currentDelay * 2, 60000);
        this.logger.warn(
          `Increasing batch delay to ${(currentDelay / 1000).toFixed(0)}s after failure`,
        );
      }
    }

    this.logger.log(
      `Wind grid: ${totalUpdated} points, ${errors} batch errors`,
    );
    return {
      recordsUpdated: totalUpdated,
      errors,
      lastError: lastError || undefined,
    };
  }

  private async fetchBatchWithRetry(
    batch: Array<{ lat: number; lng: number }>,
    endpoint: string,
    hourlyVars: string[],
    model: string,
    batchNum: number,
    totalBatches: number,
    apiKey?: string,
  ): Promise<{ success: boolean; records: number; error?: string }> {
    for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
      try {
        const records = await this.fetchBatch(
          batch,
          endpoint,
          hourlyVars,
          model,
          apiKey,
        );

        this.logger.log(
          `Wind grid batch ${batchNum}/${totalBatches}: ${records} points` +
            (attempt > 0 ? ` (retry ${attempt})` : ''),
        );
        return { success: true, records };
      } catch (error) {
        const status = error?.response?.status || 'N/A';
        const msg = `Batch ${batchNum}/${totalBatches} failed (HTTP ${status}): ${error.message}`;

        if (status === 429 && attempt < MAX_RETRIES) {
          // Respect Retry-After header if present, otherwise exponential backoff
          const retryAfter = error?.response?.headers?.['retry-after'];
          const backoffMs = retryAfter
            ? parseInt(retryAfter, 10) * 1000
            : BASE_BACKOFF_MS * Math.pow(2, attempt);
          this.logger.warn(
            `${msg} — retrying in ${(backoffMs / 1000).toFixed(0)}s (attempt ${attempt + 1}/${MAX_RETRIES})`,
          );
          await new Promise((r) => setTimeout(r, backoffMs));
          continue;
        }

        this.logger.error(msg);
        return { success: false, records: 0, error: msg };
      }
    }

    // Should not reach here, but satisfy TS
    return { success: false, records: 0, error: 'Max retries exceeded' };
  }

  private async fetchBatch(
    batch: Array<{ lat: number; lng: number }>,
    endpoint: string,
    hourlyVars: string[],
    model: string,
    apiKey?: string,
  ): Promise<number> {
    let data: any;

    if (apiKey) {
      // Route through ScrapingBee proxy to avoid Open-Meteo rate limits
      const targetParams = new URLSearchParams({
        latitude: batch.map((p) => p.lat.toFixed(2)).join(','),
        longitude: batch.map((p) => p.lng.toFixed(2)).join(','),
        hourly: hourlyVars.join(','),
        wind_speed_unit: 'kn',
        forecast_days: String(WINDS.FORECAST_DAYS),
        models: model,
      });
      const targetUrl = `${WINDS.API_BASE_URL}${endpoint}?${targetParams}`;

      const response = await firstValueFrom(
        this.http.get(SCRAPINGBEE_BASE, {
          params: {
            api_key: apiKey,
            url: targetUrl,
            render_js: 'false',
          },
          timeout: 90000,
          maxContentLength: 50 * 1024 * 1024,
          maxBodyLength: 50 * 1024 * 1024,
        }),
      );
      // ScrapingBee returns the target body — parse JSON if it came as string
      data =
        typeof response.data === 'string'
          ? JSON.parse(response.data)
          : response.data;
    } else {
      // Direct call (no proxy)
      const response = await firstValueFrom(
        this.http.get(`${WINDS.API_BASE_URL}${endpoint}`, {
          params: {
            latitude: batch.map((p) => p.lat.toFixed(2)).join(','),
            longitude: batch.map((p) => p.lng.toFixed(2)).join(','),
            hourly: hourlyVars.join(','),
            wind_speed_unit: 'kn',
            forecast_days: WINDS.FORECAST_DAYS,
            models: model,
          },
          timeout: 60000,
          maxContentLength: 50 * 1024 * 1024,
          maxBodyLength: 50 * 1024 * 1024,
        }),
      );
      data = response.data;
    }

    const hourlyResults: any[] = Array.isArray(data) ? data : [data];

    const records: WindGrid[] = [];
    for (let idx = 0; idx < batch.length; idx++) {
      const p = batch[idx];
      const hourly = hourlyResults[idx]?.hourly || hourlyResults[0]?.hourly;
      if (!hourly) continue;

      const times: string[] = hourly.time || [];
      const timestamps = times.map((t: string) => new Date(t + 'Z').getTime());

      // Build levels data structure (same as PointForecastResult.levels)
      const levels: any[] = [];

      // Surface level
      const surfWinds = timestamps.map((ts, ti) => ({
        timestamp: ts,
        direction: Math.round(hourly.wind_direction_10m?.[ti] ?? 0),
        speed: Math.round(hourly.wind_speed_10m?.[ti] ?? 0),
        temperature: Math.round((hourly.temperature_2m?.[ti] ?? 15) * 10) / 10,
      }));
      levels.push({ level: 'surface', altitudeFt: 0, winds: surfWinds });

      // Pressure levels
      for (const hPa of WINDS.PRESSURE_LEVELS) {
        const altFt = WINDS.LEVEL_ALTITUDES[hPa] || 0;
        const winds = timestamps.map((ts, ti) => ({
          timestamp: ts,
          direction: Math.round(hourly[`wind_direction_${hPa}hPa`]?.[ti] ?? 0),
          speed: Math.round(hourly[`wind_speed_${hPa}hPa`]?.[ti] ?? 0),
          temperature:
            Math.round((hourly[`temperature_${hPa}hPa`]?.[ti] ?? 0) * 10) / 10,
        }));
        levels.push({ level: `${hPa}hPa`, altitudeFt: altFt, winds });
      }

      const record = new WindGrid();
      record.lat = p.lat;
      record.lng = p.lng;
      record.model = model;
      record.levels = levels;
      records.push(record);
    }

    if (records.length > 0) {
      // Upsert in chunks within a transaction to prevent spatial seams
      const chunkSize = 50;
      await this.windGridRepo.manager.transaction(async (em) => {
        for (let ci = 0; ci < records.length; ci += chunkSize) {
          const chunk = records.slice(ci, ci + chunkSize);
          await em.upsert(WindGrid, chunk, ['lat', 'lng', 'model']);
        }
      });
    }

    return records.length;
  }
}
