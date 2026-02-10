/**
 * ARINC 424-18 (FAA CIFP) Parser
 *
 * Pure functions for parsing FAACIFP18 fixed-width records.
 * Column positions verified against real data (Denver ILS RWY 25).
 */

// ---------------------------------------------------------------------------
// Coordinate Decoder
// ---------------------------------------------------------------------------

/**
 * Decode ARINC 424 coordinate string to decimal degrees.
 * Latitude:  N39501673 → N 39° 50' 16.73" → 39.83798
 * Longitude: W104213461 → W 104° 21' 34.61" → -104.35961
 */
export function parseArinc424Coord(raw: string): number | null {
  if (!raw || raw.trim().length < 9) return null;
  const s = raw.trim();
  const dir = s[0];
  if (!'NSEW'.includes(dir)) return null;

  let idx = 1;
  const isLon = dir === 'E' || dir === 'W';
  const degLen = isLon ? 3 : 2;

  const deg = parseInt(s.substring(idx, idx + degLen), 10);
  idx += degLen;
  const min = parseInt(s.substring(idx, idx + 2), 10);
  idx += 2;
  const sec = parseInt(s.substring(idx, idx + 2), 10);
  idx += 2;
  const csec = parseInt(s.substring(idx, idx + 2), 10) || 0;

  if (isNaN(deg) || isNaN(min) || isNaN(sec)) return null;

  let result = deg + min / 60 + (sec + csec / 100) / 3600;
  if (dir === 'S' || dir === 'W') result = -result;
  return Math.round(result * 1e6) / 1e6; // 6 decimal places
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function trimOrNull(s: string): string | null {
  const t = s.trim();
  return t.length > 0 ? t : null;
}

function parseNumeric(s: string, divisor = 1): number | null {
  const t = s.trim();
  if (!t) return null;
  const n = parseInt(t, 10);
  return isNaN(n) ? null : n / divisor;
}

function parseFloat10(s: string): number | null {
  return parseNumeric(s, 10);
}

// ---------------------------------------------------------------------------
// Record Type Classification
// ---------------------------------------------------------------------------

/**
 * Classify a 132-char ARINC 424 line by section + subsection.
 * Returns two-char code like "PA", "PC", "PF", "PG", "PI", "PS", "EA", "D ".
 *
 * For P-section (airport) records, subsection is at col[12].
 * For other sections (E=enroute, D=navaid, etc.), subsection is at col[5].
 */
export function getRecordType(line: string): string {
  if (line.length < 13) return '??';
  const section = line[4];
  if (section === 'P') {
    return section + line[12];
  }
  return section + line[5];
}

/**
 * Check if a PF record is a primary record (not a continuation).
 */
export function isPrimaryRecord(line: string): boolean {
  return line[38] === '0' || line[38] === ' ';
}

// ---------------------------------------------------------------------------
// Approach Route Type Codes
// ---------------------------------------------------------------------------

const APPROACH_ROUTE_TYPES: Record<string, string> = {
  B: 'LOC Back Course',
  D: 'VOR/DME',
  F: 'FMS',
  G: 'IGS',
  I: 'ILS',
  J: 'GLS',
  L: 'LOC',
  M: 'MLS',
  N: 'NDB',
  P: 'GPS',
  Q: 'NDB/DME',
  R: 'RNAV (GPS)',
  S: 'VOR/DME',
  T: 'TACAN',
  U: 'SDF',
  V: 'VOR',
  W: 'MLS Type A',
  X: 'LDA',
  Y: 'LDA/GS',
  Z: 'MLS Type B/C',
};

export function isApproachRouteType(code: string): boolean {
  return code in APPROACH_ROUTE_TYPES;
}

export function getApproachTypeName(code: string): string {
  return APPROACH_ROUTE_TYPES[code] || code;
}

// ---------------------------------------------------------------------------
// Procedure Name Derivation
// ---------------------------------------------------------------------------

/**
 * Derive a human-readable procedure name from route type and procedure identifier.
 * "I" + "I25   " → "ILS RWY 25"
 * "R" + "R04R  " → "RNAV (GPS) RWY 04R"
 */
export function deriveProcedureName(
  routeType: string,
  procedureId: string,
): string {
  const typeName = getApproachTypeName(routeType);
  const id = procedureId.trim();

  // Extract runway from procedure ID (skip the first char which is the route type letter)
  const rwyPart = id.substring(1).trim();
  if (rwyPart) {
    return `${typeName} RWY ${rwyPart}`;
  }
  return `${typeName} ${id}`;
}

// ---------------------------------------------------------------------------
// Waypoint Description Code Decoder
// ---------------------------------------------------------------------------

export interface WaypointFlags {
  is_iaf: boolean;
  is_if: boolean;
  is_faf: boolean;
  is_map: boolean;
  is_missed_approach: boolean;
}

/**
 * Decode the 4-char waypoint description code from cols [39:43].
 * Position 0: route description (E=essential, etc.)
 * Position 1: ' ' or specific codes
 * Position 2: ' ' or F=FAF, I=IF
 * Position 3: ' ' or M=MAP, Y=missed approach holding
 */
export function decodeWaypointDesc(code: string): WaypointFlags {
  const c0 = code[0] || ' ';
  const c1 = code[1] || ' ';
  const c2 = code[2] || ' ';
  const c3 = code[3] || ' ';

  return {
    is_iaf: c1 === 'A' || c1 === 'C',
    is_if: c2 === 'I' || c1 === 'B' || c1 === 'C',
    is_faf: c2 === 'F',
    is_map: c3 === 'M' || c0 === 'G',
    is_missed_approach: c3 === 'Y' || c3 === 'E' || c3 === 'M',
  };
}

// ---------------------------------------------------------------------------
// PF Record Parser (Approach Procedure Legs)
// ---------------------------------------------------------------------------

export interface RawPFRecord {
  icaoId: string;
  procedureId: string;
  routeType: string;
  transitionId: string | null;
  sequenceNumber: number;
  fixIdentifier: string | null;
  fixIcaoCode: string | null;
  fixSectionCode: string | null;
  continuationNo: string;
  waypointDescCode: string;
  turnDirection: string | null;
  pathTermination: string;
  recommNavaid: string | null;
  recommNavaidIcao: string | null;
  arcRadius: number | null;
  theta: number | null;
  rho: number | null;
  magneticCourse: number | null;
  routeDistOrTime: string | null;
  altitudeDesc: string | null;
  altitude1: number | null;
  altitude2: number | null;
  transitionAltitude: number | null;
  speedLimit: number | null;
  verticalAngle: number | null;
  centerFix: string | null;
  cycle: string;
}

export function parsePFRecord(line: string): RawPFRecord {
  return {
    icaoId: line.substring(6, 10).trim(),
    procedureId: line.substring(13, 19).trim(),
    routeType: line[19],
    transitionId: trimOrNull(line.substring(20, 25)),
    sequenceNumber: parseInt(line.substring(26, 29), 10) || 0,
    fixIdentifier: trimOrNull(line.substring(29, 34)),
    fixIcaoCode: trimOrNull(line.substring(34, 36)),
    fixSectionCode: trimOrNull(line.substring(36, 38)),
    continuationNo: line[38],
    waypointDescCode: line.substring(39, 43),
    turnDirection: trimOrNull(line[43]),
    pathTermination: line.substring(47, 49).trim(),
    recommNavaid: trimOrNull(line.substring(50, 54)),
    recommNavaidIcao: trimOrNull(line.substring(54, 56)),
    arcRadius: parseFloat10(line.substring(56, 62)),
    theta: parseFloat10(line.substring(62, 66)),
    rho: parseFloat10(line.substring(66, 70)),
    magneticCourse: parseFloat10(line.substring(70, 74)),
    routeDistOrTime: trimOrNull(line.substring(74, 78)),
    altitudeDesc: trimOrNull(line[82]),
    altitude1: parseNumeric(line.substring(84, 89)),
    altitude2: parseNumeric(line.substring(89, 94)),
    transitionAltitude: parseNumeric(line.substring(94, 99)),
    speedLimit: parseNumeric(line.substring(99, 102)),
    verticalAngle: parseNumeric(line.substring(102, 106)),
    centerFix: trimOrNull(line.substring(106, 111)),
    cycle: line.substring(128, 132),
  };
}

// ---------------------------------------------------------------------------
// PC Record Parser (Terminal Waypoints)
// ---------------------------------------------------------------------------

export interface RawWaypoint {
  airportIcao: string;
  fixId: string;
  latitude: number | null;
  longitude: number | null;
}

export function parsePCRecord(line: string): RawWaypoint {
  // Terminal waypoint: airport in [6:10], fix in [13:18], coords starting at col 32
  return {
    airportIcao: line.substring(6, 10).trim(),
    fixId: line.substring(13, 18).trim(),
    latitude: parseArinc424Coord(line.substring(32, 41)),
    longitude: parseArinc424Coord(line.substring(41, 51)),
  };
}

// ---------------------------------------------------------------------------
// EA Record Parser (Enroute Waypoints)
// ---------------------------------------------------------------------------

export function parseEARecord(line: string): RawWaypoint {
  // Enroute waypoint: fix in [13:18], coords starting at col 32
  return {
    airportIcao: '',
    fixId: line.substring(13, 18).trim(),
    latitude: parseArinc424Coord(line.substring(32, 41)),
    longitude: parseArinc424Coord(line.substring(41, 51)),
  };
}

// ---------------------------------------------------------------------------
// PG Record Parser (Runways)
// ---------------------------------------------------------------------------

export interface RawPGRecord {
  icaoId: string;
  runwayId: string;
  runwayLength: number | null;
  runwayBearing: number | null;
  thresholdLatitude: number | null;
  thresholdLongitude: number | null;
  thresholdElevation: number | null;
  displacedThresholdDist: number | null;
  thresholdCrossingHeight: number | null;
  runwayWidth: number | null;
  localizerIdent: string | null;
  cycle: string;
}

export function parsePGRecord(line: string): RawPGRecord {
  return {
    icaoId: line.substring(6, 10).trim(),
    runwayId: line.substring(13, 18).trim(),
    runwayLength: parseNumeric(line.substring(22, 27)),
    runwayBearing: parseFloat10(line.substring(27, 31)),
    thresholdLatitude: parseArinc424Coord(line.substring(32, 41)),
    thresholdLongitude: parseArinc424Coord(line.substring(41, 51)),
    thresholdElevation: parseNumeric(line.substring(66, 71)),
    displacedThresholdDist: parseNumeric(line.substring(71, 75)),
    thresholdCrossingHeight: parseNumeric(line.substring(75, 77)),
    runwayWidth: parseNumeric(line.substring(77, 80)),
    localizerIdent: trimOrNull(line.substring(81, 85)),
    cycle: line.substring(128, 132),
  };
}

// ---------------------------------------------------------------------------
// PI Record Parser (ILS/Localizer/Glideslope)
// ---------------------------------------------------------------------------

export interface RawPIRecord {
  icaoId: string;
  localizerIdent: string;
  ilsCategory: string | null;
  frequency: number | null;
  runwayId: string | null;
  localizerLatitude: number | null;
  localizerLongitude: number | null;
  localizerBearing: number | null;
  gsLatitude: number | null;
  gsLongitude: number | null;
  localizerPosition: number | null;
  gsPosition: number | null;
  localizerWidth: number | null;
  gsAngle: number | null;
  stationDeclination: string | null;
  thresholdCrossingHeight: number | null;
  gsElevation: number | null;
  cycle: string;
}

export function parsePIRecord(line: string): RawPIRecord {
  return {
    icaoId: line.substring(6, 10).trim(),
    localizerIdent: line.substring(13, 17).trim(),
    ilsCategory: trimOrNull(line[17]),
    frequency: parseNumeric(line.substring(22, 27), 100),
    runwayId: trimOrNull(line.substring(27, 32)),
    localizerLatitude: parseArinc424Coord(line.substring(32, 41)),
    localizerLongitude: parseArinc424Coord(line.substring(41, 51)),
    localizerBearing: parseFloat10(line.substring(51, 55)),
    gsLatitude: parseArinc424Coord(line.substring(55, 64)),
    gsLongitude: parseArinc424Coord(line.substring(64, 74)),
    localizerPosition: parseNumeric(line.substring(74, 78)),
    gsPosition: parseNumeric(line.substring(79, 83)),
    localizerWidth: parseNumeric(line.substring(83, 87)),
    gsAngle: parseNumeric(line.substring(87, 90), 100),
    stationDeclination: trimOrNull(line.substring(90, 95)),
    thresholdCrossingHeight: parseNumeric(line.substring(95, 97)),
    gsElevation: parseNumeric(line.substring(97, 102)),
    cycle: line.substring(128, 132),
  };
}

// ---------------------------------------------------------------------------
// PS Record Parser (MSA — Minimum Sector Altitude)
// ---------------------------------------------------------------------------

export interface MsaSector {
  bearing_from: number;
  bearing_to: number;
  altitude: number;
  radius: number;
}

export interface RawPSRecord {
  icaoId: string;
  msaCenter: string;
  msaCenterIcao: string | null;
  msaCenterSection: string | null;
  multipleCode: string | null;
  sectors: MsaSector[];
  magneticTrueIndicator: string | null;
  cycle: string;
}

export function parsePSRecord(line: string): RawPSRecord {
  const icaoId = line.substring(6, 10).trim();
  const msaCenter = line.substring(13, 17).trim();
  const msaCenterIcao = trimOrNull(line.substring(18, 20));
  const msaCenterSection = trimOrNull(line.substring(17, 18));
  const multipleCode = trimOrNull(line[22]);

  // MSA sectors are in repeating 11-char groups starting at col 42.
  // Each sector: bearing_from (3) + bearing_to (3) + altitude (3, hundreds of ft) + radius (2, nm)
  const sectors: MsaSector[] = [];
  const sectorStart = 42;
  const sectorLen = 11;

  for (let i = 0; i < 7; i++) {
    const offset = sectorStart + i * sectorLen;
    if (offset + sectorLen > line.length) break;

    const bearingFrom = parseNumeric(line.substring(offset, offset + 3));
    const bearingTo = parseNumeric(line.substring(offset + 3, offset + 6));
    const altRaw = parseNumeric(line.substring(offset + 6, offset + 9));
    const radius = parseNumeric(line.substring(offset + 9, offset + 11));

    if (bearingFrom !== null && bearingTo !== null && altRaw !== null) {
      sectors.push({
        bearing_from: bearingFrom,
        bearing_to: bearingTo,
        altitude: altRaw * 100, // stored in hundreds of feet
        radius: radius || 25,
      });
    }
  }

  return {
    icaoId,
    msaCenter,
    msaCenterIcao,
    msaCenterSection,
    multipleCode,
    sectors,
    magneticTrueIndicator: trimOrNull(line[119]),
    cycle: line.substring(128, 132),
  };
}

// ---------------------------------------------------------------------------
// VHF Navaid Parser (D section — for resolving navaid coordinates)
// ---------------------------------------------------------------------------

export interface RawNavaid {
  navaidId: string;
  latitude: number | null;
  longitude: number | null;
  frequency: number | null;
}

export function parseDRecord(line: string): RawNavaid {
  return {
    navaidId: line.substring(13, 17).trim(),
    latitude: parseArinc424Coord(line.substring(32, 41)),
    longitude: parseArinc424Coord(line.substring(41, 51)),
    frequency: parseNumeric(line.substring(22, 27), 100),
  };
}
