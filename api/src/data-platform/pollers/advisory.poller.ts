import { Injectable } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { firstValueFrom } from 'rxjs';
import { BasePoller } from './base.poller';
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

  async execute(): Promise<number> {
    const batchId = `batch-${Date.now()}`;

    // Fetch all 3 advisory types in parallel
    const [gairmets, sigmets, cwas] = await Promise.all([
      this.fetchAdvisories('gairmet', 'gairmet'),
      this.fetchAdvisories('airsigmet', 'sigmet'),
      this.fetchAdvisories('cwa', 'cwa'),
    ]);

    const all = [...gairmets, ...sigmets, ...cwas];

    // Assign batch ID to all
    for (const adv of all) {
      adv.poll_batch_id = batchId;
    }

    // Full replace in a transaction
    await this.advisoryRepo.manager.transaction(async (em) => {
      await em.delete(Advisory, {});
      if (all.length > 0) {
        await em.save(Advisory, all);
      }
    });

    this.logger.log(
      `Advisories: ${gairmets.length} GAIRMETs, ${sigmets.length} SIGMETs, ${cwas.length} CWAs`,
    );
    return all.length;
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
