import { Injectable } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { firstValueFrom } from 'rxjs';
import { BasePoller } from './base.poller';
import { WindGrid } from '../entities/wind-grid.entity';
import { WINDS } from '../../config/constants';

// CONUS bounds at 1-degree spacing
const LAT_MIN = 24;
const LAT_MAX = 50;
const LNG_MIN = -125;
const LNG_MAX = -66;

@Injectable()
export class WindGridPoller extends BasePoller {
  constructor(
    private readonly http: HttpService,
    @InjectRepository(WindGrid)
    private readonly windGridRepo: Repository<WindGrid>,
  ) {
    super('WindGridPoller');
  }

  async execute(): Promise<number> {
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

    // Batch API calls (Open-Meteo supports up to ~250 coords per request)
    const batchSize = 250;
    for (let i = 0; i < points.length; i += batchSize) {
      const batch = points.slice(i, i + batchSize);

      try {
        const { data } = await firstValueFrom(
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
          }),
        );

        const hourlyResults: any[] = Array.isArray(data) ? data : [data];

        const records: WindGrid[] = [];
        for (let idx = 0; idx < batch.length; idx++) {
          const p = batch[idx];
          const hourly = hourlyResults[idx]?.hourly || hourlyResults[0]?.hourly;
          if (!hourly) continue;

          const times: string[] = hourly.time || [];
          const timestamps = times.map((t: string) =>
            new Date(t + 'Z').getTime(),
          );

          // Build levels data structure (same as PointForecastResult.levels)
          const levels: any[] = [];

          // Surface level
          const surfWinds = timestamps.map((ts, ti) => ({
            timestamp: ts,
            direction: Math.round(hourly.wind_direction_10m?.[ti] ?? 0),
            speed: Math.round(hourly.wind_speed_10m?.[ti] ?? 0),
            temperature:
              Math.round((hourly.temperature_2m?.[ti] ?? 15) * 10) / 10,
          }));
          levels.push({ level: 'surface', altitudeFt: 0, winds: surfWinds });

          // Pressure levels
          for (const hPa of WINDS.PRESSURE_LEVELS) {
            const altFt = WINDS.LEVEL_ALTITUDES[hPa] || 0;
            const winds = timestamps.map((ts, ti) => ({
              timestamp: ts,
              direction: Math.round(
                hourly[`wind_direction_${hPa}hPa`]?.[ti] ?? 0,
              ),
              speed: Math.round(hourly[`wind_speed_${hPa}hPa`]?.[ti] ?? 0),
              temperature:
                Math.round((hourly[`temperature_${hPa}hPa`]?.[ti] ?? 0) * 10) /
                10,
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
          // Upsert in chunks
          const chunkSize = 50;
          for (let ci = 0; ci < records.length; ci += chunkSize) {
            const chunk = records.slice(ci, ci + chunkSize);
            await this.windGridRepo.upsert(chunk, ['lat', 'lng', 'model']);
          }
        }

        totalUpdated += records.length;
        this.logger.log(
          `Wind grid batch ${Math.floor(i / batchSize) + 1}/${Math.ceil(points.length / batchSize)}: ${records.length} points`,
        );
      } catch (error) {
        this.logger.error(
          `Wind grid batch ${Math.floor(i / batchSize) + 1} failed: ${error.message}`,
        );
      }
    }

    this.logger.log(`Wind grid: ${totalUpdated} total points`);
    return totalUpdated;
  }
}
