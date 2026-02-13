import { Injectable } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource as TypeOrmDataSource } from 'typeorm';
import { firstValueFrom } from 'rxjs';
import { BasePoller, PollerResult } from './base.poller';
import { Notam } from '../entities/notam.entity';
import { WEATHER } from '../../config/constants';

@Injectable()
export class NotamPoller extends BasePoller {
  constructor(
    private readonly http: HttpService,
    @InjectRepository(Notam)
    private readonly notamRepo: Repository<Notam>,
    @InjectDataSource()
    private readonly dataSource: TypeOrmDataSource,
  ) {
    super('NotamPoller');
  }

  async execute(): Promise<PollerResult> {
    // Get top airports that have TAF service (these are the most important)
    const topAirports = await this.getTopAirports();
    let totalUpdated = 0;
    let errors = 0;
    let lastError = '';

    // Process 2 airports at a time with a small delay to avoid hammering FAA
    const batchSize = 2;
    for (let i = 0; i < topAirports.length; i += batchSize) {
      const batch = topAirports.slice(i, i + batchSize);
      const results = await Promise.allSettled(
        batch.map((apt) => this.fetchNotamsForAirport(apt)),
      );

      for (let j = 0; j < results.length; j++) {
        const result = results[j];
        if (result.status === 'fulfilled') {
          totalUpdated += result.value;
        } else {
          errors++;
          lastError = `${batch[j]}: ${result.reason?.message ?? result.reason}`;
        }
      }

      // Throttle: 500ms between batches
      if (i + batchSize < topAirports.length) {
        await new Promise((resolve) => setTimeout(resolve, 500));
      }
    }

    this.logger.log(
      `NOTAMs: ${totalUpdated} records from ${topAirports.length} airports, ${errors} errors`,
    );
    return { recordsUpdated: totalUpdated, errors, lastError: lastError || undefined };
  }

  private async getTopAirports(): Promise<string[]> {
    // Get FAA identifiers for airports that have TAF service
    const result = await this.dataSource.query(
      `SELECT identifier FROM a_airports WHERE has_taf = true ORDER BY identifier LIMIT 200`,
    );
    return result.map((r: any) => r.identifier);
  }

  private async fetchNotamsForAirport(faaId: string): Promise<number> {
    try {
      const params = new URLSearchParams();
      params.append('searchType', '0');
      params.append('designatorsForLocation', faaId);
      params.append('designatorForAccountable', '');
      params.append('latDegrees', '');
      params.append('latMinutes', '0');
      params.append('latSeconds', '0');
      params.append('longDegrees', '');
      params.append('longMinutes', '0');
      params.append('longSeconds', '0');
      params.append('radius', WEATHER.NOTAM_SEARCH_RADIUS_NM);
      params.append('sortColumns', '5 false');
      params.append('sortDirection', 'true');
      params.append('designatorForNotamNumberSearch', '');
      params.append('notamNumber', '');
      params.append('radiusSearchOnDesignator', 'false');
      params.append('radiusSearchDesignator', '');
      params.append('latitudeDirection', 'N');
      params.append('longitudeDirection', 'W');
      params.append('freeFormText', '');
      params.append('flightPathText', '');
      params.append('flightPathDivertAirfields', '');
      params.append('flightPathBuffer', '4');
      params.append('flightPathIncludeNavaids', 'true');
      params.append('flightPathIncludeArtcc', 'false');
      params.append('flightPathIncludeTfr', 'true');
      params.append('flightPathIncludeRegulatory', 'false');
      params.append('flightPathResultsType', 'All NOTAMs');
      params.append('archiveDate', '');
      params.append('archiveDesignator', '');
      params.append('offset', '0');
      params.append('notamsOnly', 'false');
      params.append('filters', '');

      const { data } = await firstValueFrom(
        this.http.post(WEATHER.NOTAM_API_URL, params.toString(), {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
            Accept: 'application/json, text/plain, */*',
            'Accept-Language': 'en-US,en;q=0.9',
            Origin: 'https://notams.aim.faa.gov',
            Referer: 'https://notams.aim.faa.gov/notamSearch/',
            'Sec-Fetch-Dest': 'empty',
            'Sec-Fetch-Mode': 'cors',
            'Sec-Fetch-Site': 'same-origin',
          },
          timeout: WEATHER.TIMEOUT_NOTAM_MS,
        }),
      );

      const rawList = data?.notamList ?? [];
      const notams: Notam[] = rawList
        .filter((n: any) => n.notamNumber)
        .map((n: any) => {
          const notam = new Notam();
          notam.notam_number = n.notamNumber;
          notam.airport_id = faaId;
          notam.text =
            n.traditionalMessageFrom4thWord ?? n.traditionalMessage ?? null;
          notam.full_text = n.traditionalMessage ?? null;
          notam.keyword = n.keyword ?? null;
          notam.classification = n.featureName ?? null;
          notam.effective_start = this.parseNotamDate(n.startDate);
          notam.effective_end = this.parseNotamDate(n.endDate);
          notam.raw_data = n;
          return notam;
        });

      if (notams.length > 0) {
        // Delete old NOTAMs for this airport, then insert fresh
        await this.notamRepo.manager.transaction(async (em) => {
          await em.delete(Notam, { airport_id: faaId });
          await em.save(Notam, notams);
        });
      }

      return notams.length;
    } catch (error) {
      this.logger.warn(`Failed to fetch NOTAMs for ${faaId}: ${error.message}`);
      return 0;
    }
  }

  private parseNotamDate(dateStr: string | null | undefined): string | null {
    if (!dateStr) return null;
    const clean = dateStr.replace(/EST$/i, '').trim();
    const match = clean.match(/^(\d{2})\/(\d{2})\/(\d{4})\s+(\d{2})(\d{2})$/);
    if (!match) return null;
    const [, month, day, year, hour, minute] = match;
    return `${year}-${month}-${day}T${hour}:${minute}:00Z`;
  }
}
