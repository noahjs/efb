/**
 * FAA NASR Data Seed Script
 *
 * Downloads the current FAA NASR 28-day subscription data and imports
 * airports, runways, runway ends, and frequencies into the SQLite database.
 *
 * Usage: npx ts-node src/seed/seed.ts
 *
 * The NASR data is available at:
 * https://nfdc.faa.gov/webContent/28DaySub/
 *
 * The CSV files use pipe (|) delimiters.
 */

import { DataSource } from 'typeorm';
import { Airport } from '../airports/entities/airport.entity';
import { Runway } from '../airports/entities/runway.entity';
import { RunwayEnd } from '../airports/entities/runway-end.entity';
import { Frequency } from '../airports/entities/frequency.entity';
import * as fs from 'fs';
import * as path from 'path';
import * as https from 'https';
import * as http from 'http';
import { createReadStream } from 'fs';
import { parse } from 'csv-parse';
import { execSync } from 'child_process';

const DATA_DIR = path.join(__dirname, '..', '..', 'data');
const DB_PATH = path.join(DATA_DIR, 'efb.sqlite');
const NASR_DIR = path.join(DATA_DIR, 'nasr');

// NASR download URL - 28-day subscription CSV format
const NASR_CSV_URL =
  'https://nfdc.faa.gov/webContent/28DaySub/28DaySubscription_Effective_2026-01-30.zip';

async function initDataSource(): Promise<DataSource> {
  // Ensure data directory exists
  fs.mkdirSync(DATA_DIR, { recursive: true });

  const ds = new DataSource({
    type: 'better-sqlite3',
    database: DB_PATH,
    entities: [Airport, Runway, RunwayEnd, Frequency],
    synchronize: true,
  });

  await ds.initialize();
  return ds;
}

function downloadFile(url: string, dest: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(dest);
    const protocol = url.startsWith('https') ? https : http;

    (protocol as typeof https)
      .get(url, (response) => {
        // Handle redirects
        if (
          response.statusCode &&
          response.statusCode >= 300 &&
          response.statusCode < 400 &&
          response.headers.location
        ) {
          file.close();
          fs.unlinkSync(dest);
          return downloadFile(response.headers.location, dest).then(
            resolve,
            reject,
          );
        }

        response.pipe(file);
        file.on('finish', () => {
          file.close();
          resolve();
        });
      })
      .on('error', (err) => {
        fs.unlinkSync(dest);
        reject(err);
      });
  });
}

function parsePipeDelimited(
  filePath: string,
): Promise<Record<string, string>[]> {
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
        }),
      )
      .on('data', (record: Record<string, string>) => records.push(record))
      .on('end', () => resolve(records))
      .on('error', reject);
  });
}

function parseCoordinate(dms: string): number | null {
  if (!dms) return null;

  // Handle decimal format
  const decimal = parseFloat(dms);
  if (!isNaN(decimal) && Math.abs(decimal) <= 180) return decimal;

  // Handle DMS format: e.g. "39-54-32.6800N" or "104-50-56.1100W"
  const match = dms.match(
    /(\d+)-(\d+)-([\d.]+)([NSEW])/,
  );
  if (!match) return null;

  const deg = parseInt(match[1]);
  const min = parseInt(match[2]);
  const sec = parseFloat(match[3]);
  const dir = match[4];

  let result = deg + min / 60 + sec / 3600;
  if (dir === 'S' || dir === 'W') result = -result;
  return result;
}

async function seedAirports(ds: DataSource): Promise<number> {
  const aptFile = findFile(NASR_DIR, 'APT_BASE.csv', 'APT.csv');
  if (!aptFile) {
    console.log('  Airport file not found, seeding sample data instead...');
    return seedSampleAirports(ds);
  }

  console.log(`  Reading ${aptFile}...`);
  const records = await parsePipeDelimited(aptFile);
  console.log(`  Parsed ${records.length} records`);

  const repo = ds.getRepository(Airport);
  let count = 0;

  // Process in batches
  const batchSize = 500;
  for (let i = 0; i < records.length; i += batchSize) {
    const batch = records.slice(i, i + batchSize);
    const airports: Partial<Airport>[] = [];

    for (const r of batch) {
      const identifier =
        r['LOCATION IDENTIFIER'] || r['ARPT_ID'] || r['LocationID'];
      if (!identifier) continue;

      airports.push({
        identifier: identifier.trim(),
        icao_identifier:
          (r['ICAO_ID'] || r['ICAO'] || '').trim() || undefined,
        name: (
          r['OFFICIAL FACILITY NAME'] ||
          r['ARPT_NAME'] ||
          r['FacilityName'] ||
          ''
        ).trim(),
        city: (r['CITY'] || r['City'] || '').trim() || undefined,
        state: (r['STATE'] || r['State'] || '').trim() || undefined,
        latitude: parseCoordinate(
          r['ARP LATITUDE'] ||
            r['ARPLatitude'] ||
            r['LATITUDE'] ||
            r['Lat'] ||
            '',
        ) ?? undefined,
        longitude: parseCoordinate(
          r['ARP LONGITUDE'] ||
            r['ARPLongitude'] ||
            r['LONGITUDE'] ||
            r['Lon'] ||
            '',
        ) ?? undefined,
        elevation: parseFloat(
          r['FIELD ELEVATION'] ||
            r['ARPElevation'] ||
            r['ELEVATION'] ||
            r['Elev'] ||
            '0',
        ) || undefined,
        magnetic_variation:
          (r['MAGNETIC VARIATION'] || r['MagVar'] || '').trim() || undefined,
        ownership_type:
          (r['OWNERSHIP TYPE'] || r['OwnershipType'] || '').trim() || undefined,
        facility_type:
          (r['FACILITY TYPE'] || r['FacilityType'] || r['TYPE'] || '').trim() || undefined,
        status:
          (r['FACILITY STATUS'] || r['Status'] || '').trim() || 'O',
      });
    }

    if (airports.length > 0) {
      await repo.save(airports as Airport[]);
      count += airports.length;
    }
  }

  return count;
}

