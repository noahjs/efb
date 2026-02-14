import { Injectable } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { firstValueFrom } from 'rxjs';
import { BasePoller, PollerResult } from './base.poller';
import { LightningThreat } from '../entities/lightning-threat.entity';
import { XWEATHER } from '../../config/constants';

@Injectable()
export class LightningThreatPoller extends BasePoller {
  constructor(
    private readonly http: HttpService,
    @InjectRepository(LightningThreat)
    private readonly lightningRepo: Repository<LightningThreat>,
  ) {
    super('LightningThreatPoller');
  }

  async execute(): Promise<PollerResult> {
    const batchId = `batch-${Date.now()}`;
    const clientId = process.env.XWEATHER_CLIENT_ID;
    const clientSecret = process.env.XWEATHER_CLIENT_SECRET;

    if (!clientId || !clientSecret) {
      this.logger.warn('XWEATHER_CLIENT_ID or XWEATHER_CLIENT_SECRET not set');
      return { recordsUpdated: 0, errors: 1, lastError: 'Missing Xweather credentials' };
    }

    const { data } = await firstValueFrom(
      this.http.get(`${XWEATHER.API_BASE_URL}/lightning/threats`, {
        params: {
          action: 'within',
          p: XWEATHER.CONUS_BOUNDS,
          limit: 500,
          client_id: clientId,
          client_secret: clientSecret,
        },
        timeout: XWEATHER.TIMEOUT_MS,
      }),
    );

    if (!data?.success || !data?.response) {
      this.logger.warn('Xweather lightning/threats returned no data');
      return { recordsUpdated: 0, errors: 0 };
    }

    const threats: LightningThreat[] = [];
    for (const item of data.response) {
      const threat = new LightningThreat();
      threat.severity = item.threats?.phrase ?? item.severity ?? null;

      // Threat area as Polygon
      if (item.geoPoly?.length > 0) {
        const polyCoords = item.geoPoly
          .map((pt: any) => [pt.long ?? pt.lon, pt.lat])
          .filter((c: any) => c[0] != null && c[1] != null);
        if (polyCoords.length >= 3) {
          polyCoords.push(polyCoords[0]); // close ring
          threat.geometry = {
            type: 'Polygon',
            coordinates: [polyCoords],
          };
        }
      }

      // Forecast path as LineString
      if (item.forecast?.length > 0) {
        const pathCoords = item.forecast
          .map((f: any) => [f.loc?.long ?? f.loc?.lon, f.loc?.lat])
          .filter((c: any) => c[0] != null && c[1] != null);
        if (pathCoords.length >= 2) {
          threat.forecast_path = {
            type: 'LineString',
            coordinates: pathCoords,
          };
        }
      }

      threat.properties = {
        direction: item.direction ?? null,
        speed: item.speed ?? null,
        strikesPerMin: item.strikesPerMin ?? null,
        threats: item.threats ?? null,
      };

      threat.poll_batch_id = batchId;
      threats.push(threat);
    }

    // Full replace in a transaction
    await this.lightningRepo.manager.transaction(async (em) => {
      await em.query('DELETE FROM a_lightning_threats');
      if (threats.length > 0) {
        await em.save(LightningThreat, threats);
      }
    });

    this.logger.log(`Lightning threats: ${threats.length} saved`);
    return { recordsUpdated: threats.length, errors: 0 };
  }
}
