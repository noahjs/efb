/**
 * FAA d-TPP (Terminal Procedures Publication) Seed Script
 *
 * Downloads the current d-TPP metafile XML and imports procedure metadata
 * (~17,000 records) into the SQLite database.
 *
 * Usage: npx ts-node -r tsconfig-paths/register src/seed/seed-procedures.ts
 *
 * Data sources (tried in order):
 *   1. https://aeronav.faa.gov/d-tpp/{cycle}/xml_data/d-tpp_Metafile.xml
 *   2. https://nfdc.faa.gov/webContent/dtpp/current.xml
 */

import { DataSource } from 'typeorm';
import { Procedure } from '../procedures/entities/procedure.entity';
import { DtppCycle } from '../procedures/entities/dtpp-cycle.entity';
import { XMLParser } from 'fast-xml-parser';
import * as fs from 'fs';
import * as path from 'path';
import * as https from 'https';
import { downloadFile } from './seed-utils';
import { dbConfig } from '../db.config';

const DATA_DIR = path.join(__dirname, '..', '..', 'data');
const DTPP_DIR = path.join(DATA_DIR, 'dtpp');
const XML_PATH = path.join(DTPP_DIR, 'current.xml');

async function initDataSource(): Promise<DataSource> {
  const ds = new DataSource({
    ...dbConfig,
    entities: [Procedure, DtppCycle],
  });

  await ds.initialize();
  return ds;
}

function ensureArray<T>(val: T | T[]): T[] {
  if (Array.isArray(val)) return val;
  if (val === undefined || val === null) return [];
  return [val];
}

/**
 * Compute candidate d-TPP cycle numbers.
 * FAA cycles are 4-digit: 2-digit year + 2-digit sequence (01-13).
 * Each cycle is ~28 days. We try the most likely current cycle first,
 * then a few surrounding ones.
 */
function getCandidateCycles(): string[] {
  const now = new Date();
  const year = now.getFullYear() % 100; // 2-digit year
  // FAA cycle 01 starts around Jan 23 each year; each cycle is 28 days
  const dayOfYear = Math.floor(
    (now.getTime() - new Date(now.getFullYear(), 0, 0).getTime()) / 86400000,
  );
  // Approximate current cycle number (1-indexed, starts ~day 23)
  const approxCycle = Math.max(1, Math.ceil((dayOfYear - 23 + 28) / 28));

  const candidates: string[] = [];
  // Try current and nearby cycles (current, previous, next)
  for (const offset of [0, -1, 1, -2]) {
    let c = approxCycle + offset;
    let y = year;
    if (c < 1) {
      c += 13;
      y -= 1;
    }
    if (c > 13) {
      c -= 13;
      y += 1;
    }
    candidates.push(
      `${String(y).padStart(2, '0')}${String(c).padStart(2, '0')}`,
    );
  }

  return candidates;
}

/**
 * Check if a URL returns 200 (HEAD request).
 */
function urlExists(url: string): Promise<boolean> {
  return new Promise((resolve) => {
    const req = https.request(url, { method: 'HEAD' }, (res) => {
      resolve(res.statusCode === 200);
    });
    req.on('error', () => resolve(false));
    req.setTimeout(10000, () => {
      req.destroy();
      resolve(false);
    });
    req.end();
  });
}

async function findMetafileUrl(): Promise<string> {
  // Try aeronav.faa.gov with auto-detected cycle
  const cycles = getCandidateCycles();
  console.log(`  Trying cycles: ${cycles.join(', ')}`);

  for (const cycle of cycles) {
    const url = `https://aeronav.faa.gov/d-tpp/${cycle}/xml_data/d-tpp_Metafile.xml`;
    console.log(`  Checking ${url}...`);
    if (await urlExists(url)) {
      console.log(`  Found: cycle ${cycle}`);
      return url;
    }
  }

  // Fallback to nfdc.faa.gov
  const fallback = 'https://nfdc.faa.gov/webContent/dtpp/current.xml';
  console.log(`  Trying fallback: ${fallback}...`);
  if (await urlExists(fallback)) {
    return fallback;
  }

  throw new Error(
    'Could not find d-TPP metafile at any known URL. ' +
      'The FAA servers may be temporarily unavailable.',
  );
}

