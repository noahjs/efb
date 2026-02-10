/**
 * FAA CIFP (Coded Instrument Flight Procedures) Seed Script
 *
 * Downloads the current FAACIFP18 file (ARINC 424-18 format) and imports
 * structured approach procedure data into PostgreSQL.
 *
 * Usage: npx ts-node -r tsconfig-paths/register src/seed/seed-cifp.ts
 *
 * Data source: https://aeronav.faa.gov/Upload_313-d/cifp/CIFP_{YYMMDD}.zip
 */

import { DataSource } from 'typeorm';
import * as fs from 'fs';
import * as path from 'path';
import * as readline from 'readline';
import * as https from 'https';
import { execSync } from 'child_process';
import { downloadFile } from './seed-utils';
import { dbConfig } from '../db.config';
import { Airport } from '../airports/entities/airport.entity';
import { Runway } from '../airports/entities/runway.entity';
import { RunwayEnd } from '../airports/entities/runway-end.entity';
import { Frequency } from '../airports/entities/frequency.entity';
import {
  CifpApproach,
  CifpLeg,
  CifpIls,
  CifpMsa,
  CifpRunway,
} from '../cifp/entities';
import {
  getRecordType,
  isPrimaryRecord,
  isApproachRouteType,
  parsePFRecord,
  parsePCRecord,
  parseEARecord,
  parsePGRecord,
  parsePIRecord,
  parsePSRecord,
  decodeWaypointDesc,
  deriveProcedureName,
  RawPFRecord,
  RawPGRecord,
  RawPIRecord,
  RawPSRecord,
} from '../cifp/cifp-parser';

/** Convert null to undefined for TypeORM nullable columns. */
function n<T>(val: T | null): T | undefined {
  return val === null ? undefined : val;
}

const DATA_DIR = path.join(__dirname, '..', '..', 'data');
const CIFP_DIR = path.join(DATA_DIR, 'cifp');

async function initDataSource(): Promise<DataSource> {
  const ds = new DataSource({
    ...dbConfig,
    entities: [
      Airport,
      Runway,
      RunwayEnd,
      Frequency,
      CifpApproach,
      CifpLeg,
      CifpIls,
      CifpMsa,
      CifpRunway,
    ],
  });
  await ds.initialize();
  return ds;
}

// ---------------------------------------------------------------------------
// CIFP Download URL Discovery
// ---------------------------------------------------------------------------

/**
 * Compute candidate CIFP effective dates.
 * FAA CIFP is published every 28 days. We try several dates.
 */
function getCifpCandidateDates(): string[] {
  const now = new Date();
  const dates: string[] = [];

  // Generate candidate dates going back up to 3 cycles
  for (let offset = 0; offset >= -3; offset--) {
    const d = new Date(now);
    d.setDate(d.getDate() + offset * 28);

    // Try dates around the 22nd of each month (common AIRAC effective day)
    for (const dayOffset of [0, -1, -2, 1, 2, -7, -14]) {
      const candidate = new Date(d);
      candidate.setDate(candidate.getDate() + dayOffset);

      const yy = String(candidate.getFullYear() % 100).padStart(2, '0');
      const mm = String(candidate.getMonth() + 1).padStart(2, '0');
      const dd = String(candidate.getDate()).padStart(2, '0');
      const key = `${yy}${mm}${dd}`;

      if (!dates.includes(key)) {
        dates.push(key);
      }
    }
  }

  return dates;
}

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

async function findCifpUrl(): Promise<string> {
  const candidates = getCifpCandidateDates();
  console.log(`  Trying ${candidates.length} candidate dates...`);

  for (const date of candidates) {
    const url = `https://aeronav.faa.gov/Upload_313-d/cifp/CIFP_${date}.zip`;
    if (await urlExists(url)) {
      console.log(`  Found: CIFP_${date}.zip`);
      return url;
    }
  }

  throw new Error(
    'Could not find CIFP download at any known URL. ' +
      'The FAA servers may be temporarily unavailable.',
  );
}

// ---------------------------------------------------------------------------
// ICAO → FAA Airport Identifier Mapping
// ---------------------------------------------------------------------------

