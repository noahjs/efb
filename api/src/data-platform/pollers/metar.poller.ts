import { Injectable } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { firstValueFrom } from 'rxjs';
import { BasePoller } from './base.poller';
import { Metar } from '../entities/metar.entity';
import { WEATHER } from '../../config/constants';

// US state abbreviations for per-state AWC queries
const US_STATES = [
  'AL',
  'AK',
  'AZ',
  'AR',
  'CA',
  'CO',
  'CT',
  'DE',
  'FL',
  'GA',
  'HI',
  'ID',
  'IL',
  'IN',
  'IA',
  'KS',
  'KY',
  'LA',
  'ME',
  'MD',
  'MA',
  'MI',
  'MN',
  'MS',
  'MO',
  'MT',
  'NE',
  'NV',
  'NH',
  'NJ',
  'NM',
  'NY',
  'NC',
  'ND',
  'OH',
  'OK',
  'OR',
  'PA',
  'RI',
  'SC',
  'SD',
  'TN',
  'TX',
  'UT',
  'VT',
  'VA',
  'WA',
  'WV',
  'WI',
  'WY',
];

@Injectable()
export class MetarPoller extends BasePoller {
  constructor(
    private readonly http: HttpService,
    @InjectRepository(Metar)
    private readonly metarRepo: Repository<Metar>,
  ) {
    super('MetarPoller');
  }

  async execute(): Promise<number> {
    let totalUpdated = 0;

    // Process states in batches of 6 to avoid overwhelming AWC
    const batchSize = 6;
    for (let i = 0; i < US_STATES.length; i += batchSize) {
      const batch = US_STATES.slice(i, i + batchSize);
      const results = await Promise.allSettled(
        batch.map((state) => this.fetchState(state)),
      );

      for (const result of results) {
        if (result.status === 'fulfilled') {
          totalUpdated += result.value;
        }
      }
    }

    this.logger.log(`METARs: ${totalUpdated} stations updated`);
    return totalUpdated;
  }

  private async fetchState(state: string): Promise<number> {
    try {
      const { data } = await firstValueFrom(
        this.http.get(`${WEATHER.AWC_BASE_URL}/metar`, {
          params: {
            ids: `@${state}`,
            format: 'json',
            hours: 3,
          },
          timeout: WEATHER.TIMEOUT_BULK_METAR_MS,
        }),
      );

      const all = Array.isArray(data) ? data : [];

      // Deduplicate — keep most recent per station
      const latest = new Map<string, any>();
      for (const m of all) {
        const id = m.icaoId;
        if (!id) continue;
        const existing = latest.get(id);
        if (!existing || (m.obsTime ?? 0) > (existing.obsTime ?? 0)) {
          latest.set(id, m);
        }
      }

      const metars: Metar[] = [];
      for (const [icaoId, m] of latest) {
        const metar = new Metar();
        metar.icao_id = icaoId;
        metar.latitude = m.lat ?? null;
        metar.longitude = m.lon ?? null;
        metar.raw_ob = m.rawOb ?? null;
        metar.flight_category = m.fltCat ?? null;
        metar.temp = m.temp ?? null;
        metar.dewp = m.dewp ?? null;
        metar.wdir = m.wdir ?? null;
        metar.wspd = m.wspd ?? null;
        metar.wgst = m.wgst ?? null;
        metar.visib = typeof m.visib === 'number' ? m.visib : null;
        metar.altim = m.altim ?? null;
        metar.clouds = m.clouds ?? null;
        metar.obs_time = m.obsTime ?? null;
        metar.report_time = m.reportTime ?? null;
        metar.raw_data = m;
        metars.push(metar);
      }

      if (metars.length > 0) {
        await this.metarRepo.upsert(metars, ['icao_id']);
      }

      return metars.length;
    } catch (error) {
      this.logger.warn(
        `Failed to fetch METARs for @${state}: ${error.message}`,
      );
      return 0;
    }
  }
}
