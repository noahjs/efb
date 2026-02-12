import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, LessThan } from 'typeorm';
import { DATA_PLATFORM } from '../config/constants';
import { Metar } from './entities/metar.entity';
import { Taf } from './entities/taf.entity';
import { WindsAloft } from './entities/winds-aloft.entity';
import { Notam } from './entities/notam.entity';
import { NwsForecast } from './entities/nws-forecast.entity';
import { WindGrid } from './entities/wind-grid.entity';

@Injectable()
export class DataCleanupService {
  private readonly logger = new Logger(DataCleanupService.name);

  constructor(
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
    @InjectRepository(WindGrid)
    private readonly windGridRepo: Repository<WindGrid>,
  ) {}

  async cleanup(): Promise<void> {
    const thresholds = DATA_PLATFORM.STALE_THRESHOLDS;
    const now = Date.now();

    const results = await Promise.allSettled([
      this.deleteStale('Metar', this.metarRepo, now - thresholds.METAR_MS),
      this.deleteStale('Taf', this.tafRepo, now - thresholds.TAF_MS),
      this.deleteStale(
        'WindsAloft',
        this.windsAloftRepo,
        now - thresholds.WINDS_ALOFT_MS,
      ),
      this.deleteStale('Notam', this.notamRepo, now - thresholds.NOTAM_MS),
      this.deleteStale(
        'NwsForecast',
        this.nwsForecastRepo,
        now - thresholds.NWS_FORECAST_MS,
      ),
      this.deleteStale(
        'WindGrid',
        this.windGridRepo,
        now - thresholds.WIND_GRID_MS,
      ),
    ]);

    for (const result of results) {
      if (result.status === 'rejected') {
        this.logger.error(`Cleanup error: ${result.reason}`);
      }
    }
  }

  private async deleteStale(
    name: string,
    repo: Repository<any>,
    cutoffMs: number,
  ): Promise<void> {
    const cutoff = new Date(cutoffMs);
    const result = await repo.delete({ updated_at: LessThan(cutoff) });
    if ((result.affected ?? 0) > 0) {
      this.logger.log(`Cleaned ${result.affected} stale ${name} rows`);
    }
  }
}