async function seedSampleAirports(ds: DataSource): Promise<number> {
  const repo = ds.getRepository(Airport);
  const sampleAirports: Partial<Airport>[] = [
    {
      identifier: 'APA',
      icao_identifier: 'KAPA',
      name: 'Centennial',
      city: 'Denver',
      state: 'CO',
      latitude: 39.5701,
      longitude: -104.8493,
      elevation: 5885,
      facility_type: 'AIRPORT',
      status: 'O',
    },
    {
      identifier: 'BJC',
      icao_identifier: 'KBJC',
      name: 'Rocky Mountain Metropolitan',
      city: 'Denver',
      state: 'CO',
      latitude: 39.9088,
      longitude: -105.1172,
      elevation: 5673,
      facility_type: 'AIRPORT',
      status: 'O',
    },
    {
      identifier: 'DEN',
      icao_identifier: 'KDEN',
      name: 'Denver International',
      city: 'Denver',
      state: 'CO',
      latitude: 39.8561,
      longitude: -104.6737,
      elevation: 5431,
      facility_type: 'AIRPORT',
      status: 'O',
    },
    {
      identifier: 'FNL',
      icao_identifier: 'KFNL',
      name: 'Northern Colorado Regional',
      city: 'Fort Collins',
      state: 'CO',
      latitude: 40.4518,
      longitude: -105.0113,
      elevation: 5016,
      facility_type: 'AIRPORT',
      status: 'O',
    },
    {
      identifier: 'CFO',
      icao_identifier: 'KCFO',
      name: 'Colorado Springs / Peterson Field',
      city: 'Colorado Springs',
      state: 'CO',
      latitude: 38.8058,
      longitude: -104.7006,
      elevation: 6187,
      facility_type: 'AIRPORT',
      status: 'O',
    },
    {
      identifier: 'BDU',
      icao_identifier: 'KBDU',
      name: 'Boulder Municipal',
      city: 'Boulder',
      state: 'CO',
      latitude: 40.0393,
      longitude: -105.2256,
      elevation: 5288,
      facility_type: 'AIRPORT',
      status: 'O',
    },
    {
      identifier: 'EIK',
      icao_identifier: 'KEIK',
      name: 'Erie Municipal',
      city: 'Erie',
      state: 'CO',
      latitude: 40.0102,
      longitude: -105.0481,
      elevation: 5130,
      facility_type: 'AIRPORT',
      status: 'O',
    },
    {
      identifier: 'LMO',
      icao_identifier: 'KLMO',
      name: 'Vance Brand',
      city: 'Longmont',
      state: 'CO',
      latitude: 40.1637,
      longitude: -105.1633,
      elevation: 5055,
      facility_type: 'AIRPORT',
      status: 'O',
    },
    {
      identifier: 'GXY',
      icao_identifier: 'KGXY',
      name: 'Greeley-Weld County',
      city: 'Greeley',
      state: 'CO',
      latitude: 40.4374,
      longitude: -104.6332,
      elevation: 4697,
      facility_type: 'AIRPORT',
      status: 'O',
    },
    {
      identifier: 'BKF',
      icao_identifier: 'KBKF',
      name: 'Buckley Space Force Base',
      city: 'Aurora',
      state: 'CO',
      latitude: 39.7017,
      longitude: -104.7517,
      elevation: 5662,
      facility_type: 'AIRPORT',
      status: 'O',
    },
  ];

  await repo.save(sampleAirports as Airport[]);

  // Add sample runways for KBJC
  const rwyRepo = ds.getRepository(Runway);
  const endRepo = ds.getRepository(RunwayEnd);

  const rwy1 = await rwyRepo.save({
    airport_identifier: 'BJC',
    identifiers: '03/21',
    length: 3600,
    width: 75,
    surface: 'Asphalt',
    condition: 'Fair',
  } as Runway);

  await endRepo.save([
    {
      runway_id: rwy1.id,
      identifier: '03',
      heading: 25,
      elevation: 5673,
      tora: 3600,
      toda: 3600,
      asda: 3600,
      lda: 3600,
      traffic_pattern: 'Left',
    } as RunwayEnd,
    {
      runway_id: rwy1.id,
      identifier: '21',
      heading: 205,
      elevation: 5620,
      tora: 3600,
      toda: 3600,
      asda: 3600,
      lda: 3600,
      glideslope: '2-light PAPI (on left)',
      lighting_edge: 'Medium Intensity',
      traffic_pattern: 'Right',
      latitude: 39.91,
      longitude: -105.11,
    } as RunwayEnd,
  ]);

  const rwy2 = await rwyRepo.save({
    airport_identifier: 'BJC',
    identifiers: '12L/30R',
    length: 9000,
    width: 100,
    surface: 'Asphalt',
    condition: 'Good',
  } as Runway);

  await endRepo.save([
    {
      runway_id: rwy2.id,
      identifier: '12L',
      heading: 118,
      elevation: 5673,
      tora: 9000,
      toda: 9000,
      asda: 9000,
      lda: 9000,
      traffic_pattern: 'Left',
    } as RunwayEnd,
    {
      runway_id: rwy2.id,
      identifier: '30R',
      heading: 298,
      elevation: 5660,
      tora: 9000,
      toda: 9000,
      asda: 9000,
      lda: 9000,
      traffic_pattern: 'Right',
    } as RunwayEnd,
  ]);

  const rwy3 = await rwyRepo.save({
    airport_identifier: 'BJC',
    identifiers: '12R/30L',
    length: 7002,
    width: 75,
    surface: 'Asphalt',
    condition: 'Good',
  } as Runway);

  await endRepo.save([
    {
      runway_id: rwy3.id,
      identifier: '12R',
      heading: 118,
      elevation: 5670,
      tora: 7002,
      toda: 7002,
      asda: 7002,
      lda: 7002,
      traffic_pattern: 'Right',
    } as RunwayEnd,
    {
      runway_id: rwy3.id,
      identifier: '30L',
      heading: 298,
      elevation: 5655,
      tora: 7002,
      toda: 7002,
      asda: 7002,
      lda: 7002,
      traffic_pattern: 'Left',
    } as RunwayEnd,
  ]);

  // Add sample frequencies for KBJC
  const freqRepo = ds.getRepository(Frequency);
  await freqRepo.save([
    {
      airport_identifier: 'BJC',
      type: 'ATIS',
      name: 'ATIS',
      frequency: '126.25',
      phone: '(303) 466-8744',
    },
    {
      airport_identifier: 'BJC',
      type: 'AWOS',
      name: 'AWOS-3',
      phone: '(720) 887-8067',
    },
    {
      airport_identifier: 'BJC',
      type: 'CD',
      name: 'Metro Clearance Delivery',
      frequency: '132.6',
    },
    {
      airport_identifier: 'BJC',
      type: 'GND',
      name: 'Metro Ground',
      frequency: '121.7',
    },
    {
      airport_identifier: 'BJC',
      type: 'TWR',
      name: 'Metro Tower',
      frequency: '118.6',
    },
    {
      airport_identifier: 'BJC',
      type: 'APP',
      name: 'Denver Approach',
      frequency: '120.3',
    },
    {
      airport_identifier: 'BJC',
      type: 'DEP',
      name: 'Denver Departure',
      frequency: '128.3',
    },
    {
      airport_identifier: 'BJC',
      type: 'UNIC',
      name: 'UNICOM',
      frequency: '122.95',
    },
  ] as Frequency[]);

  return sampleAirports.length;
}

