/**
 * FAA NASR Data Seed Script
 *
 * Downloads the current FAA NASR 28-day subscription data and imports
 * airports, runways, runway ends, and frequencies into the PostgreSQL database.
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
import {
  parsePipeDelimited,
  parseCoordinate,
  findFile,
  ensureNasrData,
} from './seed-utils';
import { dbConfig } from '../db.config';

const DATA_DIR = path.join(__dirname, '..', '..', 'data');
const NASR_DIR = path.join(DATA_DIR, 'nasr');

async function initDataSource(): Promise<DataSource> {
  const ds = new DataSource({
    ...dbConfig,
    entities: [Airport, Runway, RunwayEnd, Frequency],
  });

  await ds.initialize();
  return ds;
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
      const identifier = r['ARPT_ID'];
      if (!identifier) continue;

      airports.push({
        identifier: identifier.trim(),
        icao_identifier: (r['ICAO_ID'] || '').trim() || undefined,
        name: (r['ARPT_NAME'] || '').trim(),
        city: (r['CITY'] || '').trim() || undefined,
        state: (r['STATE_CODE'] || '').trim() || undefined,
        latitude: parseFloat(r['LAT_DECIMAL'] || '') || undefined,
        longitude: parseFloat(r['LONG_DECIMAL'] || '') || undefined,
        elevation: parseFloat(r['ELEV'] || '0') || undefined,
        magnetic_variation: (r['MAG_VARN'] || '').trim() || undefined,
        ownership_type: (r['OWNERSHIP_TYPE_CODE'] || '').trim() || undefined,
        facility_type: (r['SITE_TYPE_CODE'] || '').trim() || undefined,
        status: (r['ARPT_STATUS'] || '').trim() || 'O',
        tpa: parseInt(r['TPA'] || '', 10) || undefined,
        fuel_types: (r['FUEL_TYPES'] || '').trim() || undefined,
        facility_use: (r['FACILITY_USE_CODE'] || '').trim() || undefined,
        artcc_id: (r['RESP_ARTCC_ID'] || '').trim() || undefined,
        artcc_name: (r['ARTCC_NAME'] || '').trim() || undefined,
        fss_id: (r['FSS_ID'] || '').trim() || undefined,
        fss_name: (r['FSS_NAME'] || '').trim() || undefined,
        notam_id: (r['NOTAM_ID'] || '').trim() || undefined,
        sectional_chart: (r['CHART_NAME'] || '').trim() || undefined,
        customs_flag: (r['CUST_FLAG'] || '').trim() || undefined,
        landing_rights_flag: (r['LNDG_RIGHTS_FLAG'] || '').trim() || undefined,
        lighting_schedule: (r['LGT_SKED'] || '').trim() || undefined,
        beacon_schedule: (r['BCN_LGT_SKED'] || '').trim() || undefined,
        nasr_effective_date: (r['EFF_DATE'] || '').trim() || undefined,
      });
    }

    if (airports.length > 0) {
      await repo.save(airports as Airport[]);
      count += airports.length;
    }
  }

  return count;
}

async function seedRunways(
  ds: DataSource,
): Promise<{ runways: number; ends: number }> {
  const rwyFile = findFile(NASR_DIR, 'APT_RWY.csv');
  const rwyEndFile = findFile(NASR_DIR, 'APT_RWY_END.csv');
  if (!rwyFile || !rwyEndFile) {
    console.log('  Runway CSV files not found, skipping...');
    return { runways: 0, ends: 0 };
  }

  // Seed runways
  console.log(`  Reading ${rwyFile}...`);
  const rwyRecords = await parsePipeDelimited(rwyFile);
  console.log(`  Parsed ${rwyRecords.length} runway records`);

  const rwyRepo = ds.getRepository(Runway);
  let rwyCount = 0;

  // Map (ARPT_ID, RWY_ID) → saved runway id for linking ends
  const rwyLookup = new Map<string, number>();

  const batchSize = 500;
  for (let i = 0; i < rwyRecords.length; i += batchSize) {
    const batch = rwyRecords.slice(i, i + batchSize);
    const runways: Partial<Runway>[] = [];

    for (const r of batch) {
      const aptId = (r['ARPT_ID'] || '').trim();
      const rwyId = (r['RWY_ID'] || '').trim();
      if (!aptId || !rwyId) continue;

      runways.push({
        airport_identifier: aptId,
        identifiers: rwyId,
        length: parseInt(r['RWY_LEN'] || '', 10) || undefined,
        width: parseInt(r['RWY_WIDTH'] || '', 10) || undefined,
        surface: (r['SURFACE_TYPE_CODE'] || '').trim() || undefined,
        condition: (r['COND'] || '').trim() || undefined,
      });
    }

    if (runways.length > 0) {
      const saved = await rwyRepo.save(runways as Runway[]);
      for (const rwy of saved) {
        rwyLookup.set(`${rwy.airport_identifier}:${rwy.identifiers}`, rwy.id);
      }
      rwyCount += saved.length;
    }
  }

  console.log(`  Imported ${rwyCount} runways.`);

  // Seed runway ends
  console.log(`  Reading ${rwyEndFile}...`);
  const endRecords = await parsePipeDelimited(rwyEndFile);
  console.log(`  Parsed ${endRecords.length} runway end records`);

  const endRepo = ds.getRepository(RunwayEnd);
  let endCount = 0;

  for (let i = 0; i < endRecords.length; i += batchSize) {
    const batch = endRecords.slice(i, i + batchSize);
    const ends: Partial<RunwayEnd>[] = [];

    for (const r of batch) {
      const aptId = (r['ARPT_ID'] || '').trim();
      const rwyId = (r['RWY_ID'] || '').trim();
      const endId = (r['RWY_END_ID'] || '').trim();
      if (!aptId || !rwyId || !endId) continue;

      const runwayId = rwyLookup.get(`${aptId}:${rwyId}`);
      if (!runwayId) continue;

      const rightTraffic = (r['RIGHT_HAND_TRAFFIC_PAT_FLAG'] || '').trim();

      ends.push({
        runway_id: runwayId,
        identifier: endId,
        heading: parseFloat(r['TRUE_ALIGNMENT'] || '') || undefined,
        elevation: parseFloat(r['RWY_END_ELEV'] || '') || undefined,
        latitude: parseFloat(r['LAT_DECIMAL'] || '') || undefined,
        longitude: parseFloat(r['LONG_DECIMAL'] || '') || undefined,
        tora: parseInt(r['TKOF_RUN_AVBL'] || '', 10) || undefined,
        toda: parseInt(r['TKOF_DIST_AVBL'] || '', 10) || undefined,
        asda: parseInt(r['ACLT_STOP_DIST_AVBL'] || '', 10) || undefined,
        lda: parseInt(r['LNDG_DIST_AVBL'] || '', 10) || undefined,
        glideslope: (r['VGSI_CODE'] || '').trim() || undefined,
        lighting_approach:
          (r['APCH_LGT_SYSTEM_CODE'] || '').trim() || undefined,
        traffic_pattern: rightTraffic === 'Y' ? 'Right' : 'Left',
        displaced_threshold:
          parseInt(r['DISPLACED_THR_LEN'] || '', 10) || undefined,
      });
    }

    if (ends.length > 0) {
      await endRepo.save(ends as RunwayEnd[]);
      endCount += ends.length;
    }
  }

  console.log(`  Imported ${endCount} runway ends.`);
  return { runways: rwyCount, ends: endCount };
}

/**
 * Parse TWR3 records from the NASR TWR.txt fixed-width file.
 * Each TWR3 record has: identifier (pos 5-8), then up to 9 freq/use pairs.
 * Freq: 44 chars, Use: 50 chars, repeating from position 9.
 */
