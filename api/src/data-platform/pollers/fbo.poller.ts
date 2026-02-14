import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull } from 'typeorm';
import { BasePoller, PollerResult } from './base.poller';
import { Airport } from '../../airports/entities/airport.entity';
import { Fbo } from '../../fbos/entities/fbo.entity';
import { FuelPrice } from '../../fbos/entities/fuel-price.entity';
import { FBO } from '../../config/constants';
import { scrapeAndUpsertAirport, sleep } from './fbo-scrape.utils';
import { CycleQueryHelper } from '../../data-cycle/cycle-query.helper';
import { CycleDataGroup } from '../../data-cycle/entities/data-cycle.entity';

@Injectable()
export class FboPoller extends BasePoller {
  constructor(
    @InjectRepository(Airport)
    private readonly airportRepo: Repository<Airport>,
    @InjectRepository(Fbo)
    private readonly fboRepo: Repository<Fbo>,
    @InjectRepository(FuelPrice)
    private readonly fuelPriceRepo: Repository<FuelPrice>,
    private readonly cycleHelper: CycleQueryHelper,
  ) {
    super('FboPoller');
  }

  async execute(): Promise<PollerResult> {
    // Scrape airports that have never been scraped
    const cycleWhere = await this.cycleHelper.getCycleWhere(CycleDataGroup.NASR);
    const airports = await this.airportRepo.find({
      where: { fbo_scraped_at: IsNull(), ...cycleWhere },
      order: { identifier: 'ASC' },
    });

    if (airports.length === 0) {
      this.logger.log('FBO crawl: all airports already scraped, nothing to do');
      return { recordsUpdated: 0, errors: 0 };
    }

    this.logger.log(
      `FBO crawl: ${airports.length} unscraped airports to process`,
    );

    let recordsUpdated = 0;
    let errors = 0;
    let lastError = '';

    for (let i = 0; i < airports.length; i++) {
      const airport = airports[i];

      try {
        const result = await scrapeAndUpsertAirport(
          airport,
          this.fboRepo,
          this.fuelPriceRepo,
          this.airportRepo,
        );
        recordsUpdated += result.fbos + result.prices;
      } catch (err: any) {
        errors++;
        lastError = `${airport.identifier}: ${err.message}`;
        this.logger.warn(lastError);
      }

      // Rate limiting between requests
      if (i < airports.length - 1) {
        await sleep(FBO.SCRAPE_DELAY_MS);
      }

      // Log progress every 100 airports
      if ((i + 1) % 100 === 0) {
        this.logger.log(
          `FBO crawl progress: ${i + 1}/${airports.length} airports, ${recordsUpdated} records, ${errors} errors`,
        );
      }
    }

    this.logger.log(
      `FBO crawl complete: ${recordsUpdated} records from ${airports.length} airports, ${errors} errors`,
    );

    return {
      recordsUpdated,
      errors,
      lastError: lastError || undefined,
    };
  }
}
