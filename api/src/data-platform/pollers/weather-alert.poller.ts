import { Injectable } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { firstValueFrom } from 'rxjs';
import { BasePoller, PollerResult } from './base.poller';
import { WeatherAlert } from '../entities/weather-alert.entity';
import { WEATHER } from '../../config/constants';

@Injectable()
export class WeatherAlertPoller extends BasePoller {
  constructor(
    private readonly http: HttpService,
    @InjectRepository(WeatherAlert)
    private readonly alertRepo: Repository<WeatherAlert>,
  ) {
    super('WeatherAlertPoller');
  }

  async execute(): Promise<PollerResult> {
    const { data } = await firstValueFrom(
      this.http.get('https://api.weather.gov/alerts/active', {
        params: {
          status: 'actual',
          message_type: 'alert',
        },
        headers: {
          'User-Agent': WEATHER.NWS_USER_AGENT,
          Accept: 'application/geo+json',
        },
        timeout: 30_000,
      }),
    );

    const features: any[] = data?.features ?? [];

    // Filter out features with null geometry (zone-based alerts)
    const alerts: WeatherAlert[] = [];
    for (const f of features) {
      if (!f.geometry) continue;

      const props = f.properties ?? {};
      const alert = new WeatherAlert();
      alert.alert_id = props.id ?? `nws-${Date.now()}-${alerts.length}`;
      alert.event = props.event ?? null;
      alert.severity = props.severity ?? null;
      alert.urgency = props.urgency ?? null;
      alert.certainty = props.certainty ?? null;
      alert.headline = props.headline ?? null;
      alert.description = props.description ?? null;
      alert.effective = props.effective ? new Date(props.effective) : null;
      alert.expires = props.expires ? new Date(props.expires) : null;
      alert.geometry = f.geometry;
      alert.properties = {
        sender: props.senderName ?? null,
        areaDesc: props.areaDesc ?? null,
        category: props.category ?? null,
        response: props.response ?? null,
      };
      alerts.push(alert);
    }

    // Full replace in a transaction
    await this.alertRepo.manager.transaction(async (em) => {
      await em.query('DELETE FROM a_weather_alerts');
      if (alerts.length > 0) {
        // Save in batches to avoid parameter limit
        const batchSize = 500;
        for (let i = 0; i < alerts.length; i += batchSize) {
          await em.save(WeatherAlert, alerts.slice(i, i + batchSize));
        }
      }
    });

    this.logger.log(
      `Weather alerts: ${alerts.length} saved (${features.length - alerts.length} skipped — no geometry)`,
    );
    return { recordsUpdated: alerts.length, errors: 0 };
  }
}
