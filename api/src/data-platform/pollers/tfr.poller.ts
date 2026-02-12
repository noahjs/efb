import { Injectable } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { firstValueFrom } from 'rxjs';
import { BasePoller } from './base.poller';
import { Tfr } from '../entities/tfr.entity';
import { IMAGERY } from '../../config/constants';
import { parseTfrWebText } from '../utils/tfr-parser.util';

@Injectable()
export class TfrPoller extends BasePoller {
  constructor(
    private readonly http: HttpService,
    @InjectRepository(Tfr)
    private readonly tfrRepo: Repository<Tfr>,
  ) {
    super('TfrPoller');
  }

  async execute(): Promise<number> {
    // Fetch WFS polygons and metadata list in parallel
    const [wfsResponse, listResponse] = await Promise.all([
      firstValueFrom(
        this.http.get(`${IMAGERY.TFR_BASE_URL}/geoserver/TFR/ows`, {
          params: {
            service: 'WFS',
            version: '1.1.0',
            request: 'GetFeature',
            typeName: 'TFR:V_TFR_LOC',
            maxFeatures: 300,
            outputFormat: 'application/json',
            srsname: 'EPSG:4326',
          },
          timeout: IMAGERY.TIMEOUT_TFR_WFS_MS,
        }),
      ),
      firstValueFrom(
        this.http.get(`${IMAGERY.TFR_BASE_URL}/tfrapi/getTfrList`, {
          timeout: IMAGERY.TIMEOUT_TFR_LIST_MS,
        }),
      ).catch(() => ({ data: [] })),
    ]);

    const wfsFeatures: any[] = wfsResponse.data?.features ?? [];
    const listData: any[] = Array.isArray(listResponse.data)
      ? listResponse.data
      : [];

    // Build metadata lookup
    const listMap = new Map<string, any>();
    for (const entry of listData) {
      if (entry.notam_id) listMap.set(entry.notam_id, entry);
    }

    // Collect unique NOTAM IDs
    const notamIds = new Set<string>();
    for (const feature of wfsFeatures) {
      const notamKey = feature.properties?.NOTAM_KEY ?? '';
      const notamId = notamKey.split('-')[0];
      if (notamId) notamIds.add(notamId);
    }

    // Batch fetch web text
    const webTextMap = new Map<string, Record<string, string>>();
    const ids = Array.from(notamIds);
    const batchSize = IMAGERY.TFR_BATCH_SIZE;
    for (let i = 0; i < ids.length; i += batchSize) {
      const batch = ids.slice(i, i + batchSize);
      const results = await Promise.allSettled(
        batch.map((id) =>
          firstValueFrom(
            this.http.get(`${IMAGERY.TFR_BASE_URL}/tfrapi/getWebText`, {
              params: { notamId: id },
              timeout: IMAGERY.TIMEOUT_TFR_TEXT_MS,
            }),
          ),
        ),
      );
      for (let j = 0; j < batch.length; j++) {
        const result = results[j];
        if (result.status === 'fulfilled' && Array.isArray(result.value.data)) {
          const html = result.value.data[0]?.text ?? '';
          webTextMap.set(batch[j], parseTfrWebText(html));
        }
      }
    }

    // Build TFR entities — group features by notam_id (multiple polygons per TFR)
    const tfrMap = new Map<string, Tfr>();
    for (const feature of wfsFeatures) {
      const props = feature.properties ?? {};
      const notamKey = props.NOTAM_KEY ?? '';
      const notamId = notamKey.split('-')[0];
      if (!notamId) continue;

      const meta = listMap.get(notamId);
      const webText = webTextMap.get(notamId) ?? {};

      if (!tfrMap.has(notamId)) {
        const tfr = new Tfr();
        tfr.notam_id = notamId;
        tfr.type = props.LEGAL ?? meta?.type ?? null;
        tfr.state = props.STATE ?? meta?.state ?? null;
        tfr.facility = props.CNS_LOCATION_ID ?? meta?.facility ?? null;
        tfr.description = meta?.description ?? props.TITLE ?? null;
        tfr.effective_start = webText.effectiveStart ?? null;
        tfr.effective_end = webText.effectiveEnd ?? null;
        tfr.altitude = webText.altitude ?? null;
        tfr.reason = webText.reason ?? null;
        tfr.notam_text = webText.notamText ?? null;
        tfr.geometry = feature.geometry ?? null;
        tfr.properties = {
          title: props.TITLE,
          color: '#FF5252',
          location: webText.location ?? '',
        };
        tfrMap.set(notamId, tfr);
      }
    }

    const tfrs = Array.from(tfrMap.values());

    // Upsert TFRs, remove any that are no longer active
    if (tfrs.length > 0) {
      await this.tfrRepo.manager.transaction(async (em) => {
        await em.delete(Tfr, {});
        await em.save(Tfr, tfrs);
      });
    } else {
      await this.tfrRepo.delete({});
    }

    this.logger.log(`TFRs: ${tfrs.length} active`);
    return tfrs.length;
  }
}
