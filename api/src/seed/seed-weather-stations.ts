/**
 * Weather Station Seed Script
 *
 * Discovers non-airport METAR stations by fetching bulk METARs from AWC,
 * cross-referencing against the airports DB, then fetching stationinfo
 * metadata for the unmatched ones.
 *
 * Usage: npx ts-node -r tsconfig-paths/register src/seed/seed-weather-stations.ts
 */

import { DataSource } from 'typeorm';
import { WeatherStation } from '../weather/entities/weather-station.entity';
import { Airport } from '../airports/entities/airport.entity';
import { Runway } from '../airports/entities/runway.entity';
import { RunwayEnd } from '../airports/entities/runway-end.entity';
import { Frequency } from '../airports/entities/frequency.entity';
import { Fbo } from '../fbos/entities/fbo.entity';
import { FuelPrice } from '../fbos/entities/fuel-price.entity';
import { dbConfig } from '../db.config';

const AWC_METAR_URL = 'https://aviationweather.gov/api/data/metar';
const AWC_STATIONINFO_URL = 'https://aviationweather.gov/api/data/stationinfo';

// Split CONUS into regional bboxes to get full coverage
const REGIONS = [
  { name: 'NW', bbox: '42,-130,50,-104' },
  { name: 'NE', bbox: '42,-104,50,-60' },
  { name: 'SW', bbox: '24,-130,42,-104' },
  { name: 'SE', bbox: '24,-104,42,-60' },
];

async function initDataSource(): Promise<DataSource> {
  const ds = new DataSource({
    ...dbConfig,
    // Airport has OneToMany relations that require related entities
    entities: [
      WeatherStation,
      Airport,
      Runway,
      RunwayEnd,
      Frequency,
      Fbo,
      FuelPrice,
    ],
  });
  await ds.initialize();
  return ds;
}

/**
 * Fetch all unique METAR station IDs from AWC by querying regional bboxes.
 */
async function discoverMetarStations(): Promise<
  Map<string, { lat: number; lon: number }>
> {
  const stations = new Map<string, { lat: number; lon: number }>();

  for (const region of REGIONS) {
    console.log(`  Fetching METARs for ${region.name} (${region.bbox})...`);
    const url = `${AWC_METAR_URL}?bbox=${region.bbox}&format=json&hours=3`;
    const response = await fetch(url);
    if (!response.ok) {
      console.warn(
        `  Warning: METAR fetch for ${region.name} returned ${response.status}`,
      );
      continue;
    }
    const data = await response.json();
    if (!Array.isArray(data)) continue;

    for (const m of data) {
      const icao = m.icaoId;
      if (!icao || stations.has(icao)) continue;
      const lat = parseFloat(m.lat);
      const lon = parseFloat(m.lon);
      if (!isNaN(lat) && !isNaN(lon)) {
        stations.set(icao, { lat, lon });
      }
    }
    console.log(
      `    ${data.length} METARs, ${stations.size} unique stations so far`,
    );
  }

  return stations;
}

/**
 * Fetch station metadata from AWC stationinfo for a batch of IDs.
 */
async function fetchStationInfo(ids: string[]): Promise<Map<string, any>> {
  const result = new Map<string, any>();
  // AWC limits query string length; batch in groups of 50
  const batchSize = 50;
  for (let i = 0; i < ids.length; i += batchSize) {
    const batch = ids.slice(i, i + batchSize);
    const idsParam = batch.join(',');
    const url = `${AWC_STATIONINFO_URL}?ids=${idsParam}&format=json`;
    try {
      const response = await fetch(url);
      if (!response.ok) continue;
      const data = await response.json();
      if (!Array.isArray(data)) continue;
      for (const s of data) {
        const icao = s.icaoId || s.id;
        if (icao) result.set(icao, s);
      }
    } catch (err) {
      console.warn(`  Warning: stationinfo batch failed: ${err}`);
    }
  }
  return result;
}

async function getAirportIcaoIds(ds: DataSource): Promise<Set<string>> {
  const airportRepo = ds.getRepository(Airport);
  const airports = await airportRepo.find({
    select: ['icao_identifier'],
  });
  const ids = new Set<string>();
  for (const a of airports) {
    if (a.icao_identifier) {
      ids.add(a.icao_identifier.toUpperCase());
    }
  }
  console.log(`  Found ${ids.size} airports with ICAO identifiers.`);
  return ids;
}

