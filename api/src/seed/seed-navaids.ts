/**
 * FAA NASR Navigation Data Seed Script
 *
 * Downloads the current FAA NASR 28-day subscription data and imports
 * navaids (VOR, VORTAC, NDB, etc.) and fixes/waypoints into the database.
 *
 * Usage: npx ts-node -r tsconfig-paths/register src/seed/seed-navaids.ts
 */

import { DataSource } from 'typeorm';
import { Navaid } from '../navaids/entities/navaid.entity';
import { Fix } from '../navaids/entities/fix.entity';
import * as path from 'path';
import {
  parsePipeDelimited,
  parseCoordinate,
  findFile,
  ensureNasrData,
} from './seed-utils';
import { dbConfig } from '../db.config';
import { DataCycle, CycleDataGroup } from '../data-cycle/entities/data-cycle.entity';
import {
  parseCycleIdArg,
  resolveOrCreateCycle,
  deleteCycleData,
  updateRecordCounts,
  markCycleStaged,
} from './seed-cycle-utils';

const DATA_DIR =
  process.env.EFB_DATA_DIR ||
  (process.env.NODE_ENV === 'production' ? '/tmp/efb-data' : undefined) ||
  path.join(__dirname, '..', '..', 'data');
const NASR_DIR = path.join(DATA_DIR, 'nasr');

async function initDataSource(): Promise<DataSource> {
  const ds = new DataSource({
    ...dbConfig,
    entities: [Navaid, Fix, DataCycle],
  });

  await ds.initialize();
  return ds;
}

async function seedNavaids(ds: DataSource, cycleId?: string): Promise<number> {
  const navFile = findFile(NASR_DIR, 'NAV_BASE.csv', 'NAV.csv');
  if (!navFile) {
    console.log('  NAV file not found, seeding sample data instead...');
    return seedSampleNavaids(ds, cycleId);
  }

  console.log(`  Reading ${navFile}...`);
  const records = await parsePipeDelimited(navFile);
  console.log(`  Parsed ${records.length} records`);

  const repo = ds.getRepository(Navaid);
  let count = 0;

  const batchSize = 500;
  for (let i = 0; i < records.length; i += batchSize) {
    const batch = records.slice(i, i + batchSize);
    const navaids: Partial<Navaid>[] = [];

    for (const r of batch) {
      const identifier = r['NAV_ID'];
      if (!identifier) continue;

      const lat = parseFloat(r['LAT_DECIMAL'] || '');
      const lng = parseFloat(r['LONG_DECIMAL'] || '');
      if (isNaN(lat) || isNaN(lng)) continue;

      navaids.push({
        cycle_id: cycleId,
        identifier: identifier.trim(),
        name: (r['NAME'] || '').trim(),
        type: (r['NAV_TYPE'] || '').trim(),
        latitude: lat,
        longitude: lng,
        elevation: parseFloat(r['ELEV'] || '') || undefined,
        frequency: (r['FREQ'] || '').trim() || undefined,
        channel: (r['CHAN'] || '').trim() || undefined,
        magnetic_variation: (r['MAG_VARN'] || '').trim() || undefined,
        state: (r['STATE_CODE'] || '').trim() || undefined,
        status: (r['NAV_STATUS'] || '').trim() || undefined,
      });
    }

    if (navaids.length > 0) {
      await repo.save(navaids as Navaid[]);
      count += navaids.length;
    }
  }

  return count;
}

