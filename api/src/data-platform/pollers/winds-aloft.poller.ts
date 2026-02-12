import { Injectable } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { firstValueFrom } from 'rxjs';
import { BasePoller } from './base.poller';
import { WindsAloft } from '../entities/winds-aloft.entity';
import { WEATHER } from '../../config/constants';
import { parseWindsAloftText } from '../utils/winds-parser.util';

const FORECAST_PERIODS = [
  { fcst: '06', label: '6-hour' },
  { fcst: '12', label: '12-hour' },
  { fcst: '24', label: '24-hour' },
];

@Injectable()
export class WindsAloftPoller extends BasePoller {
  constructor(
    private readonly http: HttpService,
    @InjectRepository(WindsAloft)
    private readonly windsRepo: Repository<WindsAloft>,
  ) {
    super('WindsAloftPoller');
  }

  async execute(): Promise<number> {
    let totalUpdated = 0;

    for (const period of FORECAST_PERIODS) {
      const count = await this.fetchPeriod(period.fcst);
      totalUpdated += count;
    }

    this.logger.log(`Winds aloft: ${totalUpdated} station-periods`);
    return totalUpdated;
  }

  private async fetchPeriod(fcst: string): Promise<number> {
    try {
      // Fetch low and high altitude winds in parallel
      const [lowRes, highRes] = await Promise.all([
        firstValueFrom(
          this.http.get(`${WEATHER.AWC_BASE_URL}/windtemp`, {
            params: { region: 'us', level: 'low', fcst },
            responseType: 'text',
            transformResponse: [(d: any) => d],
          }),
        ),
        firstValueFrom(
          this.http.get(`${WEATHER.AWC_BASE_URL}/windtemp`, {
            params: { region: 'us', level: 'high', fcst },
            responseType: 'text',
            transformResponse: [(d: any) => d],
          }),
        ).catch(() => null),
      ]);

      const lowParsed = parseWindsAloftText(lowRes.data as string);

      // Merge high-altitude data
      if (highRes) {
        const highParsed = parseWindsAloftText(highRes.data as string);
        for (const [station, highAlts] of highParsed) {
          const lowAlts = lowParsed.get(station) ?? [];
          const existingAltitudes = new Set(lowAlts.map((a) => a.altitude));
          const merged = [
            ...lowAlts,
            ...highAlts.filter((a) => !existingAltitudes.has(a.altitude)),
          ].sort((a, b) => a.altitude - b.altitude);
          lowParsed.set(station, merged);
        }
      }

      // Upsert all stations for this period
      const records: WindsAloft[] = [];
      for (const [stationCode, altitudes] of lowParsed) {
        const record = new WindsAloft();
        record.station_code = stationCode;
        record.forecast_period = fcst;
        record.altitudes = altitudes;
        records.push(record);
      }

      if (records.length > 0) {
        // Batch upsert in chunks to avoid parameter limits
        const chunkSize = 100;
        for (let i = 0; i < records.length; i += chunkSize) {
          const chunk = records.slice(i, i + chunkSize);
          await this.windsRepo.upsert(chunk, [
            'station_code',
            'forecast_period',
          ]);
        }
      }

      return records.length;
    } catch (error) {
      this.logger.error(
        `Failed to fetch winds aloft for fcst=${fcst}: ${error.message}`,
      );
      return 0;
    }
  }
}