async function main() {
  console.log('=== EFB d-TPP Procedure Seed ===\n');

  // Ensure directories exist
  fs.mkdirSync(DTPP_DIR, { recursive: true });

  // Find and download XML metafile
  console.log('Locating d-TPP metafile...');
  const xmlUrl = await findMetafileUrl();

  console.log(`\nDownloading d-TPP metafile...`);
  console.log(`  URL: ${xmlUrl}`);
  await downloadFile(xmlUrl, XML_PATH);
  const fileSize = fs.statSync(XML_PATH).size;
  console.log(`  Downloaded: ${(fileSize / 1024 / 1024).toFixed(1)} MB\n`);

  // Parse XML
  console.log('Parsing XML...');
  const xmlData = fs.readFileSync(XML_PATH, 'utf-8');
  const parser = new XMLParser({
    ignoreAttributes: false,
    attributeNamePrefix: '@_',
    textNodeName: '#text',
  });
  const parsed = parser.parse(xmlData);

  const root = parsed.digital_tpp;
  if (!root) {
    console.error(
      'ERROR: Unexpected XML structure — missing <digital_tpp> root',
    );
    process.exit(1);
  }

  // Extract cycle info from root attributes
  const cycle = root['@_cycle'] || '';
  const fromDate = root['@_from_edate'] || '';
  const toDate = root['@_to_edate'] || '';

  console.log(`  Cycle: ${cycle}`);
  console.log(`  Effective: ${fromDate} to ${toDate}\n`);

  // Collect all procedure records
  console.log('Extracting procedure records...');
  const procedures: Partial<Procedure>[] = [];

  const states = ensureArray(root.state_code);
  for (const state of states) {
    const stateId = state['@_ID'] || '';
    const cities = ensureArray(state.city_name);

    for (const city of cities) {
      const cityId = city['@_ID'] || '';
      const volume = city['@_volume'] || '';
      const airports = ensureArray(city.airport_name);

      for (const airport of airports) {
        const aptIdent = airport['@_apt_ident'] || '';
        const records = ensureArray(airport.record);

        for (const record of records) {
          const chartCode = record.chart_code || '';
          const chartName = record.chart_name || '';
          const pdfName = record.pdf_name || '';

          // Skip records with no PDF
          if (!pdfName || pdfName === 'DELETED') continue;

          procedures.push({
            airport_identifier: aptIdent.trim(),
            chart_code: chartCode.trim(),
            chart_name: chartName.trim(),
            pdf_name: pdfName.trim(),
            chart_seq: parseInt(record.chartseq || '0', 10) || 0,
            user_action: (record.useraction || '').trim() || null,
            faanfd18: (record.faanfd18 || '').trim() || null,
            copter: (record.copter || '').trim() || null,
            cycle,
            state_code: stateId.trim() || null,
            city_name: cityId.trim() || null,
            volume: volume.trim() || null,
          });
        }
      }
    }
  }

  console.log(`  Found ${procedures.length} procedures\n`);

  // Initialize database
  const ds = await initDataSource();
  console.log('Database initialized.\n');

  // Clear existing procedures
  console.log('Clearing existing procedure data...');
  await ds.query('TRUNCATE TABLE procedures, dtpp_cycles CASCADE');
  console.log('  Done.\n');

  // Batch insert procedures
  console.log('Inserting procedures...');
  const repo = ds.getRepository(Procedure);
  const batchSize = 500;
  let inserted = 0;

  for (let i = 0; i < procedures.length; i += batchSize) {
    const batch = procedures.slice(i, i + batchSize);
    await repo.save(batch as Procedure[]);
    inserted += batch.length;
    if (inserted % 5000 === 0 || inserted === procedures.length) {
      console.log(`  ${inserted} / ${procedures.length}`);
    }
  }

  // Save cycle metadata
  const cycleRepo = ds.getRepository(DtppCycle);
  await cycleRepo.save({
    cycle,
    from_date: fromDate,
    to_date: toDate,
    procedure_count: inserted,
    seeded_at: new Date().toISOString(),
  } as DtppCycle);

  console.log('\n=== Seed Complete ===');
  console.log(`  Cycle:      ${cycle}`);
  console.log(`  Effective:  ${fromDate} to ${toDate}`);
  console.log(`  Procedures: ${inserted}`);

  await ds.destroy();
}

main().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