async function buildIcaoToFaaMap(ds: DataSource): Promise<Map<string, string>> {
  const airports = await ds
    .getRepository(Airport)
    .createQueryBuilder('a')
    .select(['a.identifier', 'a.icao_identifier'])
    .where('a.icao_identifier IS NOT NULL')
    .getMany();

  const map = new Map<string, string>();
  for (const apt of airports) {
    if (apt.icao_identifier) {
      map.set(apt.icao_identifier.toUpperCase(), apt.identifier);
    }
  }
  console.log(`  Built ICAO→FAA map: ${map.size} airports`);
  return map;
}

function icaoToFaa(icao: string, map: Map<string, string>): string {
  const upper = icao.toUpperCase().trim();
  if (map.has(upper)) return map.get(upper)!;
  // Fallback: strip leading K for continental US
  if (upper.length === 4 && upper.startsWith('K')) return upper.substring(1);
  return upper;
}

// ---------------------------------------------------------------------------
// Single-Pass File Parser
// ---------------------------------------------------------------------------

interface ParseResult {
  terminalWaypoints: Map<string, { lat: number; lng: number }>;
  enrouteWaypoints: Map<string, { lat: number; lng: number }>;
  approachRecords: RawPFRecord[];
  runwayRecords: RawPGRecord[];
  ilsRecords: RawPIRecord[];
  msaRecords: RawPSRecord[];
  lineCount: number;
}

async function parseCifpFile(filePath: string): Promise<ParseResult> {
  const terminalWaypoints = new Map<string, { lat: number; lng: number }>();
  const enrouteWaypoints = new Map<string, { lat: number; lng: number }>();
  const approachRecords: RawPFRecord[] = [];
  const runwayRecords: RawPGRecord[] = [];
  const ilsRecords: RawPIRecord[] = [];
  const msaRecords: RawPSRecord[] = [];
  let lineCount = 0;

  const fileStream = fs.createReadStream(filePath, { encoding: 'utf-8' });
  const rl = readline.createInterface({
    input: fileStream,
    crlfDelay: Infinity,
  });

  for await (const line of rl) {
    lineCount++;
    if (line.length < 132) continue;
    if (line[0] === 'H') continue; // Skip header records

    const recType = getRecordType(line);

    switch (recType) {
      case 'PC': {
        // Terminal waypoint — skip continuations
        if (line[21] !== '0' && line[21] !== ' ') break;
        const wp = parsePCRecord(line);
        if (wp.latitude !== null && wp.longitude !== null) {
          const key = `${wp.airportIcao}:${wp.fixId}`;
          terminalWaypoints.set(key, {
            lat: wp.latitude,
            lng: wp.longitude,
          });
        }
        break;
      }
      case 'EA': {
        // Enroute waypoint
        if (line[21] !== '0' && line[21] !== ' ') break;
        const wp = parseEARecord(line);
        if (wp.latitude !== null && wp.longitude !== null) {
          enrouteWaypoints.set(wp.fixId, {
            lat: wp.latitude,
            lng: wp.longitude,
          });
        }
        break;
      }
      case 'PF': {
        // Approach procedure leg — only primary records, only approach route types
        if (!isPrimaryRecord(line)) break;
        const routeType = line[19];
        if (!isApproachRouteType(routeType)) break;
        approachRecords.push(parsePFRecord(line));
        break;
      }
      case 'PG': {
        // Runway
        if (line[21] !== '0' && line[21] !== ' ') break;
        runwayRecords.push(parsePGRecord(line));
        break;
      }
      case 'PI': {
        // ILS/Localizer/Glideslope
        if (line[21] !== '0' && line[21] !== ' ') break;
        ilsRecords.push(parsePIRecord(line));
        break;
      }
      case 'PS': {
        // MSA
        msaRecords.push(parsePSRecord(line));
        break;
      }
    }

    if (lineCount % 100000 === 0) {
      process.stdout.write(`  ${lineCount} lines...\r`);
    }
  }

  console.log(`  Parsed ${lineCount} lines`);
  console.log(`  Terminal waypoints: ${terminalWaypoints.size}`);
  console.log(`  Enroute waypoints: ${enrouteWaypoints.size}`);
  console.log(`  Approach leg records: ${approachRecords.length}`);
  console.log(`  Runway records: ${runwayRecords.length}`);
  console.log(`  ILS records: ${ilsRecords.length}`);
  console.log(`  MSA records: ${msaRecords.length}`);

  return {
    terminalWaypoints,
    enrouteWaypoints,
    approachRecords,
    runwayRecords,
    ilsRecords,
    msaRecords,
    lineCount,
  };
}

