/**
 * FAA NASR Airspace, Airway, and ARTCC Boundary Seed Script
 *
 * Seeds airspace polygons from shapefiles, airway segments from CSV,
 * and ARTCC boundaries from CSV into the database.
 *
 * Usage: npx ts-node -r tsconfig-paths/register src/seed/seed-airspaces.ts
 */

import { DataSource } from 'typeorm';
import { Airspace } from '../airspaces/entities/airspace.entity';
import { AirwaySegment } from '../airspaces/entities/airway-segment.entity';
import { ArtccBoundary } from '../airspaces/entities/artcc-boundary.entity';
import { Navaid } from '../navaids/entities/navaid.entity';
import { Fix } from '../navaids/entities/fix.entity';
import * as path from 'path';
import * as shapefile from 'shapefile';
import { parsePipeDelimited, findFile, ensureNasrData } from './seed-utils';
import { dbConfig } from '../db.config';

const DATA_DIR = path.join(__dirname, '..', '..', 'data');
const NASR_DIR = path.join(DATA_DIR, 'nasr');

async function initDataSource(): Promise<DataSource> {
  const ds = new DataSource({
    ...dbConfig,
    entities: [Airspace, AirwaySegment, ArtccBoundary, Navaid, Fix],
  });

  await ds.initialize();
  return ds;
}

// ---- Airspaces from Shapefile ----

