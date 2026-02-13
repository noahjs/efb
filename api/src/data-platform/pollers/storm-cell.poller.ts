import { Injectable } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { firstValueFrom } from 'rxjs';
import { BasePoller, PollerResult } from './base.poller';
import { StormCell } from '../entities/storm-cell.entity';
import { XWEATHER } from '../../config/constants';

@Injectable()
export class StormCellPoller extends BasePoller {
  constructor(
    private readonly http: HttpService,
    @InjectRepository(StormCell)
    private readonly stormCellRepo: Repository<StormCell>,
  ) {
    super('StormCellPoller');
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
      this.http.get(`${XWEATHER.API_BASE_URL}/stormcells`, {
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
      this.logger.warn('Xweather stormcells returned no data');
      return { recordsUpdated: 0, errors: 0 };
    }

    const cells: StormCell[] = [];
    for (const item of data.response) {
      const loc = item.loc;
      if (!loc?.lat || !loc?.long) continue;

      const cell = new StormCell();
      cell.cell_id = item.id ?? `${loc.lat}_${loc.long}`;
      cell.latitude = loc.lat;
      cell.longitude = loc.long;

      // Determine primary trait
      const traits: string[] = item.traits ?? [];
      if (traits.includes('tornado')) {
        cell.trait = 'tornado';
      } else if (traits.includes('rotating')) {
        cell.trait = 'rotating';
      } else if (traits.includes('hail')) {
        cell.trait = 'hail';
      } else {
        cell.trait = 'general';
      }

      // Point geometry
      cell.geometry = {
        type: 'Point',
        coordinates: [loc.long, loc.lat],
      };

      // Forecast track as LineString
      if (item.forecast?.length > 0) {
        const trackCoords = [
          [loc.long, loc.lat],
          ...item.forecast.map((f: any) => [f.loc?.long, f.loc?.lat]).filter(
            (c: any) => c[0] != null && c[1] != null,
          ),
        ];
        if (trackCoords.length >= 2) {
          cell.forecast_track = {
            type: 'LineString',
            coordinates: trackCoords,
          };
        }
      }

      // Forecast cone as Polygon (if errorCone provided)
      if (item.forecast?.length > 0) {
        const coneCoords: [number, number][] = [];
        for (const f of item.forecast) {
          if (f.errorCone?.length > 0) {
            for (const pt of f.errorCone) {
              if (pt.lat != null && pt.long != null) {
                coneCoords.push([pt.long, pt.lat]);
              }
            }
          }
        }
        if (coneCoords.length >= 3) {
          // Close the ring
          coneCoords.push(coneCoords[0]);
          cell.forecast_cone = {
            type: 'Polygon',
            coordinates: [coneCoords],
          };
        }
      }

      // Store relevant properties
      cell.properties = {
        movement: item.movement ?? null,
        hail: item.hail ?? null,
        tvs: item.tvs ?? null,
        mda: item.mda ?? null,
        dbzm: item.dbzm ?? null,
        traits,
      };

      cell.poll_batch_id = batchId;
      cells.push(cell);
    }

    // Full replace in a transaction
    await this.stormCellRepo.manager.transaction(async (em) => {
      await em.createQueryBuilder().delete().from(StormCell).execute();
      if (cells.length > 0) {
        await em.save(StormCell, cells);
      }
    });

    this.logger.log(`Storm cells: ${cells.length} saved`);
    return { recordsUpdated: cells.length, errors: 0 };
  }
}
