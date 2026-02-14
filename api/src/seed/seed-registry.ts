/**
 * FAA Aircraft Registry Seed Script
 *
 * Downloads the FAA Releasable Aircraft database and imports
 * aircraft registration data (MASTER + ACFTREF + ENGINE) into
 * a single denormalized table.
 *
 * Usage: npx ts-node -r tsconfig-paths/register src/seed/seed-registry.ts
 */

import { DataSource } from 'typeorm';
import { FaaRegistryAircraft } from '../registry/entities/faa-registry-aircraft.entity';
import * as path from 'path';
import * as fs from 'fs';
import { execSync } from 'child_process';
import { downloadFile } from './seed-utils';
import { createReadStream } from 'fs';
import { parse } from 'csv-parse';
import { dbConfig } from '../db.config';

const DATA_DIR =
  process.env.EFB_DATA_DIR ||
  (process.env.NODE_ENV === 'production' ? '/tmp/efb-data' : undefined) ||
  path.join(__dirname, '..', '..', 'data');
const REGISTRY_DIR = path.join(DATA_DIR, 'registry');
const REGISTRY_URL = 'https://registry.faa.gov/database/ReleasableAircraft.zip';

function parseRegistryCsv(filePath: string): Promise<Record<string, string>[]> {
  return new Promise((resolve, reject) => {
    const records: Record<string, string>[] = [];
    createReadStream(filePath)
      .pipe(
        parse({
          delimiter: ',',
          columns: true,
          skip_empty_lines: true,
          trim: true,
          relax_column_count: true,
          quote: false,
          bom: true,
        }),
      )
      .on('data', (record: Record<string, string>) => records.push(record))
      .on('end', () => resolve(records))
      .on('error', reject);
  });
}

async function ensureRegistryData(): Promise<void> {
  // Check if files already exist
  const masterPath = path.join(REGISTRY_DIR, 'MASTER.txt');
  if (fs.existsSync(masterPath)) {
    console.log('Registry data already present, skipping download.\n');
    return;
  }

  fs.mkdirSync(REGISTRY_DIR, { recursive: true });

  const zipPath = path.join(REGISTRY_DIR, 'ReleasableAircraft.zip');

  console.log('Downloading FAA Aircraft Registry...');
  console.log(`  URL: ${REGISTRY_URL}`);
  await downloadFile(REGISTRY_URL, zipPath);
  const zipSize = fs.statSync(zipPath).size;
  console.log(`  Downloaded: ${(zipSize / 1024 / 1024).toFixed(1)} MB`);

  console.log('Extracting registry archive...');
  execSync(`unzip -o "${zipPath}" -d "${REGISTRY_DIR}"`, { stdio: 'pipe' });
  console.log('Registry data ready.\n');
}

async function initDataSource(): Promise<DataSource> {
  const ds = new DataSource({
    ...dbConfig,
    entities: [FaaRegistryAircraft],
  });
  await ds.initialize();
  return ds;
}

async function main() {
  console.log('=== EFB Aircraft Registry Seed ===\n');

  await ensureRegistryData();

  const ds = await initDataSource();
  console.log('Database initialized.\n');

  // Parse ACFTREF.txt into a map keyed by MFR MDL CODE
  console.log('Parsing ACFTREF.txt...');
  const acftrefPath = path.join(REGISTRY_DIR, 'ACFTREF.txt');
  const acftrefRecords = await parseRegistryCsv(acftrefPath);
  const acftrefMap = new Map<string, Record<string, string>>();
  for (const r of acftrefRecords) {
    const code = (r['CODE'] || '').trim();
    if (code) acftrefMap.set(code, r);
  }
  console.log(`  ${acftrefMap.size} aircraft reference entries.\n`);

  // Parse ENGINE.txt into a map keyed by CODE
  console.log('Parsing ENGINE.txt...');
  const enginePath = path.join(REGISTRY_DIR, 'ENGINE.txt');
  const engineRecords = await parseRegistryCsv(enginePath);
  const engineMap = new Map<string, Record<string, string>>();
  for (const r of engineRecords) {
    const code = (r['CODE'] || '').trim();
    if (code) engineMap.set(code, r);
  }
  console.log(`  ${engineMap.size} engine reference entries.\n`);

  // Clear existing data
  console.log('Clearing existing registry data...');
  await ds.getRepository(FaaRegistryAircraft).clear();
  console.log('  Done.\n');

  // Parse MASTER.txt and join with reference data
  console.log('Parsing MASTER.txt...');
  const masterPath = path.join(REGISTRY_DIR, 'MASTER.txt');
  const masterRecords = await parseRegistryCsv(masterPath);
  console.log(`  ${masterRecords.length} master records.\n`);

  console.log('Importing records...');
  const repo = ds.getRepository(FaaRegistryAircraft);
  let count = 0;
  const batchSize = 500;

  for (let i = 0; i < masterRecords.length; i += batchSize) {
    const batch = masterRecords.slice(i, i + batchSize);
    const entities: Partial<FaaRegistryAircraft>[] = [];

    for (const r of batch) {
      const nNumber = (r['N-NUMBER'] || '').trim();
      if (!nNumber) continue;

      // Look up aircraft reference data
      const mfrCode = (r['MFR MDL CODE'] || '').trim();
      const acftRef = acftrefMap.get(mfrCode);

      // Look up engine reference data
      const engCode = (r['ENG MFR MDL'] || '').trim();
      const engRef = engineMap.get(engCode);

      entities.push({
        n_number: nNumber,
        serial_number: (r['SERIAL NUMBER'] || '').trim() || undefined,
        year_mfr: (r['YEAR MFR'] || '').trim() || undefined,
        type_aircraft: (r['TYPE AIRCRAFT'] || '').trim() || undefined,
        type_engine: (r['TYPE ENGINE'] || '').trim() || undefined,
        status_code: (r['STATUS CODE'] || '').trim() || undefined,
        mode_s_code_hex: (r['MODE S CODE HEX'] || '').trim() || undefined,
        // ACFTREF fields
        manufacturer: acftRef
          ? (acftRef['MFR'] || '').trim() || undefined
          : undefined,
        model: acftRef
          ? (acftRef['MODEL'] || '').trim() || undefined
          : undefined,
        num_engines: acftRef
          ? (acftRef['NO-ENG'] || '').trim() || undefined
          : undefined,
        num_seats: acftRef
          ? (acftRef['NO-SEATS'] || '').trim() || undefined
          : undefined,
        cruising_speed_mph: acftRef
          ? (acftRef['SPEED'] || '').trim() || undefined
          : undefined,
        // ENGINE fields
        engine_manufacturer: engRef
          ? (engRef['MFR'] || '').trim() || undefined
          : undefined,
        engine_model: engRef
          ? (engRef['MODEL'] || '').trim() || undefined
          : undefined,
        horsepower: engRef
          ? (engRef['HOR-POWER'] || engRef['HORSEPOWER'] || '').trim() ||
            undefined
          : undefined,
        thrust: engRef
          ? (engRef['THRUST'] || '').trim() || undefined
          : undefined,
      });
    }

    if (entities.length > 0) {
      await repo
        .createQueryBuilder()
        .insert()
        .into(FaaRegistryAircraft)
        .values(entities)
        .orIgnore()
        .execute();
      count += entities.length;
    }

    if (i % 10000 === 0 && i > 0) {
      console.log(
        `  Processed ${i.toLocaleString()} / ${masterRecords.length.toLocaleString()} records...`,
      );
    }
  }

  console.log(`\n=== Seed Complete ===`);
  console.log(`  Registry aircraft: ${count.toLocaleString()}`);

  await ds.destroy();
}

main().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
