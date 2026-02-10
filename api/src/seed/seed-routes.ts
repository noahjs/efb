/**
 * FAA Preferred Routes Seed Script
 *
 * Imports IFR Preferred Routes, TEC Routes, and NARs from FAA NASR
 * PFR_BASE.csv and PFR_SEG.csv into the database.
 *
 * Usage: npx ts-node -r tsconfig-paths/register src/seed/seed-routes.ts
 */

import { DataSource } from 'typeorm';
import { PreferredRoute } from '../routes/entities/preferred-route.entity';
import { PreferredRouteSegment } from '../routes/entities/preferred-route-segment.entity';
import * as path from 'path';
import { parsePipeDelimited, findFile, ensureNasrData } from './seed-utils';
import { dbConfig } from '../db.config';

const DATA_DIR = path.join(__dirname, '..', '..', 'data');
const NASR_DIR = path.join(DATA_DIR, 'nasr');

async function initDataSource(): Promise<DataSource> {
  const ds = new DataSource({
    ...dbConfig,
    entities: [PreferredRoute, PreferredRouteSegment],
  });

  await ds.initialize();
  return ds;
}

async function seedRoutes(ds: DataSource): Promise<{
  routeCount: number;
  routeLookup: Map<string, number>;
}> {
  const baseFile = findFile(NASR_DIR, 'PFR_BASE.csv');
  if (!baseFile) {
    console.log('  PFR_BASE.csv not found, skipping routes.');
    return { routeCount: 0, routeLookup: new Map() };
  }

  console.log(`  Reading ${baseFile}...`);
  const records = await parsePipeDelimited(baseFile);
  console.log(`  Parsed ${records.length} records`);

  const repo = ds.getRepository(PreferredRoute);
  const routeLookup = new Map<string, number>();
  let count = 0;

  const batchSize = 500;
  for (let i = 0; i < records.length; i += batchSize) {
    const batch = records.slice(i, i + batchSize);
    const routes: Partial<PreferredRoute>[] = [];

    for (const r of batch) {
      const originId = (r['ORIGIN_ID'] || '').trim();
      const dstnId = (r['DSTN_ID'] || '').trim();
      const routeType = (r['PFR_TYPE_CODE'] || '').trim();
      const routeNo = parseInt(r['ROUTE_NO'] || '0', 10);

      if (!originId || !dstnId || !routeType) continue;

      routes.push({
        origin_id: originId,
        destination_id: dstnId,
        route_type: routeType,
        route_number: routeNo,
        route_string: (r['ROUTE_STRING'] || '').trim(),
        altitude: (r['ALT_DESCRIP'] || '').trim() || undefined,
        aircraft: (r['AIRCRAFT'] || '').trim() || undefined,
        direction: (r['ROUTE_DIR_DESCRIP'] || '').trim() || undefined,
        hours: (r['HOURS'] || '').trim() || undefined,
        area_description: (r['SPECIAL_AREA_DESCRIP'] || '').trim() || undefined,
        origin_city: (r['ORIGIN_CITY'] || '').trim() || undefined,
        destination_city: (r['DSTN_CITY'] || '').trim() || undefined,
      });
    }

    if (routes.length > 0) {
      const saved = await repo.save(routes as PreferredRoute[]);
      for (const route of saved) {
        const key = `${route.origin_id}|${route.destination_id}|${route.route_type}|${route.route_number}`;
        routeLookup.set(key, route.id);
      }
      count += saved.length;
    }
  }

  return { routeCount: count, routeLookup };
}

async function seedSegments(
  ds: DataSource,
  routeLookup: Map<string, number>,
): Promise<number> {
  const segFile = findFile(NASR_DIR, 'PFR_SEG.csv');
  if (!segFile) {
    console.log('  PFR_SEG.csv not found, skipping segments.');
    return 0;
  }

  console.log(`  Reading ${segFile}...`);
  const records = await parsePipeDelimited(segFile);
  console.log(`  Parsed ${records.length} records`);

  const repo = ds.getRepository(PreferredRouteSegment);
  let count = 0;
  let skipped = 0;

  const batchSize = 500;
  for (let i = 0; i < records.length; i += batchSize) {
    const batch = records.slice(i, i + batchSize);
    const segments: Partial<PreferredRouteSegment>[] = [];

    for (const r of batch) {
      const originId = (r['ORIGIN_ID'] || '').trim();
      const dstnId = (r['DSTN_ID'] || '').trim();
      const routeType = (r['PFR_TYPE_CODE'] || '').trim();
      const routeNo = parseInt(r['ROUTE_NO'] || '0', 10);

      const key = `${originId}|${dstnId}|${routeType}|${routeNo}`;
      const routeId = routeLookup.get(key);

      if (!routeId) {
        skipped++;
        continue;
      }

      segments.push({
        route: { id: routeId } as PreferredRoute,
        sequence: parseInt(r['SEGMENT_SEQ'] || '0', 10),
        value: (r['SEG_VALUE'] || '').trim(),
        type: (r['SEG_TYPE'] || '').trim(),
        navaid_type: (r['NAV_TYPE'] || '').trim() || undefined,
      });
    }

    if (segments.length > 0) {
      await repo.save(segments as PreferredRouteSegment[]);
      count += segments.length;
    }
  }

  if (skipped > 0) {
    console.log(`  Skipped ${skipped} segments with no matching route.`);
  }

  return count;
}

async function main() {
  console.log('=== EFB Preferred Routes Seed ===\n');

  // Download + extract NASR data if not already present
  await ensureNasrData(NASR_DIR);

  const ds = await initDataSource();
  console.log('Database initialized.\n');

  // Clear existing data
  console.log('Clearing existing preferred route data...');
  await ds.query(
    'TRUNCATE TABLE a_preferred_route_segments, a_preferred_routes CASCADE',
  );
  console.log('  Done.\n');

  // Seed routes
  console.log('Seeding preferred routes...');
  const { routeCount, routeLookup } = await seedRoutes(ds);
  console.log(`  Imported ${routeCount} routes.\n`);

  // Seed segments
  console.log('Seeding route segments...');
  const segmentCount = await seedSegments(ds, routeLookup);
  console.log(`  Imported ${segmentCount} segments.\n`);

  // Summary
  console.log('=== Seed Complete ===');
  console.log(`  Routes:   ${routeCount}`);
  console.log(`  Segments: ${segmentCount}`);

  await ds.destroy();
}

main().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