async function seedAirspaces(ds: DataSource): Promise<number> {
  const shpFile = findFile(
    NASR_DIR,
    'Class_Airspace.shp',
    'Additional_Data/Shape_Files/Class_Airspace.shp',
  );
  if (!shpFile) {
    console.log('  Class_Airspace.shp not found, seeding sample data...');
    return seedSampleAirspaces(ds);
  }

  console.log(`  Reading ${shpFile}...`);
  const repo = ds.getRepository(Airspace);
  const source = await shapefile.open(shpFile);
  let count = 0;
  let batch: Partial<Airspace>[] = [];
  const batchSize = 500;

  while (true) {
    const result = await source.read();
    if (result.done) break;

    const props = result.value.properties;
    const geom = result.value.geometry;

    if (!geom || !geom.coordinates) continue;

    const geometryJson = JSON.stringify(geom);

    // Compute bounding box
    const allCoords = flattenCoords(geom.coordinates);
    if (allCoords.length === 0) continue;

    let minLat = Infinity,
      maxLat = -Infinity,
      minLng = Infinity,
      maxLng = -Infinity;
    for (const [lng, lat] of allCoords) {
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    batch.push({
      identifier: (props.IDENT || '').trim() || undefined,
      name: (props.NAME || '').trim() || undefined,
      airspace_class: (props.CLASS || '').trim(),
      type: (props.TYPE_CODE || '').trim() || undefined,
      lower_alt: parseInt(props.LOWER_VAL || '') || undefined,
      upper_alt: parseInt(props.UPPER_VAL || '') || undefined,
      lower_code: (props.LOWER_CODE || '').trim() || undefined,
      upper_code: (props.UPPER_CODE || '').trim() || undefined,
      geometry_json: geometryJson,
      min_lat: minLat,
      max_lat: maxLat,
      min_lng: minLng,
      max_lng: maxLng,
      military: props.MIL_CODE === 'MIL',
    });

    if (batch.length >= batchSize) {
      await repo.save(batch as Airspace[]);
      count += batch.length;
      batch = [];
    }
  }

  if (batch.length > 0) {
    await repo.save(batch as Airspace[]);
    count += batch.length;
  }

  return count;
}

function flattenCoords(coords: any): [number, number][] {
  const result: [number, number][] = [];
  if (!Array.isArray(coords)) return result;

  // Check if this is a coordinate pair [lng, lat]
  if (
    coords.length >= 2 &&
    typeof coords[0] === 'number' &&
    typeof coords[1] === 'number'
  ) {
    result.push([coords[0], coords[1]]);
    return result;
  }

  // Recurse into nested arrays
  for (const item of coords) {
    result.push(...flattenCoords(item));
  }
  return result;
}

async function seedSampleAirspaces(ds: DataSource): Promise<number> {
  const repo = ds.getRepository(Airspace);

  // Sample Denver Class B airspace (simplified polygon)
  const denverClassB = {
    type: 'Polygon',
    coordinates: [
      [
        [-105.2, 39.95],
        [-104.5, 39.95],
        [-104.5, 39.55],
        [-105.2, 39.55],
        [-105.2, 39.95],
      ],
    ],
  };

  // Sample Centennial Class D
  const centennialClassD = {
    type: 'Polygon',
    coordinates: [
      [
        [-104.88, 39.59],
        [-104.83, 39.59],
        [-104.83, 39.55],
        [-104.88, 39.55],
        [-104.88, 39.59],
      ],
    ],
  };

  const samples: Partial<Airspace>[] = [
    {
      identifier: 'DEN',
      name: 'Denver Class B',
      airspace_class: 'B',
      type: 'CLASS',
      lower_alt: 0,
      upper_alt: 12000,
      lower_code: 'SFC',
      upper_code: 'MSL',
      geometry_json: JSON.stringify(denverClassB),
      min_lat: 39.55,
      max_lat: 39.95,
      min_lng: -105.2,
      max_lng: -104.5,
      military: false,
    },
    {
      identifier: 'APA',
      name: 'Centennial Class D',
      airspace_class: 'D',
      type: 'CLASS',
      lower_alt: 0,
      upper_alt: 8000,
      lower_code: 'SFC',
      upper_code: 'MSL',
      geometry_json: JSON.stringify(centennialClassD),
      min_lat: 39.55,
      max_lat: 39.59,
      min_lng: -104.88,
      max_lng: -104.83,
      military: false,
    },
  ];

  await repo.save(samples as Airspace[]);
  return samples.length;
}

// ---- Airways from CSV ----

async function buildCoordLookup(
  ds: DataSource,
): Promise<Map<string, { lat: number; lng: number }>> {
  const lookup = new Map<string, { lat: number; lng: number }>();

  // Load fixes
  const fixFile = findFile(NASR_DIR, 'FIX_BASE.csv', 'FIX.csv');
  if (fixFile) {
    console.log(`  Building coord lookup from ${fixFile}...`);
    const fixes = await parsePipeDelimited(fixFile);
    for (const r of fixes) {
      const id = (r['FIX_ID'] || '').trim();
      const lat = parseFloat(r['LAT_DECIMAL'] || '');
      const lng = parseFloat(r['LONG_DECIMAL'] || '');
      if (id && !isNaN(lat) && !isNaN(lng)) {
        lookup.set(id, { lat, lng });
      }
    }
    console.log(`    ${lookup.size} fixes loaded`);
  }

  // Load navaids
  const navFile = findFile(NASR_DIR, 'NAV_BASE.csv', 'NAV.csv');
  if (navFile) {
    const navaids = await parsePipeDelimited(navFile);
    let navCount = 0;
    for (const r of navaids) {
      const id = (r['NAV_ID'] || '').trim();
      const lat = parseFloat(r['LAT_DECIMAL'] || '');
      const lng = parseFloat(r['LONG_DECIMAL'] || '');
      if (id && !isNaN(lat) && !isNaN(lng) && !lookup.has(id)) {
        lookup.set(id, { lat, lng });
        navCount++;
      }
    }
    console.log(`    ${navCount} navaids added (total ${lookup.size})`);
  }

  return lookup;
}

async function seedAirways(ds: DataSource): Promise<number> {
  const awyFile = findFile(NASR_DIR, 'AWY_SEG_ALT.csv');
  if (!awyFile) {
    console.log('  AWY_SEG_ALT.csv not found, seeding sample data...');
    return seedSampleAirways(ds);
  }

  const coordLookup = await buildCoordLookup(ds);

  console.log(`  Reading ${awyFile}...`);
  const records = await parsePipeDelimited(awyFile);
  console.log(`  Parsed ${records.length} airway segment records`);

  const repo = ds.getRepository(AirwaySegment);
  let count = 0;
  let skipped = 0;
  const batchSize = 500;

  for (let i = 0; i < records.length; i += batchSize) {
    const batch = records.slice(i, i + batchSize);
    const segments: Partial<AirwaySegment>[] = [];

    for (const r of batch) {
      const awyId = (r['AWY_ID'] || '').trim();
      if (!awyId) continue;

      const fromPoint = (r['FROM_POINT'] || '').trim();
      const toPoint = (r['TO_POINT'] || '').trim();
      if (!fromPoint || !toPoint) continue;

      const fromCoord = coordLookup.get(fromPoint);
      const toCoord = coordLookup.get(toPoint);
      if (!fromCoord || !toCoord) {
        skipped++;
        continue;
      }

      // Derive airway type from ID prefix
      let airwayType = 'V';
      if (awyId.startsWith('J')) airwayType = 'J';
      else if (awyId.startsWith('T')) airwayType = 'T';
      else if (awyId.startsWith('Q')) airwayType = 'Q';
      else if (awyId.startsWith('V')) airwayType = 'V';

      const mea = parseInt(r['MIN_ENROUTE_ALT'] || '') || undefined;
      const moca = parseInt(r['MIN_OBSTN_CLNC_ALT'] || '') || undefined;
      const dist = parseFloat(r['MAG_COURSE_DIST'] || '') || undefined;

      segments.push({
        airway_id: awyId,
        sequence: parseInt(r['POINT_SEQ'] || '0') || 0,
        from_fix: fromPoint,
        to_fix: toPoint,
        from_lat: fromCoord.lat,
        from_lng: fromCoord.lng,
        to_lat: toCoord.lat,
        to_lng: toCoord.lng,
        min_enroute_alt: mea,
        moca: moca,
        distance_nm: dist,
        airway_type: airwayType,
      });
    }

    if (segments.length > 0) {
      await repo.save(segments as AirwaySegment[]);
      count += segments.length;
    }
  }

  if (skipped > 0) {
    console.log(`  Skipped ${skipped} segments (missing fix coordinates)`);
  }

  return count;
}

async function seedSampleAirways(ds: DataSource): Promise<number> {
  const repo = ds.getRepository(AirwaySegment);

  const samples: Partial<AirwaySegment>[] = [
    {
      airway_id: 'V389',
      sequence: 10,
      from_fix: 'DEN',
      to_fix: 'TOMSN',
      from_lat: 39.8017,
      from_lng: -104.8872,
      to_lat: 39.95,
      to_lng: -105.1333,
      min_enroute_alt: 11000,
      airway_type: 'V',
      distance_nm: 15.2,
    },
    {
      airway_id: 'V389',
      sequence: 20,
      from_fix: 'TOMSN',
      to_fix: 'BJC',
      from_lat: 39.95,
      from_lng: -105.1333,
      to_lat: 39.9086,
      to_lng: -105.1175,
      min_enroute_alt: 11000,
      airway_type: 'V',
      distance_nm: 3.0,
    },
  ];

  await repo.save(samples as AirwaySegment[]);
  return samples.length;
}

// ---- ARTCC Boundaries from CSV ----

async function seedArtcc(ds: DataSource): Promise<number> {
  const segFile = findFile(NASR_DIR, 'ARB_SEG.csv');
  const baseFile = findFile(NASR_DIR, 'ARB_BASE.csv');
  if (!segFile) {
    console.log('  ARB_SEG.csv not found, seeding sample data...');
    return seedSampleArtcc(ds);
  }

  console.log(`  Reading ${segFile}...`);
  const segments = await parsePipeDelimited(segFile);
  console.log(`  Parsed ${segments.length} ARTCC boundary segments`);

  // Load base info for names
  const nameMap = new Map<string, string>();
  if (baseFile) {
    const baseRecords = await parsePipeDelimited(baseFile);
    for (const r of baseRecords) {
      const id = (r['LOCATION_ID'] || '').trim();
      const name = (r['LOCATION_NAME'] || '').trim();
      if (id) nameMap.set(id, name);
    }
  }

  // Group segments by LOCATION_ID + ALTITUDE
  const groups = new Map<
    string,
    { artccId: string; altitude: string; points: [number, number][] }
  >();

  for (const r of segments) {
    const artccId = (r['LOCATION_ID'] || '').trim();
    const altitude = (r['ALTITUDE'] || '').trim();
    if (!artccId || !altitude) continue;

    const lat = parseFloat(r['LAT_DECIMAL'] || '');
    const lng = parseFloat(r['LONG_DECIMAL'] || '');
    if (isNaN(lat) || isNaN(lng)) continue;

    const key = `${artccId}*${altitude}`;
    if (!groups.has(key)) {
      groups.set(key, { artccId, altitude, points: [] });
    }
    groups.get(key)!.points.push([lng, lat]);
  }

  const repo = ds.getRepository(ArtccBoundary);
  let count = 0;
  const batch: Partial<ArtccBoundary>[] = [];

  for (const [, group] of groups) {
    const { artccId, altitude, points } = group;
    if (points.length < 3) continue;

    // Close the polygon if not already closed
    const first = points[0];
    const last = points[points.length - 1];
    if (first[0] !== last[0] || first[1] !== last[1]) {
      points.push([...first]);
    }

    const geometry = {
      type: 'Polygon',
      coordinates: [points],
    };

    let minLat = Infinity,
      maxLat = -Infinity,
      minLng = Infinity,
      maxLng = -Infinity;
    for (const [lng, lat] of points) {
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    batch.push({
      artcc_id: artccId,
      name: nameMap.get(artccId) || undefined,
      altitude,
      geometry_json: JSON.stringify(geometry),
      min_lat: minLat,
      max_lat: maxLat,
      min_lng: minLng,
      max_lng: maxLng,
    });
  }

  if (batch.length > 0) {
    await repo.save(batch as ArtccBoundary[]);
    count = batch.length;
  }

  return count;
}

async function seedSampleArtcc(ds: DataSource): Promise<number> {
  const repo = ds.getRepository(ArtccBoundary);

  const zdvPolygon = {
    type: 'Polygon',
    coordinates: [
      [
        [-111.85, 35.77],
        [-110.23, 35.7],
        [-108.22, 36.03],
        [-107.47, 36.2],
        [-105.0, 37.0],
        [-103.0, 38.0],
        [-103.0, 41.0],
        [-105.0, 43.0],
        [-109.0, 43.0],
        [-111.85, 41.0],
        [-111.85, 35.77],
      ],
    ],
  };

  const samples: Partial<ArtccBoundary>[] = [
    {
      artcc_id: 'ZDV',
      name: 'DENVER',
      altitude: 'HIGH',
      geometry_json: JSON.stringify(zdvPolygon),
      min_lat: 35.77,
      max_lat: 43.0,
      min_lng: -111.85,
      max_lng: -103.0,
    },
  ];

  await repo.save(samples as ArtccBoundary[]);
  return samples.length;
}

// ---- Main ----

async function main() {
  console.log('=== EFB Airspace/Airway/ARTCC Seed ===\n');

  // Download + extract NASR data if not already present
  await ensureNasrData(NASR_DIR);

  const ds = await initDataSource();
  console.log('Database initialized.\n');

  // Clear existing data
  console.log('Clearing existing airspace data...');
  await ds.query('DELETE FROM airspaces');
  await ds.query('DELETE FROM airway_segments');
  await ds.query('DELETE FROM artcc_boundaries');
  console.log('  Done.\n');

  // Seed airspaces
  console.log('Seeding airspaces from shapefile...');
  const airspaceCount = await seedAirspaces(ds);
  console.log(`  Imported ${airspaceCount} airspaces.\n`);

  // Seed airways
  console.log('Seeding airway segments...');
  const airwayCount = await seedAirways(ds);
  console.log(`  Imported ${airwayCount} airway segments.\n`);

  // Seed ARTCC boundaries
  console.log('Seeding ARTCC boundaries...');
  const artccCount = await seedArtcc(ds);
  console.log(`  Imported ${artccCount} ARTCC boundaries.\n`);

  // Summary
  console.log('=== Seed Complete ===');
  console.log(`  Airspaces:        ${airspaceCount}`);
  console.log(`  Airway segments:  ${airwayCount}`);
  console.log(`  ARTCC boundaries: ${artccCount}`);

  await ds.destroy();
}

main().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