async function seedFrequencies(ds: DataSource): Promise<number> {
  const twrFile = path.join(NASR_DIR, 'TWR.txt');
  if (!fs.existsSync(twrFile)) {
    console.log('  TWR.txt not found, skipping frequencies...');
    return 0;
  }

  console.log(`  Reading ${twrFile} (TWR3 records)...`);
  const content = fs.readFileSync(twrFile, 'utf-8');
  const lines = content.split('\n').filter((l) => l.startsWith('TWR3'));
  console.log(`  Found ${lines.length} TWR3 records`);

  // Build set of valid airport identifiers to filter out non-airport facilities
  const airportIds = new Set<string>(
    (
      await ds
        .getRepository(Airport)
        .createQueryBuilder('a')
        .select('a.identifier')
        .getMany()
    ).map((a) => a.identifier),
  );

  const repo = ds.getRepository(Frequency);
  const freqs: Partial<Frequency>[] = [];

  // Map frequency use codes to friendly types
  const useToType = (use: string): string => {
    const u = use.toUpperCase();
    if (u.includes('ATIS')) return 'ATIS';
    if (u.includes('GND')) return 'GND';
    if (u.includes('LCL') || u.includes('TWR')) return 'TWR';
    if (u.includes('CD') || u.includes('CLNC')) return 'CD';
    if (u.includes('APCH')) return 'APP';
    if (u.includes('DEP')) return 'DEP';
    if (u.includes('CTAF')) return 'CTAF';
    if (u.includes('UNIC')) return 'UNIC';
    if (u.includes('EMERG')) return 'EMERG';
    return use.split('/')[0].trim();
  };

  for (const line of lines) {
    const identifier = line.substring(4, 8).trim();
    if (!identifier || !airportIds.has(identifier)) continue;

    // Up to 9 frequency/use pairs, each: 44 chars freq + 50 chars use
    const PAIR_START = 8;
    const FREQ_LEN = 44;
    const USE_LEN = 50;
    const PAIR_LEN = FREQ_LEN + USE_LEN;

    for (let p = 0; p < 9; p++) {
      const offset = PAIR_START + p * PAIR_LEN;
      const freqStr = line.substring(offset, offset + FREQ_LEN).trim();
      const useStr = line
        .substring(offset + FREQ_LEN, offset + PAIR_LEN)
        .trim();

      if (!freqStr) continue;

      freqs.push({
        airport_identifier: identifier,
        type: useToType(useStr),
        name: useStr || undefined,
        frequency: freqStr,
      });
    }
  }

  console.log(`  Parsed ${freqs.length} frequencies`);

  // Batch insert
  const batchSize = 500;
  let count = 0;
  for (let i = 0; i < freqs.length; i += batchSize) {
    const batch = freqs.slice(i, i + batchSize);
    await repo.save(batch as Frequency[]);
    count += batch.length;
  }

  return count;
}