async function seedSampleNavaids(ds: DataSource, cycleId?: string): Promise<number> {
  const repo = ds.getRepository(Navaid);
  const samples: Partial<Navaid>[] = [
    {
      identifier: 'DEN',
      name: 'Denver',
      type: 'VORTAC',
      latitude: 39.8017,
      longitude: -104.8872,
      elevation: 5870,
      frequency: '117.90',
      channel: '126X',
      state: 'CO',
      status: 'OPERATIONAL',
    },
    {
      identifier: 'BJC',
      name: 'Jeffco',
      type: 'VOR/DME',
      latitude: 39.9086,
      longitude: -105.1175,
      elevation: 5671,
      frequency: '114.40',
      channel: '91X',
      state: 'CO',
      status: 'OPERATIONAL',
    },
    {
      identifier: 'DBL',
      name: 'Eagle',
      type: 'VOR/DME',
      latitude: 39.6464,
      longitude: -106.9153,
      elevation: 7600,
      frequency: '113.00',
      channel: '77X',
      state: 'CO',
      status: 'OPERATIONAL',
    },
    {
      identifier: 'GLL',
      name: 'Gill',
      type: 'VOR/DME',
      latitude: 40.4847,
      longitude: -104.5822,
      elevation: 4670,
      frequency: '114.20',
      channel: '89X',
      state: 'CO',
      status: 'OPERATIONAL',
    },
    {
      identifier: 'FQF',
      name: 'Falcon',
      type: 'VORTAC',
      latitude: 38.8119,
      longitude: -104.6236,
      elevation: 6740,
      frequency: '116.90',
      channel: '116X',
      state: 'CO',
      status: 'OPERATIONAL',
    },
    {
      identifier: 'PUB',
      name: 'Pueblo',
      type: 'VORTAC',
      latitude: 38.2886,
      longitude: -104.4964,
      elevation: 4700,
      frequency: '116.70',
      channel: '114X',
      state: 'CO',
      status: 'OPERATIONAL',
    },
    {
      identifier: 'AKR',
      name: 'Akron',
      type: 'NDB',
      latitude: 40.1564,
      longitude: -103.2261,
      elevation: 4660,
      frequency: '362',
      state: 'CO',
      status: 'OPERATIONAL',
    },
    {
      identifier: 'HBU',
      name: 'Hubbart',
      type: 'NDB',
      latitude: 39.9369,
      longitude: -105.0636,
      elevation: 5300,
      frequency: '242',
      state: 'CO',
      status: 'OPERATIONAL',
    },
    {
      identifier: 'COS',
      name: 'Colorado Springs',
      type: 'VORTAC',
      latitude: 38.8097,
      longitude: -104.6828,
      elevation: 6170,
      frequency: '112.50',
      channel: '72X',
      state: 'CO',
      status: 'OPERATIONAL',
    },
    {
      identifier: 'FTN',
      name: 'Fort Collins',
      type: 'VOR',
      latitude: 40.4508,
      longitude: -105.0103,
      elevation: 5000,
      frequency: '112.90',
      state: 'CO',
      status: 'OPERATIONAL',
    },
  ];

  if (cycleId) { for (const n of samples) n.cycle_id = cycleId; }
  await repo.save(samples as Navaid[]);
  return samples.length;
}

async function seedFixes(ds: DataSource, cycleId?: string): Promise<number> {
  const fixFile = findFile(NASR_DIR, 'FIX_BASE.csv', 'FIX.csv');
  if (!fixFile) {
    console.log('  FIX file not found, seeding sample data instead...');
    return seedSampleFixes(ds, cycleId);
  }

  console.log(`  Reading ${fixFile}...`);
  const records = await parsePipeDelimited(fixFile);
  console.log(`  Parsed ${records.length} records`);

  const repo = ds.getRepository(Fix);
  let count = 0;

  const batchSize = 500;
  for (let i = 0; i < records.length; i += batchSize) {
    const batch = records.slice(i, i + batchSize);
    const fixes: Partial<Fix>[] = [];

    for (const r of batch) {
      const identifier = r['FIX_ID'];
      if (!identifier) continue;

      const lat = parseFloat(r['LAT_DECIMAL'] || '');
      const lng = parseFloat(r['LONG_DECIMAL'] || '');
      if (isNaN(lat) || isNaN(lng)) continue;

      fixes.push({
        cycle_id: cycleId,
        identifier: identifier.trim(),
        latitude: lat,
        longitude: lng,
        state: (r['STATE_CODE'] || '').trim() || undefined,
        artcc_high: (r['ARTCC_ID_HIGH'] || '').trim() || undefined,
        artcc_low: (r['ARTCC_ID_LOW'] || '').trim() || undefined,
      });
    }

    if (fixes.length > 0) {
      await repo.save(fixes as Fix[]);
      count += fixes.length;
    }
  }

  return count;
}

