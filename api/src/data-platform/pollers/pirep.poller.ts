import { Injectable } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { firstValueFrom } from 'rxjs';
import { BasePoller } from './base.poller';
import { Pirep } from '../entities/pirep.entity';
import { IMAGERY } from '../../config/constants';

@Injectable()
export class PirepPoller extends BasePoller {
  constructor(
    private readonly http: HttpService,
    @InjectRepository(Pirep)
    private readonly pirepRepo: Repository<Pirep>,
  ) {
    super('PirepPoller');
  }

  async execute(): Promise<number> {
    const { data } = await firstValueFrom(
      this.http.get(`${IMAGERY.AWC_BASE_URL}/api/data/pirep`, {
        params: {
          format: 'geojson',
          bbox: IMAGERY.PIREP_DEFAULT_BBOX,
          age: IMAGERY.PIREP_DEFAULT_AGE_HOURS,
        },
      }),
    );

    const features: any[] = data?.features ?? [];

    const pireps = features.map((f) => {
      const props = f.properties ?? {};
      const coords = f.geometry?.coordinates;
      const p = new Pirep();
      p.raw_ob = props.rawOb ?? null;
      p.icao_id = props.icaoId ?? null;
      p.latitude = coords?.[1] ?? null;
      p.longitude = coords?.[0] ?? null;
      p.flight_level = props.fltlvl ?? null;
      p.aircraft_type = props.acType ?? null;
      p.report_type = props.pirepType ?? null;
      p.obs_time = props.obsTime ? new Date(props.obsTime * 1000) : null;
      p.properties = props;
      p.geometry = f.geometry ?? null;
      return p;
    });

    // Full replace
    await this.pirepRepo.manager.transaction(async (em) => {
      await em.delete(Pirep, {});
      if (pireps.length > 0) {
        await em.save(Pirep, pireps);
      }
    });

    this.logger.log(`PIREPs: ${pireps.length} records`);
    return pireps.length;
  }
}