async function seedContacts(ds: DataSource): Promise<number> {
  const conFile = findFile(NASR_DIR, 'APT_CON.csv');
  if (!conFile) {
    console.log('  APT_CON.csv not found, skipping contacts...');
    return 0;
  }

  console.log(`  Reading ${conFile}...`);
  const records = await parsePipeDelimited(conFile);
  console.log(`  Parsed ${records.length} contact records`);

  const repo = ds.getRepository(Airport);

  // Build map: ARPT_ID → { manager_*, owner_* }
  const contactMap = new Map<string, Partial<Airport>>();

  for (const r of records) {
    const aptId = (r['ARPT_ID'] || '').trim();
    const title = (r['TITLE'] || '').trim().toUpperCase();
    if (!aptId || (!title.includes('MANAGER') && !title.includes('OWNER')))
      continue;

    const name = (r['NAME'] || '').trim() || undefined;
    const phone = (r['PHONE_NO'] || '').trim() || undefined;

    // Compose address
    const parts: string[] = [];
    const addr1 = (r['ADDRESS1'] || '').trim();
    if (addr1) parts.push(addr1);
    const city = (r['TITLE_CITY'] || '').trim();
    const state = (r['STATE'] || '').trim();
    const zip = (r['ZIP_CODE'] || '').trim();
    const cityStateZip =
      [city, state].filter(Boolean).join(', ') + (zip ? ` ${zip}` : '');
    if (cityStateZip.trim()) parts.push(cityStateZip.trim());
    const address = parts.join(', ') || undefined;

    if (!contactMap.has(aptId)) contactMap.set(aptId, {});
    const entry = contactMap.get(aptId)!;

    if (title.includes('MANAGER')) {
      entry.manager_name = name;
      entry.manager_phone = phone;
      entry.manager_address = address;
    } else if (title.includes('OWNER')) {
      entry.owner_name = name;
      entry.owner_phone = phone;
      entry.owner_address = address;
    }
  }

  // Batch update airports
  let count = 0;
  const entries = Array.from(contactMap.entries());
  const batchSize = 500;
  for (let i = 0; i < entries.length; i += batchSize) {
    const batch = entries.slice(i, i + batchSize);
    for (const [aptId, data] of batch) {
      await repo.update(aptId, data);
      count++;
    }
  }

  return count;
}