async function seedWeatherStations(ds: DataSource): Promise<number> {
  // Step 1: Discover all stations reporting METARs
  console.log('Step 1: Discovering METAR stations...');
  const metarStations = await discoverMetarStations();
  console.log(`  Total unique METAR stations: ${metarStations.size}`);

  // Step 2: Get airport ICAO IDs from DB
  console.log('\nStep 2: Cross-referencing with airports DB...');
  const airportIds = await getAirportIcaoIds(ds);

  // Step 2b: Update airports that have METARs
  const matchedIcaos: string[] = [];
  const unmatchedIds: string[] = [];
  for (const icao of metarStations.keys()) {
    if (airportIds.has(icao.toUpperCase())) {
      matchedIcaos.push(icao.toUpperCase());
    } else {
      unmatchedIds.push(icao);
    }
  }
  console.log(`  ${matchedIcaos.length} airports have METARs.`);
  console.log(`  ${unmatchedIds.length} METAR stations not in airports DB.`);

  // Batch update has_metar on matching airports
  if (matchedIcaos.length > 0) {
    const airportRepo = ds.getRepository(Airport);
    const batchSize = 500;
    for (let i = 0; i < matchedIcaos.length; i += batchSize) {
      const batch = matchedIcaos.slice(i, i + batchSize);
      await airportRepo
        .createQueryBuilder()
        .update()
        .set({ has_metar: true })
        .where('icao_identifier IN (:...ids)', { ids: batch })
        .execute();
    }
    console.log(
      `  Updated ${matchedIcaos.length} airports with has_metar = true.`,
    );
  }

  // Step 2c: Determine TAF capability for airport stations
  console.log(
    '\n  Fetching stationinfo for airport ICAOs to check TAF capability...',
  );
  const airportStationInfo = await fetchStationInfo(matchedIcaos);
  const tafIcaos: string[] = [];
  for (const [icao, info] of airportStationInfo) {
    const siteTypes: string[] = info?.siteType ?? [];
    if (siteTypes.includes('TAF')) {
      tafIcaos.push(icao.toUpperCase());
    }
  }
  console.log(`  ${tafIcaos.length} airports have TAF capability.`);

  if (tafIcaos.length > 0) {
    const airportRepo = ds.getRepository(Airport);
    const batchSize = 500;
    for (let i = 0; i < tafIcaos.length; i += batchSize) {
      const batch = tafIcaos.slice(i, i + batchSize);
      await airportRepo
        .createQueryBuilder()
        .update()
        .set({ has_taf: true })
        .where('icao_identifier IN (:...ids)', { ids: batch })
        .execute();
    }
    console.log(`  Updated ${tafIcaos.length} airports with has_taf = true.`);
  }

  // Step 3: Find unmatched stations (already computed above)

  if (unmatchedIds.length === 0) {
    return 0;
  }

  // Step 4: Fetch metadata for unmatched stations
  console.log('\nStep 3: Fetching station metadata from AWC...');
  const stationInfo = await fetchStationInfo(unmatchedIds);
  console.log(
    `  Got metadata for ${stationInfo.size} of ${unmatchedIds.length} stations.`,
  );

  // Step 5: Build insert records
  const repo = ds.getRepository(WeatherStation);
  const toInsert: Partial<WeatherStation>[] = [];

  for (const icao of unmatchedIds) {
    const info = stationInfo.get(icao);
    const metar = metarStations.get(icao);

    const lat = info?.lat ?? metar?.lat;
    const lon = info?.lon ?? metar?.lon;
    if (lat == null || lon == null) continue;

    // Only include US stations
    const country = (info?.country || '').toUpperCase();
    if (country && country !== 'US') continue;

    const siteTypes: string[] = info?.siteType ?? [];

    toInsert.push({
      icao_id: icao,
      name: (info?.site || icao).trim(),
      latitude: lat,
      longitude: lon,
      elevation: info?.elev != null ? parseFloat(info.elev) : undefined,
      state: (info?.state || '').trim() || undefined,
      country: country || 'US',
      priority: info?.priority != null ? parseInt(info.priority, 10) : 0,
      has_metar: true, // all discovered via METAR data
      has_taf: siteTypes.includes('TAF'),
    });
  }

  console.log(`\n  ${toInsert.length} weather stations to insert.`);

  // Batch insert
  const batchSize = 500;
  let count = 0;
  for (let i = 0; i < toInsert.length; i += batchSize) {
    const batch = toInsert.slice(i, i + batchSize);
    await repo.save(batch as WeatherStation[]);
    count += batch.length;
  }

  return count;
}

async function main() {
  console.log('=== EFB Weather Station Seed ===\n');

  const ds = await initDataSource();
  console.log('Database initialized.\n');

  // Clear existing weather station data
  console.log('Clearing existing weather stations...');
  await ds.query('TRUNCATE TABLE a_weather_stations CASCADE');
  console.log('  Done.\n');

  // Seed weather stations
  const count = await seedWeatherStations(ds);
  console.log(`\n=== Seed Complete ===`);
  console.log(`  Weather stations: ${count}`);

  await ds.destroy();
}

main().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