function findFile(dir: string, ...names: string[]): string | null {
  if (!fs.existsSync(dir)) return null;

  for (const name of names) {
    const filePath = path.join(dir, name);
    if (fs.existsSync(filePath)) return filePath;
  }

  // Search subdirectories
  try {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      if (entry.isDirectory()) {
        const result = findFile(path.join(dir, entry.name), ...names);
        if (result) return result;
      }
    }
  } catch {
    // ignore
  }

  return null;
}

async function main() {
  console.log('=== EFB NASR Data Seed ===\n');

  const ds = await initDataSource();
  console.log('Database initialized.\n');

  // Clear existing data
  console.log('Clearing existing data...');
  await ds.getRepository(RunwayEnd).clear();
  await ds.getRepository(Runway).clear();
  await ds.getRepository(Frequency).clear();
  await ds.getRepository(Airport).clear();
  console.log('  Done.\n');

  // Seed airports
  console.log('Seeding airports...');
  const airportCount = await seedAirports(ds);
  console.log(`  Imported ${airportCount} airports.\n`);

  // Summary
  const totalRunways = await ds.getRepository(Runway).count();
  const totalFreqs = await ds.getRepository(Frequency).count();
  console.log('=== Seed Complete ===');
  console.log(`  Airports:    ${airportCount}`);
  console.log(`  Runways:     ${totalRunways}`);
  console.log(`  Frequencies: ${totalFreqs}`);

  await ds.destroy();
}

main().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
