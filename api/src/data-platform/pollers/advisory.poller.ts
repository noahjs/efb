import { Injectable } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { firstValueFrom } from 'rxjs';
import { BasePoller, PollerResult } from './base.poller';
import { Advisory } from '../entities/advisory.entity';
import { IMAGERY } from '../../config/constants';

@Injectable()
export class AdvisoryPoller extends BasePoller {
  constructor(
    private readonly http: HttpService,
    @InjectRepository(Advisory)
    private readonly advisoryRepo: Repository<Advisory>,
  ) {
    super('AdvisoryPoller');
  }

  async execute(): Promise<PollerResult> {
    const batchId = `batch-${Date.now()}`;

    // Fetch all 3 advisory types in parallel
    const results = await Promise.allSettled([
      this.fetchAdvisories('gairmet', 'gairmet'),
      this.fetchAdvisories('airsigmet', 'sigmet'),
      this.fetchAdvisories('cwa', 'cwa'),
    ]);

    const labels = ['gairmet', 'sigmet', 'cwa'];
    const fetched: Advisory[][] = [];
    let errors = 0;
    let lastError = '';
    for (let i = 0; i < results.length; i++) {
      const r = results[i];
      if (r.status === 'fulfilled') {
        fetched.push(r.value);
      } else {
        errors++;
        lastError = `${labels[i]}: ${r.reason?.message ?? r.reason}`;
        fetched.push([]);
      }
    }

    const [gairmets, sigmets, cwas] = fetched;
    const all = [...gairmets, ...sigmets, ...cwas];

    // Assign batch ID to all
    for (const adv of all) {
      adv.poll_batch_id = batchId;
    }

    // Full replace in a transaction
    await this.advisoryRepo.manager.transaction(async (em) => {
      await em.createQueryBuilder().delete().from(Advisory).execute();
      if (all.length > 0) {
        await em.save(Advisory, all);
      }
    });

    this.logger.log(
      `Advisories: ${gairmets.length} GAIRMETs, ${sigmets.length} SIGMETs, ${cwas.length} CWAs`,
    );
    return { recordsUpdated: all.length, errors, lastError: lastError || undefined };
  }

  private async fetchAdvisories(
    endpoint: string,
    type: string,
  ): Promise<Advisory[]> {
    try {
      const { data } = await firstValueFrom(
        this.http.get(`${IMAGERY.AWC_BASE_URL}/api/data/${endpoint}`, {
          params: { format: 'geojson' },
        }),
      );

      const features: any[] = data?.features ?? [];
      return features.map((f) => {
        const props = f.properties ?? {};
        const adv = new Advisory();
        adv.type = type;
        adv.hazard = props.hazard ?? props.airSigmetType ?? null;
        adv.severity = props.severity ?? null;
        adv.raw_text = props.rawAirSigmet ?? props.rawText ?? null;
        adv.valid_time_from = props.validTimeFrom
          ? new Date(props.validTimeFrom)
          : null;
        adv.valid_time_to = props.validTimeTo
          ? new Date(props.validTimeTo)
          : null;
        adv.geometry = f.geometry ?? null;
        adv.properties = props;
        return adv;
      });
    } catch (error) {
      this.logger.error(`Failed to fetch ${endpoint}: ${error.message}`);
      return [];
    }
  }
}