async function seedTowerHours(ds: DataSource): Promise<number> {
  const atcFile = findFile(NASR_DIR, 'ATC_BASE.csv');
  if (!atcFile) {
    console.log('  ATC_BASE.csv not found, skipping tower hours...');
    return 0;
  }

  console.log(`  Reading ${atcFile}...`);
  const records = await parsePipeDelimited(atcFile);
  console.log(`  Parsed ${records.length} ATC records`);

  const repo = ds.getRepository(Airport);

  // Build set of valid airport identifiers
  const airportIds = new Set<string>(
    (await repo.createQueryBuilder('a').select('a.identifier').getMany()).map(
      (a) => a.identifier,
    ),
  );

  let count = 0;
  for (const r of records) {
    const facilityId = (r['FACILITY_ID'] || '').trim();
    const towerHrs = (r['TWR_HRS'] || '').trim();
    if (!facilityId || !towerHrs || !airportIds.has(facilityId)) continue;

    await repo.update(facilityId, { tower_hours: towerHrs });
    count++;
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
      tpa: 6673,
      fuel_types: '100LL,JET-A',
      facility_use: 'PU',
      artcc_id: 'ZDV',
      artcc_name: 'DENVER',
      fss_id: 'DEN',
      fss_name: 'DENVER',
      notam_id: 'BJC',
      sectional_chart: 'DENVER',
      customs_flag: 'N',
      landing_rights_flag: 'N',
      lighting_schedule: 'SS-SR',
      beacon_schedule: 'SS-SR',
      nasr_effective_date: '2026/01/22',
      tower_hours: '0600-2200',
      manager_name: 'PAUL QUINNETT',
      manager_phone: '(303) 271-4850',
      manager_address: '11755 AIRPORT WAY, BROOMFIELD, CO 80021',
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

async function seedDatisCapability(ds: DataSource): Promise<number> {
  const repo = ds.getRepository(Airport);

  // Find towered airports with ICAO identifiers — these are candidates for D-ATIS
  const toweredAirports = await repo
    .createQueryBuilder('a')
    .select(['a.identifier', 'a.icao_identifier'])
    .where('a.tower_hours IS NOT NULL')
    .andWhere('a.icao_identifier IS NOT NULL')
    .getMany();

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

    // Progress
    const checked = Math.min(i + batchSize, toweredAirports.length);
    if (checked % 100 === 0 || checked === toweredAirports.length) {
      console.log(`  Checked ${checked}/${toweredAirports.length} (${count} with D-ATIS so far)`);
    }
  }

  return count;
}

async function main() {
  console.log('=== EFB NASR Data Seed ===\n');

  // Download + extract NASR data if not already present
  await ensureNasrData(NASR_DIR);

  const ds = await initDataSource();
  console.log('Database initialized.\n');

  // Clear existing data (CASCADE needed for Postgres foreign key constraints)
  console.log('Clearing existing data...');
  await ds.query(
    'TRUNCATE TABLE a_runway_ends, a_runways, a_frequencies, a_airports CASCADE',
  );
  console.log('  Done.\n');

  // Seed airports
  console.log('Seeding airports...');
  const airportCount = await seedAirports(ds);
  console.log(`  Imported ${airportCount} airports.\n`);

  // Seed contacts (must be after airports)
  console.log('Seeding contacts...');
  const contactCount = await seedContacts(ds);
  console.log(`  Updated ${contactCount} airports with contacts.\n`);

  // Seed tower hours (must be after airports)
  console.log('Seeding tower hours...');
  const towerCount = await seedTowerHours(ds);
  console.log(`  Updated ${towerCount} airports with tower hours.\n`);

  // Seed runways + runway ends
  console.log('Seeding runways...');
  const { runways: rwyCount, ends: endCount } = await seedRunways(ds);
  console.log('');

  // Seed frequencies from TWR.txt
  console.log('Seeding frequencies...');
  const freqCount = await seedFrequencies(ds);
  console.log(`  Imported ${freqCount} frequencies.\n`);

  // Seed D-ATIS capability (must be after airports + tower hours)
  console.log('Seeding D-ATIS capability...');
  const datisCount = await seedDatisCapability(ds);
  console.log(`  Marked ${datisCount} airports with D-ATIS.\n`);

  // Summary
  console.log('=== Seed Complete ===');
  console.log(`  Airports:     ${airportCount}`);
  console.log(`  Contacts:     ${contactCount}`);
  console.log(`  Tower Hours:  ${towerCount}`);
  console.log(`  Runways:      ${rwyCount}`);
  console.log(`  Runway Ends:  ${endCount}`);
  console.log(`  Frequencies:  ${freqCount}`);
  console.log(`  D-ATIS:       ${datisCount}`);

  await ds.destroy();
}

main().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