// ---------------------------------------------------------------------------
// Group PF Records into Approaches
// ---------------------------------------------------------------------------

interface GroupedApproach {
  icaoId: string;
  procedureId: string;
  routeType: string;
  transitionId: string | null;
  legs: RawPFRecord[];
}

function groupApproachRecords(records: RawPFRecord[]): GroupedApproach[] {
  const map = new Map<string, GroupedApproach>();

  for (const rec of records) {
    const key = `${rec.icaoId}:${rec.procedureId}:${rec.routeType}:${rec.transitionId || ''}`;

    if (!map.has(key)) {
      map.set(key, {
        icaoId: rec.icaoId,
        procedureId: rec.procedureId,
        routeType: rec.routeType,
        transitionId: rec.transitionId,
        legs: [],
      });
    }
    map.get(key)!.legs.push(rec);
  }

  // Sort legs within each approach by sequence number
  for (const group of map.values()) {
    group.legs.sort((a, b) => a.sequenceNumber - b.sequenceNumber);
  }

  return Array.from(map.values());
}

/**
 * Extract runway identifier from an approach's legs.
 * Looks for a fix starting with "RW" (e.g., RW25, RW16L).
 */
function extractRunwayFromLegs(legs: RawPFRecord[]): string | null {
  for (const leg of legs) {
    if (leg.fixIdentifier?.startsWith('RW')) {
      return leg.fixIdentifier;
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Fix Coordinate Resolution
// ---------------------------------------------------------------------------

function resolveFixCoords(
  icaoId: string,
  fixId: string | null,
  fixSection: string | null,
  terminalWp: Map<string, { lat: number; lng: number }>,
  enrouteWp: Map<string, { lat: number; lng: number }>,
): { lat: number | null; lng: number | null } {
  if (!fixId) return { lat: null, lng: null };

  // Try terminal waypoint first (airport-specific)
  const termKey = `${icaoId}:${fixId}`;
  if (terminalWp.has(termKey)) {
    const wp = terminalWp.get(termKey)!;
    return { lat: wp.lat, lng: wp.lng };
  }

  // Try enroute waypoint
  if (enrouteWp.has(fixId)) {
    const wp = enrouteWp.get(fixId)!;
    return { lat: wp.lat, lng: wp.lng };
  }

  return { lat: null, lng: null };
}

// ---------------------------------------------------------------------------
// Batch Insert Helpers
// ---------------------------------------------------------------------------

async function batchInsert<T>(
  ds: DataSource,
  entity: new () => T,
  records: Partial<T>[],
  label: string,
  batchSize = 500,
): Promise<number> {
  const repo = ds.getRepository(entity);
  let inserted = 0;

  for (let i = 0; i < records.length; i += batchSize) {
    const batch = records.slice(i, i + batchSize);
    await repo.save(batch as T[]);
    inserted += batch.length;
    if (inserted % 5000 === 0 || inserted === records.length) {
      console.log(`  ${label}: ${inserted} / ${records.length}`);
    }
  }

  return inserted;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  console.log('=== EFB CIFP (Instrument Procedures) Seed ===\n');

  // Ensure directories exist
  fs.mkdirSync(CIFP_DIR, { recursive: true });
  const zipPath = path.join(CIFP_DIR, 'cifp.zip');
  const cifpPath = path.join(CIFP_DIR, 'FAACIFP18');

  // Check if FAACIFP18 already exists
  if (fs.existsSync(cifpPath)) {
    const stats = fs.statSync(cifpPath);
    const ageHours = (Date.now() - stats.mtimeMs) / 3600000;
    if (ageHours < 24 * 28) {
      console.log(
        `FAACIFP18 already present (${(stats.size / 1024 / 1024).toFixed(1)} MB, ${Math.floor(ageHours / 24)} days old)`,
      );
      console.log(
        'Skipping download. Delete data/cifp/ to force re-download.\n',
      );
    }
  } else {
    // Find and download CIFP ZIP
    console.log('Locating CIFP download...');
    const cifpUrl = await findCifpUrl();

    console.log(`\nDownloading CIFP...`);
    console.log(`  URL: ${cifpUrl}`);
    await downloadFile(cifpUrl, zipPath);
    const zipSize = fs.statSync(zipPath).size;
    console.log(`  Downloaded: ${(zipSize / 1024 / 1024).toFixed(1)} MB`);

    // Extract
    console.log('Extracting...');
    execSync(`unzip -o "${zipPath}" -d "${CIFP_DIR}"`, { stdio: 'pipe' });
    console.log('  Done.\n');
  }

  if (!fs.existsSync(cifpPath)) {
    console.error('ERROR: FAACIFP18 not found after extraction');
    process.exit(1);
  }

  // Initialize database
  const ds = await initDataSource();
  console.log('Database initialized.\n');

  // Build ICAO → FAA mapping
  console.log('Building ICAO → FAA identifier map...');
  const icaoFaaMap = await buildIcaoToFaaMap(ds);
  console.log();

  // Parse CIFP file
  console.log('Parsing FAACIFP18...');
  const parsed = await parseCifpFile(cifpPath);
  console.log();

  // Group approach records
  console.log('Grouping approach procedures...');
  const grouped = groupApproachRecords(parsed.approachRecords);
  console.log(`  ${grouped.length} approach procedures\n`);

  // Clear existing CIFP data
  console.log('Clearing existing CIFP data...');
  await ds.query(
    'TRUNCATE TABLE cifp_legs, cifp_approaches, cifp_ils, cifp_msa, cifp_runways CASCADE',
  );
  console.log('  Done.\n');

  // Insert approaches with legs
  console.log('Inserting approaches and legs...');
  const approachRepo = ds.getRepository(CifpApproach);
  let approachCount = 0;
  let legCount = 0;

  for (let i = 0; i < grouped.length; i += 100) {
    const batch = grouped.slice(i, i + 100);
    const approaches: CifpApproach[] = [];

    for (const group of batch) {
      const faaId = icaoToFaa(group.icaoId, icaoFaaMap);
      const runwayId = extractRunwayFromLegs(group.legs);
      const procName = deriveProcedureName(group.routeType, group.procedureId);
      const cycle = group.legs[0]?.cycle || '';

      const approach = new CifpApproach();
      approach.airport_identifier = faaId;
      approach.icao_identifier = group.icaoId;
      approach.procedure_identifier = group.procedureId;
      approach.route_type = group.routeType;
      approach.transition_identifier = n(group.transitionId);
      approach.procedure_name = procName;
      approach.runway_identifier = n(runwayId);
      approach.cycle = cycle;

      approach.legs = group.legs.map((leg) => {
        const coords = resolveFixCoords(
          group.icaoId,
          leg.fixIdentifier,
          leg.fixSectionCode,
          parsed.terminalWaypoints,
          parsed.enrouteWaypoints,
        );
        const wpFlags = decodeWaypointDesc(leg.waypointDescCode);

        const cifpLeg = new CifpLeg();
        cifpLeg.sequence_number = leg.sequenceNumber;
        cifpLeg.fix_identifier = n(leg.fixIdentifier);
        cifpLeg.fix_section_code = n(leg.fixSectionCode);
        cifpLeg.waypoint_description_code = n(
          leg.waypointDescCode.trim() || null,
        );
        cifpLeg.turn_direction = n(leg.turnDirection);
        cifpLeg.path_termination = leg.pathTermination;
        cifpLeg.recomm_navaid = n(leg.recommNavaid);
        cifpLeg.theta = n(leg.theta);
        cifpLeg.rho = n(leg.rho);
        cifpLeg.arc_radius = n(leg.arcRadius);
        cifpLeg.magnetic_course = n(leg.magneticCourse);
        cifpLeg.route_distance_or_time = n(leg.routeDistOrTime);
        cifpLeg.altitude_description = n(leg.altitudeDesc);
        cifpLeg.altitude1 = n(leg.altitude1);
        cifpLeg.altitude2 = n(leg.altitude2);
        cifpLeg.transition_altitude = n(leg.transitionAltitude);
        cifpLeg.speed_limit = n(leg.speedLimit);
        cifpLeg.vertical_angle = n(leg.verticalAngle);
        cifpLeg.center_fix = n(leg.centerFix);
        cifpLeg.fix_latitude = n(coords.lat);
        cifpLeg.fix_longitude = n(coords.lng);
        cifpLeg.is_iaf = wpFlags.is_iaf;
        cifpLeg.is_if = wpFlags.is_if;
        cifpLeg.is_faf = wpFlags.is_faf;
        cifpLeg.is_map = wpFlags.is_map;
        cifpLeg.is_missed_approach = wpFlags.is_missed_approach;

        return cifpLeg;
      });

      legCount += approach.legs.length;
      approaches.push(approach);
    }

    await approachRepo.save(approaches);
    approachCount += approaches.length;

    if (approachCount % 5000 === 0 || i + 100 >= grouped.length) {
      console.log(
        `  Approaches: ${approachCount} / ${grouped.length} (${legCount} legs)`,
      );
    }
  }

  // Insert runways
  console.log('\nInserting runways...');
  const runways = parsed.runwayRecords.map((r) => ({
    airport_identifier: icaoToFaa(r.icaoId, icaoFaaMap),
    icao_identifier: r.icaoId,
    runway_identifier: r.runwayId,
    runway_length: n(r.runwayLength),
    runway_bearing: n(r.runwayBearing),
    threshold_latitude: n(r.thresholdLatitude),
    threshold_longitude: n(r.thresholdLongitude),
    threshold_elevation: n(r.thresholdElevation),
    displaced_threshold_distance: n(r.displacedThresholdDist),
    threshold_crossing_height: n(r.thresholdCrossingHeight),
    runway_width: n(r.runwayWidth),
    localizer_identifier: n(r.localizerIdent),
    cycle: r.cycle,
  })) as Partial<CifpRunway>[];
  await batchInsert(ds, CifpRunway, runways, 'Runways');

  // Insert ILS
  console.log('\nInserting ILS/LOC data...');
  const ilsData = parsed.ilsRecords.map((r) => ({
    airport_identifier: icaoToFaa(r.icaoId, icaoFaaMap),
    icao_identifier: r.icaoId,
    localizer_identifier: r.localizerIdent,
    ils_category: n(r.ilsCategory),
    frequency: n(r.frequency),
    runway_identifier: n(r.runwayId),
    localizer_latitude: n(r.localizerLatitude),
    localizer_longitude: n(r.localizerLongitude),
    localizer_bearing: n(r.localizerBearing),
    gs_latitude: n(r.gsLatitude),
    gs_longitude: n(r.gsLongitude),
    gs_angle: n(r.gsAngle),
    gs_elevation: n(r.gsElevation),
    threshold_crossing_height: n(r.thresholdCrossingHeight),
    station_declination: n(r.stationDeclination),
    cycle: r.cycle,
  })) as Partial<CifpIls>[];
  await batchInsert(ds, CifpIls, ilsData, 'ILS');

  // Insert MSA
  console.log('\nInserting MSA data...');
  const msaData = parsed.msaRecords
    .filter((r) => r.sectors.length > 0)
    .map((r) => ({
      airport_identifier: icaoToFaa(r.icaoId, icaoFaaMap),
      icao_identifier: r.icaoId,
      msa_center: r.msaCenter,
      msa_center_icao: n(r.msaCenterIcao),
      multiple_code: n(r.multipleCode),
      sectors: r.sectors,
      magnetic_true_indicator: n(r.magneticTrueIndicator),
      cycle: r.cycle,
    })) as Partial<CifpMsa>[];
  await batchInsert(ds, CifpMsa, msaData, 'MSA');

  // Summary
  console.log('\n=== Seed Complete ===');
  console.log(`  Approaches: ${approachCount}`);
  console.log(`  Legs:       ${legCount}`);
  console.log(`  Runways:    ${runways.length}`);
  console.log(`  ILS:        ${ilsData.length}`);
  console.log(`  MSA:        ${msaData.length}`);

  await ds.destroy();
}

main().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