async function seedSampleFixes(ds: DataSource, cycleId?: string): Promise<number> {
  const repo = ds.getRepository(Fix);
  const samples: Partial<Fix>[] = [
    {
      identifier: 'TOMSN',
      latitude: 39.95,
      longitude: -105.1333,
      state: 'CO',
      artcc_high: 'ZDV',
      artcc_low: 'ZDV',
    },
    {
      identifier: 'DRAIN',
      latitude: 39.75,
      longitude: -104.7,
      state: 'CO',
      artcc_high: 'ZDV',
      artcc_low: 'ZDV',
    },
    {
      identifier: 'RAMMS',
      latitude: 39.7833,
      longitude: -104.8833,
      state: 'CO',
      artcc_high: 'ZDV',
      artcc_low: 'ZDV',
    },
    {
      identifier: 'TSHNR',
      latitude: 39.65,
      longitude: -104.9667,
      state: 'CO',
      artcc_high: 'ZDV',
      artcc_low: 'ZDV',
    },
    {
      identifier: 'ELORE',
      latitude: 39.8667,
      longitude: -105.0667,
      state: 'CO',
      artcc_high: 'ZDV',
      artcc_low: 'ZDV',
    },
    {
      identifier: 'POWDR',
      latitude: 40.0167,
      longitude: -105.2333,
      state: 'CO',
      artcc_high: 'ZDV',
      artcc_low: 'ZDV',
    },
    {
      identifier: 'SSKIS',
      latitude: 39.6,
      longitude: -106.5167,
      state: 'CO',
      artcc_high: 'ZDV',
      artcc_low: 'ZDV',
    },
    {
      identifier: 'LANDR',
      latitude: 40.1833,
      longitude: -105.1,
      state: 'CO',
      artcc_high: 'ZDV',
      artcc_low: 'ZDV',
    },
    {
      identifier: 'WOBEE',
      latitude: 39.55,
      longitude: -104.5833,
      state: 'CO',
      artcc_high: 'ZDV',
      artcc_low: 'ZDV',
    },
    {
      identifier: 'FLATI',
      latitude: 40.0833,
      longitude: -105.3333,
      state: 'CO',
      artcc_high: 'ZDV',
      artcc_low: 'ZDV',
    },
  ];

  if (cycleId) { for (const f of samples) f.cycle_id = cycleId; }
  await repo.save(samples as Fix[]);
  return samples.length;
}

async function main() {
  console.log('=== EFB Navigation Data Seed ===\n');

  // Download + extract NASR data if not already present
  await ensureNasrData(NASR_DIR);

  const ds = await initDataSource();
  console.log('Database initialized.\n');

  // Resolve or create a data cycle
  const cycleIdArg = parseCycleIdArg();
  const { cycle } = await resolveOrCreateCycle(ds, cycleIdArg, CycleDataGroup.NASR, {
    cycle_code: new Date().toISOString().slice(0, 10),
    effective_date: new Date().toISOString().slice(0, 10),
    expiration_date: new Date(Date.now() + 28 * 86400000).toISOString().slice(0, 10),
  });
  const cycleId = cycle.id;
  console.log('');

  // Clear existing data for this cycle
  console.log('Clearing existing navigation data for this cycle...');
  await deleteCycleData(ds, cycleId, ['a_navaids', 'a_fixes']);
  console.log('  Done.\n');

  // Seed navaids
  console.log('Seeding navaids...');
  const navaidCount = await seedNavaids(ds, cycleId);
  console.log(`  Imported ${navaidCount} navaids.\n`);

  // Seed fixes
  console.log('Seeding fixes...');
  const fixCount = await seedFixes(ds, cycleId);
  console.log(`  Imported ${fixCount} fixes.\n`);

  // Summary
  console.log('=== Seed Complete ===');
  console.log(`  Navaids: ${navaidCount}`);
  console.log(`  Fixes:   ${fixCount}`);

  await updateRecordCounts(ds, cycleId, { navaids: navaidCount, fixes: fixCount });
  if (!cycleIdArg) await markCycleStaged(ds, cycleId);

  await ds.destroy();
}

main().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
