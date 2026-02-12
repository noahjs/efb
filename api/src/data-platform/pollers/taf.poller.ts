import { Injectable } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { firstValueFrom } from 'rxjs';
import { BasePoller } from './base.poller';
import { Taf } from '../entities/taf.entity';
import { WEATHER } from '../../config/constants';

@Injectable()
export class TafPoller extends BasePoller {
  constructor(
    private readonly http: HttpService,
    @InjectRepository(Taf)
    private readonly tafRepo: Repository<Taf>,
  ) {
    super('TafPoller');
  }

  async execute(): Promise<number> {
    // Fetch all TAFs for CONUS using a bounding box
    const { data } = await firstValueFrom(
      this.http.get(`${WEATHER.AWC_BASE_URL}/taf`, {
        params: {
          bbox: '20,-130,55,-60',
          format: 'json',
        },
        timeout: 30000,
      }),
    );

    const all = Array.isArray(data) ? data : [];

    const tafs: Taf[] = all
      .filter((t: any) => t.icaoId)
      .map((t: any) => {
        const taf = new Taf();
        taf.icao_id = t.icaoId;
        taf.latitude = t.lat ?? null;
        taf.longitude = t.lon ?? null;
        taf.raw_taf = t.rawTAF ?? null;
        taf.fcsts = t.fcsts ?? null;
        taf.raw_data = t;
        return taf;
      });

    if (tafs.length > 0) {
      await this.tafRepo.upsert(tafs, ['icao_id']);
    }

    this.logger.log(`TAFs: ${tafs.length} stations`);
    return tafs.length;
  }
}
