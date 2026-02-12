/**
 * Weather Flags Seed Script
 *
 * Sets has_datis and has_awos flags on airports without re-seeding airport data.
 * - has_awos: checks if airport has ATIS frequency (proxy for weather reporting)
 *   and is NOT towered (towered airports use ATIS, non-towered use AWOS/ASOS)
 * - has_datis: probes datis.clowd.io API for each towered airport
 *
 * Usage: npx ts-node -r tsconfig-paths/register src/seed/seed-weather-flags.ts
 */

import { DataSource } from 'typeorm';
import { Airport } from '../airports/entities/airport.entity';
import { Runway } from '../airports/entities/runway.entity';
import { RunwayEnd } from '../airports/entities/runway-end.entity';
import { Frequency } from '../airports/entities/frequency.entity';
import { Fbo } from '../fbos/entities/fbo.entity';
import { FuelPrice } from '../fbos/entities/fuel-price.entity';
import { dbConfig } from '../db.config';

async function initDataSource(): Promise<DataSource> {
  const ds = new DataSource({
    ...dbConfig,
    entities: [Airport, Runway, RunwayEnd, Frequency, Fbo, FuelPrice],
  });
  await ds.initialize();
  return ds;
}

async function seedDatisFlag(ds: DataSource): Promise<number> {
  const repo = ds.getRepository(Airport);

  // Reset
  await ds.query(
    'UPDATE a_airports SET has_datis = false WHERE has_datis = true',
  );

  // Find towered airports (have TWR frequency) with ICAO identifiers
  const toweredAirports: { identifier: string; icao_identifier: string }[] =
    await ds.query(`
      SELECT DISTINCT a.identifier, a.icao_identifier
      FROM a_airports a
      INNER JOIN a_frequencies f ON f.airport_identifier = a.identifier AND f.type = 'TWR'
      WHERE a.icao_identifier IS NOT NULL
    `);

  console.log(
    `  Checking ${toweredAirports.length} towered airports for D-ATIS...`,
  );

  let count = 0;
  const batchSize = 20;
  const delayMs = 500;

  for (let i = 0; i < toweredAirports.length; i += batchSize) {
    const batch = toweredAirports.slice(i, i + batchSize);

    const results = await Promise.allSettled(
      batch.map(async (apt) => {
        try {
          const response = await fetch(
            `https://datis.clowd.io/api/${apt.icao_identifier}`,
            { signal: AbortSignal.timeout(5000) },
          );
          if (!response.ok) return false;
          const data = await response.json();
          return Array.isArray(data) && data.length > 0;
        } catch {
          return false;
        }
      }),
    );

    const idsToUpdate: string[] = [];
    for (let j = 0; j < results.length; j++) {
      const result = results[j];
      if (result.status === 'fulfilled' && result.value) {
        idsToUpdate.push(batch[j].identifier);
      }
    }

    if (idsToUpdate.length > 0) {
      await repo
        .createQueryBuilder()
        .update()
        .set({ has_datis: true })
        .where('identifier IN (:...ids)', { ids: idsToUpdate })
        .execute();
      count += idsToUpdate.length;
    }

    if (i + batchSize < toweredAirports.length) {
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }

    const checked = Math.min(i + batchSize, toweredAirports.length);
    if (checked % 100 === 0 || checked === toweredAirports.length) {
      console.log(
        `  Checked ${checked}/${toweredAirports.length} (${count} with D-ATIS so far)`,
      );
    }
  }

  return count;
}

async function main() {
  console.log('=== EFB Weather Flags Seed ===\n');

  const ds = await initDataSource();
  console.log('Database initialized.\n');

  // D-ATIS
  console.log('Seeding D-ATIS capability...');
  const datisCount = await seedDatisFlag(ds);
  console.log(`  Marked ${datisCount} airports with D-ATIS.\n`);

  console.log('=== Seed Complete ===');
  console.log(`  D-ATIS: ${datisCount}`);

  await ds.destroy();
}

main().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
