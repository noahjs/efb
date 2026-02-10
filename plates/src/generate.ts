/**
 * Jeppesen-style Approach Plate PDF Generator
 *
 * Fetches CIFP data from the EFB API and renders a PDF approach chart.
 *
 * Usage: npx ts-node src/generate.ts <airportId> <approachId>
 * Example: npx ts-node src/generate.ts DEN 13375
 */

import { PDFDocument, StandardFonts, rgb, PDFFont, PDFPage } from 'pdf-lib';
import * as fs from 'fs';
import * as path from 'path';
import * as http from 'http';

const API_BASE = 'http://localhost:3001/api';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface ChartData {
  approach: {
    id: number;
    airport_identifier: string;
    icao_identifier: string;
    procedure_identifier: string;
    route_type: string;
    transition_identifier: string | null;
    procedure_name: string;
    runway_identifier: string;
    cycle: string;
  };
  legs: Leg[];
  ils: IlsData | null;
  msa: MsaData | null;
  runway: RunwayData | null;
}

interface Leg {
  sequence_number: number;
  fix_identifier: string | null;
  path_termination: string;
  turn_direction: string | null;
  magnetic_course: number | null;
  route_distance_or_time: string | null;
  altitude_description: string | null;
  altitude1: number | null;
  altitude2: number | null;
  vertical_angle: number | null;
  speed_limit: number | null;
  recomm_navaid: string | null;
  theta: number | null;
  rho: number | null;
  arc_radius: number | null;
  center_fix: string | null;
  fix_latitude: number | null;
  fix_longitude: number | null;
  is_iaf: boolean;
  is_if: boolean;
  is_faf: boolean;
  is_map: boolean;
  is_missed_approach: boolean;
}

interface IlsData {
  localizer_identifier: string;
  frequency: number;
  localizer_bearing: number;
  localizer_latitude: number;
  localizer_longitude: number;
  gs_latitude: number;
  gs_longitude: number;
  gs_angle: number;
  gs_elevation: number;
  threshold_crossing_height: number;
}

interface MsaData {
  msa_center: string;
  sectors: { bearing_from: number; bearing_to: number; altitude: number; radius: number }[];
}

interface RunwayData {
  runway_identifier: string;
  runway_length: number;
  runway_bearing: number;
  threshold_latitude: number;
  threshold_longitude: number;
  threshold_elevation: number;
  threshold_crossing_height: number;
  runway_width: number;
}

interface AirportInfo {
  identifier: string;
  icao_identifier: string;
  name: string;
  city: string;
  state: string;
  elevation: number;
  latitude: number;
  longitude: number;
  frequencies?: { type: string; name?: string; frequency: string }[];
}

// ---------------------------------------------------------------------------
// HTTP Fetch Helper
// ---------------------------------------------------------------------------

function fetchJson<T>(url: string): Promise<T> {
  return new Promise((resolve, reject) => {
    http.get(url, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(new Error(`Failed to parse JSON from ${url}: ${data.substring(0, 200)}`));
        }
      });
    }).on('error', reject);
  });
}

// ---------------------------------------------------------------------------
// Page Layout Constants (in points, 72 pts/inch)
// ---------------------------------------------------------------------------

const PAGE_W = 396;  // ~5.5"
const PAGE_H = 612;  // 8.5"
const M = 14;        // margin

const BLACK = rgb(0, 0, 0);
const GRAY = rgb(0.45, 0.45, 0.45);
const LGRAY = rgb(0.72, 0.72, 0.72);
const WHITE = rgb(1, 1, 1);

// Section Y coordinates (from bottom of page)
const MIN_B = 14, MIN_T = 108;
const PRO_B = MIN_T + 1, PRO_T = 222;
const PLN_B = PRO_T + 1, PLN_T = 452;
const NTS_B = PLN_T + 1, NTS_T = 498;
const BRF_B = NTS_T + 1, BRF_T = 548;
const COM_B = BRF_T + 1, COM_T = 574;
const HDR_B = COM_T + 1, HDR_T = PAGE_H - 8;

// ---------------------------------------------------------------------------
// Drawing Helpers
// ---------------------------------------------------------------------------

function tw(f: PDFFont, t: string, s: number) { return f.widthOfTextAtSize(t, s); }
function hLine(p: PDFPage, y: number, x1 = M, x2 = PAGE_W - M, t = 0.5) {
  p.drawLine({ start: { x: x1, y }, end: { x: x2, y }, thickness: t, color: BLACK });
}
function vLine(p: PDFPage, x: number, y1: number, y2: number, t = 0.5) {
  p.drawLine({ start: { x, y: y1 }, end: { x, y: y2 }, thickness: t, color: BLACK });
}
function cText(p: PDFPage, t: string, x: number, y: number, f: PDFFont, s: number, c = BLACK) {
  p.drawText(t, { x: x - tw(f, t, s) / 2, y, size: s, font: f, color: c });
}
function rText(p: PDFPage, t: string, x: number, y: number, f: PDFFont, s: number, c = BLACK) {
  p.drawText(t, { x: x - tw(f, t, s), y, size: s, font: f, color: c });
}

function dashedLine(p: PDFPage, x1: number, y1: number, x2: number, y2: number, dash = 4, gap = 3, t = 1) {
  const dx = x2 - x1, dy = y2 - y1;
  const len = Math.sqrt(dx * dx + dy * dy);
  if (len < 1) return;
  const steps = Math.floor(len / (dash + gap));
  for (let s = 0; s < steps; s++) {
    const t1 = (s * (dash + gap)) / len;
    const t2 = Math.min((s * (dash + gap) + dash) / len, 1);
    p.drawLine({
      start: { x: x1 + dx * t1, y: y1 + dy * t1 },
      end: { x: x1 + dx * t2, y: y1 + dy * t2 },
      thickness: t, color: BLACK,
    });
  }
}

function drawTriangle(p: PDFPage, cx: number, cy: number, sz: number, filled = false) {
  const h = sz * 0.866, hw = sz / 2;
  const pts = [
    { x: cx, y: cy + h * 0.67 },
    { x: cx - hw, y: cy - h * 0.33 },
    { x: cx + hw, y: cy - h * 0.33 },
  ];
  for (let i = 0; i < 3; i++) {
    p.drawLine({ start: pts[i], end: pts[(i + 1) % 3], thickness: 1.2, color: BLACK });
  }
  if (filled) p.drawCircle({ x: cx, y: cy, size: 1.2, color: BLACK });
}

function drawMalteseCross(p: PDFPage, cx: number, cy: number, sz: number) {
  const arm = sz, t = sz * 0.35;
  // Four arms
  for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
    p.drawLine({ start: { x: cx + dx * t, y: cy + dy * t }, end: { x: cx + dx * arm, y: cy + dy * arm }, thickness: 2, color: BLACK });
    // Crossbar at end of arm
    const ex = cx + dx * arm, ey = cy + dy * arm;
    if (dx !== 0) {
      p.drawLine({ start: { x: ex, y: ey - t }, end: { x: ex, y: ey + t }, thickness: 1.5, color: BLACK });
    } else {
      p.drawLine({ start: { x: ex - t, y: ey }, end: { x: ex + t, y: ey }, thickness: 1.5, color: BLACK });
    }
  }
}

function drawMapSymbol(p: PDFPage, cx: number, cy: number, sz: number) {
  // MAP "M" lightning bolt style — simplified as bold M
  const s = sz;
  p.drawLine({ start: { x: cx - s, y: cy + s }, end: { x: cx - s, y: cy - s }, thickness: 1.5, color: BLACK });
  p.drawLine({ start: { x: cx - s, y: cy + s }, end: { x: cx, y: cy - s * 0.3 }, thickness: 1.5, color: BLACK });
  p.drawLine({ start: { x: cx, y: cy - s * 0.3 }, end: { x: cx + s, y: cy + s }, thickness: 1.5, color: BLACK });
  p.drawLine({ start: { x: cx + s, y: cy + s }, end: { x: cx + s, y: cy - s }, thickness: 1.5, color: BLACK });
}

function drawVor(p: PDFPage, cx: number, cy: number, r: number) {
  // Hexagonal VOR symbol with compass rose ticks
  for (let i = 0; i < 6; i++) {
    const a1 = (i * 60 - 30) * Math.PI / 180;
    const a2 = ((i + 1) * 60 - 30) * Math.PI / 180;
    p.drawLine({
      start: { x: cx + r * Math.cos(a1), y: cy + r * Math.sin(a1) },
      end: { x: cx + r * Math.cos(a2), y: cy + r * Math.sin(a2) },
      thickness: 1, color: BLACK,
    });
  }
  p.drawCircle({ x: cx, y: cy, size: 1.5, color: BLACK });
  // Compass ticks at N/S/E/W
  for (let a = 0; a < 360; a += 90) {
    const rad = a * Math.PI / 180;
    p.drawLine({
      start: { x: cx + (r + 1) * Math.cos(rad), y: cy + (r + 1) * Math.sin(rad) },
      end: { x: cx + (r + 4) * Math.cos(rad), y: cy + (r + 4) * Math.sin(rad) },
      thickness: 0.8, color: BLACK,
    });
  }
}

// ---------------------------------------------------------------------------
// Geo Projection
// ---------------------------------------------------------------------------

interface GeoExtent { minLat: number; maxLat: number; minLon: number; maxLon: number; }

function computeExtent(legs: Leg[], rwy: RunwayData | null, ils: IlsData | null): GeoExtent {
  const lats: number[] = [], lons: number[] = [];
  for (const l of legs) {
    if (l.fix_latitude != null) { lats.push(l.fix_latitude); lons.push(l.fix_longitude!); }
  }
  if (rwy) { lats.push(rwy.threshold_latitude); lons.push(rwy.threshold_longitude); }
  if (ils) {
    lats.push(ils.localizer_latitude, ils.gs_latitude);
    lons.push(ils.localizer_longitude, ils.gs_longitude);
  }
  if (!lats.length) return { minLat: 39.5, maxLat: 40.2, minLon: -105.2, maxLon: -104.2 };
  const pad = 0.18;
  const latR = Math.max(...lats) - Math.min(...lats), lonR = Math.max(...lons) - Math.min(...lons);
  return {
    minLat: Math.min(...lats) - Math.max(latR * pad, 0.05),
    maxLat: Math.max(...lats) + Math.max(latR * pad, 0.05),
    minLon: Math.min(...lons) - Math.max(lonR * pad, 0.05),
    maxLon: Math.max(...lons) + Math.max(lonR * pad, 0.05),
  };
}

function geoToXY(lat: number, lon: number, ext: GeoExtent, px: number, py: number, pw: number, ph: number) {
  const cosLat = Math.cos(((ext.minLat + ext.maxLat) / 2) * Math.PI / 180);
  const nLon = (lon - ext.minLon) / (ext.maxLon - ext.minLon);
  const nLat = (lat - ext.minLat) / (ext.maxLat - ext.minLat);
  const geoA = ((ext.maxLon - ext.minLon) * cosLat) / (ext.maxLat - ext.minLat);
  const viewA = pw / ph;
  let sx: number, sy: number, ox = 0, oy = 0;
  if (geoA > viewA) { sx = pw; sy = pw / geoA; oy = (ph - sy) / 2; }
  else { sy = ph; sx = ph * geoA; ox = (pw - sx) / 2; }
  return { x: px + ox + nLon * sx, y: py + oy + nLat * sy };
}

function fmtDegMin(dd: number): string {
  const a = Math.abs(dd), d = Math.floor(a + 0.0001), m = Math.round((a - d) * 60);
  return m >= 60 ? `${d + 1}-00` : `${d}-${String(m).padStart(2, '0')}`;
}

function parseDist(s: string | null): number {
  if (!s || s.startsWith('T')) return 0;
  const n = parseInt(s); return isNaN(n) ? 0 : n / 10;
}

/** Find the FAF fix — the last named approach fix before MAP */
function findFaf(legs: Leg[]): Leg | null {
  // First try explicit flag
  const explicit = legs.find(l => l.is_faf);
  if (explicit) return explicit;
  // Fallback: last fix before MAP with an altitude (typically the FAF in ILS approaches)
  const mapIdx = legs.findIndex(l => l.is_map);
  const appLegs = (mapIdx >= 0 ? legs.slice(0, mapIdx) : legs).filter(l => l.fix_identifier && !l.fix_identifier.startsWith('RW'));
  return appLegs.length > 0 ? appLegs[appLegs.length - 1] : null;
}

// ---------------------------------------------------------------------------
// Section Renderers
// ---------------------------------------------------------------------------

function renderHeader(pg: PDFPage, c: ChartData, a: AirportInfo, B: PDFFont, R: PDFFont) {
  // Double line at top
  hLine(pg, HDR_T, M, PAGE_W - M, 2);
  hLine(pg, HDR_T - 3, M, PAGE_W - M, 0.5);

  // Left: airport ID
  pg.drawText(`${a.icao_identifier}/${a.identifier}`, { x: M + 4, y: HDR_T - 16, size: 11, font: B });
  pg.drawText(a.name.toUpperCase(), { x: M + 4, y: HDR_T - 26, size: 6.5, font: R });

  // Right: city/state + procedure
  const city = `${a.city.toUpperCase()}, ${a.state.toUpperCase().substring(0, 4)}`;
  rText(pg, city, PAGE_W - M - 4, HDR_T - 13, B, 9);
  // Use "ILS or LOC Rwy XX" format like Jeppesen
  let proc = c.approach.procedure_name || 'APPROACH';
  if (c.approach.route_type === 'I') {
    const rwy = c.approach.runway_identifier?.replace('RW', '') || '';
    proc = `ILS or LOC Rwy ${rwy}`;
  }
  rText(pg, proc, PAGE_W - M - 4, HDR_T - 26, B, 11);

  hLine(pg, HDR_B, M, PAGE_W - M, 1);
}

function renderComm(pg: PDFPage, a: AirportInfo, B: PDFFont, R: PDFFont) {
  hLine(pg, COM_T, M, PAGE_W - M, 0.5);
  hLine(pg, COM_B, M, PAGE_W - M, 0.5);

  const cw = (PAGE_W - 2 * M) / 4;
  const labels = ['D-ATIS Arrival', `${a.name.split(' ')[0].toUpperCase()} Approach`, `${a.name.split(' ')[0].toUpperCase()} Tower`, 'Ground'];
  const fMap: Record<string, string[]> = { ATIS: [], APP: [], TWR: [], GND: [] };

  if (a.frequencies) {
    for (const f of a.frequencies) {
      const t = (f.type || f.name || '').toUpperCase();
      const fv = parseFloat(String(f.frequency).split(';')[0].trim());
      if (isNaN(fv)) continue;
      const fs = fv.toFixed(fv % 1 === 0 ? 1 : String(fv).split('.')[1]?.length || 1);
      if (t.includes('ATIS')) fMap.ATIS.push(fs);
      else if (t.includes('APP') || t.includes('TRACON')) fMap.APP.push(fs);
      else if (t.includes('TWR') || t.includes('LCL')) fMap.TWR.push(fs);
      else if (t.includes('GND')) fMap.GND.push(fs);
    }
  }

  const keys = ['ATIS', 'APP', 'TWR', 'GND'];
  for (let i = 0; i < 4; i++) {
    const cx = M + cw * i + cw / 2;
    cText(pg, labels[i], cx, COM_T - 9, R, 5.5);
    const freqs = fMap[keys[i]];
    if (freqs.length) cText(pg, freqs.slice(0, 2).join('   '), cx, COM_T - 19, B, 7.5);
    if (i < 3) vLine(pg, M + cw * (i + 1), COM_B, COM_T, 0.3);
  }
}

function renderBriefing(pg: PDFPage, c: ChartData, a: AirportInfo, B: PDFFont, R: PDFFont) {
  // Thick borders
  hLine(pg, BRF_T, M, PAGE_W - M, 1.5);
  hLine(pg, BRF_B, M, PAGE_W - M, 1.5);
  vLine(pg, M, BRF_B, BRF_T, 1.5);
  vLine(pg, PAGE_W - M, BRF_B, BRF_T, 1.5);

  const tdze = c.runway?.threshold_elevation || a.elevation;
  const cw = (PAGE_W - 2 * M) / 5;
  const course = c.legs.find(l => l.magnetic_course && !l.is_map)?.magnetic_course;
  const courseTxt = course ? `${Math.round(course)}°` : '';

  // Column headers and values
  const headers = [
    ['LOC', c.ils?.localizer_identifier || ''],
    ['Final', 'Apch Crs'],
    ['', ''],
    [c.ils ? 'ILS' : 'LOC', 'DA(H)'],
    ['Apt Elev', `${Math.round(a.elevation)}'`],
  ];

  // Find FAF fix
  const fafLeg = findFaf(c.legs);
  const fafName = fafLeg?.fix_identifier || '';
  const fafAlt = fafLeg?.altitude1 || 0;
  const fafHat = fafAlt > tdze ? fafAlt - tdze : 0;

  const da = tdze + 200;
  const values = [
    c.ils ? c.ils.frequency.toFixed(2) : '',
    courseTxt,
    fafName,
    `${da}'(200')`,
    `TDZE ${tdze}'`,
  ];
  const subValues = ['', '', fafAlt ? `${fafAlt}' (${fafHat}')` : '', '', ''];

  for (let i = 0; i < 5; i++) {
    const cx = M + cw * i + cw / 2;
    // Header labels
    cText(pg, headers[i][0], cx, BRF_T - 9, R, 5.5);
    cText(pg, headers[i][1], cx, BRF_T - 16, R, 5.5);
    // Main value
    cText(pg, values[i], cx, BRF_T - 28, B, values[i].length > 10 ? 7.5 : 9);
    // Sub value
    if (subValues[i]) cText(pg, subValues[i], cx, BRF_T - 38, R, 6.5);
    // Column dividers
    if (i < 4) vLine(pg, M + cw * (i + 1), BRF_B + 14, BRF_T, 0.3);
  }

  // Missed approach text at bottom of briefing strip
  const mapIdx = c.legs.findIndex(l => l.is_map);
  const missedLegs = mapIdx >= 0 ? c.legs.slice(mapIdx + 1) : [];
  const holdLeg = missedLegs.find(l => l.path_termination === 'HM' || l.path_termination === 'HF');
  const climbAlt = holdLeg?.altitude1 || 10000;
  const holdFix = holdLeg?.fix_identifier || '';

  let missedText = `MISSED APCH: Climb to ${climbAlt}' on heading ${courseTxt}`;
  if (holdFix) {
    // Add navaid info for missed approach
    const cfLeg = missedLegs.find(l => l.path_termination === 'CF' && l.recomm_navaid);
    if (cfLeg?.recomm_navaid && cfLeg.rho) {
      missedText += ` and outbound on ${cfLeg.recomm_navaid} R-${Math.round(cfLeg.magnetic_course || 0)}`;
      missedText += ` to ${holdFix} INT/D${cfLeg.rho} ${cfLeg.recomm_navaid} and hold.`;
    } else {
      missedText += ` to ${holdFix} and hold.`;
    }
  }

  pg.drawText(missedText, { x: M + 4, y: BRF_B + 2, size: 5, font: B, maxWidth: PAGE_W - 2 * M - 8 });
}

function renderMsa(pg: PDFPage, c: ChartData, B: PDFFont, R: PDFFont) {
  if (!c.msa) return;
  const cx = PAGE_W - M - 44, cy = NTS_B + (NTS_T - NTS_B) / 2 + 4, r = 26;

  pg.drawCircle({ x: cx, y: cy, size: r, borderColor: BLACK, borderWidth: 1, color: WHITE });
  cText(pg, `MSA ${c.msa.msa_center}`, cx, cy + r + 5, R, 5.5);
  cText(pg, `${c.msa.sectors[0]?.radius || 25} NM`, cx, cy + r - 1, R, 4.5);

  if (c.msa.sectors.length === 1) {
    cText(pg, `${c.msa.sectors[0].altitude}`, cx, cy - 4, B, 10);
  } else {
    for (const s of c.msa.sectors) {
      // Draw dividing line at sector boundary
      const a = (90 - s.bearing_from) * Math.PI / 180;
      pg.drawLine({ start: { x: cx, y: cy }, end: { x: cx + r * Math.cos(a), y: cy + r * Math.sin(a) }, thickness: 0.5, color: BLACK });

      // Calculate midpoint bearing (handle wrap-around)
      let midBearing: number;
      if (s.bearing_from <= s.bearing_to) {
        midBearing = (s.bearing_from + s.bearing_to) / 2;
      } else {
        midBearing = (s.bearing_from + s.bearing_to + 360) / 2;
        if (midBearing >= 360) midBearing -= 360;
      }
      const mid = (90 - midBearing) * Math.PI / 180;
      cText(pg, `${s.altitude}`, cx + r * 0.45 * Math.cos(mid), cy + r * 0.45 * Math.sin(mid) - 3, B, 8);

      // Bearing labels at sector boundaries
      const bLabel = s.bearing_from === 360 ? '360°' : `${s.bearing_from}°`;
      const bx = cx + (r + 8) * Math.cos(a), by = cy + (r + 8) * Math.sin(a);
      cText(pg, bLabel, bx, by - 2, R, 3.5);
    }
  }
}

function renderNotes(pg: PDFPage, c: ChartData, B: PDFFont, R: PDFFont) {
  hLine(pg, NTS_T, M, PAGE_W - M - 80, 0.3);
  // Notes text
  pg.drawText('Alt Set: INCHES     Trans level: FL 180     Trans alt: 18000\'', { x: M + 4, y: NTS_T - 10, size: 5, font: R });
  pg.drawText('1. Radar required.', { x: M + 4, y: NTS_T - 20, size: 5, font: R });
}

function renderPlanView(pg: PDFPage, c: ChartData, a: AirportInfo, B: PDFFont, R: PDFFont) {
  const px = M + 2, py = PLN_B + 2, pw = PAGE_W - 2 * M - 4, ph = PLN_T - PLN_B - 4;

  // Border
  pg.drawRectangle({ x: M, y: PLN_B, width: PAGE_W - 2 * M, height: PLN_T - PLN_B, borderColor: BLACK, borderWidth: 0.8, color: WHITE });

  pg.drawText('NOT TO SCALE', { x: M + 4, y: PLN_T - 11, size: 5, font: R, color: GRAY });

  const ext = computeExtent(c.legs, c.runway, c.ils);
  const mapIdx = c.legs.findIndex(l => l.is_map);

  // Lat/lon grid with tick marks on border
  const step = 10 / 60;
  for (let lat = Math.ceil(ext.minLat / step) * step; lat <= ext.maxLat; lat += step) {
    const p1 = geoToXY(lat, ext.minLon, ext, px, py, pw, ph);
    const p2 = geoToXY(lat, ext.maxLon, ext, px, py, pw, ph);
    if (p1.y > py + 5 && p1.y < py + ph - 5) {
      pg.drawLine({ start: p1, end: p2, thickness: 0.15, color: LGRAY });
      // Tick + label on left border
      pg.drawLine({ start: { x: M, y: p1.y }, end: { x: M + 4, y: p1.y }, thickness: 0.5, color: BLACK });
      pg.drawText(fmtDegMin(lat), { x: M + 1, y: p1.y + 2, size: 3.5, font: R, color: GRAY });
    }
  }
  for (let lon = Math.ceil(ext.minLon / step) * step; lon <= ext.maxLon; lon += step) {
    const p1 = geoToXY(ext.minLat, lon, ext, px, py, pw, ph);
    const p2 = geoToXY(ext.maxLat, lon, ext, px, py, pw, ph);
    if (p1.x > px + 5 && p1.x < px + pw - 5) {
      pg.drawLine({ start: p1, end: p2, thickness: 0.15, color: LGRAY });
      pg.drawLine({ start: { x: p1.x, y: PLN_B }, end: { x: p1.x, y: PLN_B + 4 }, thickness: 0.5, color: BLACK });
      pg.drawText(fmtDegMin(Math.abs(lon)), { x: p1.x + 2, y: PLN_B + 2, size: 3.5, font: R, color: GRAY });
    }
  }

  // Draw course lines
  const vis = c.legs.filter(l => l.fix_latitude != null && l.fix_longitude != null);
  for (let i = 0; i < vis.length - 1; i++) {
    const l = vis[i], n = vis[i + 1];
    const p1 = geoToXY(l.fix_latitude!, l.fix_longitude!, ext, px, py, pw, ph);
    const p2 = geoToXY(n.fix_latitude!, n.fix_longitude!, ext, px, py, pw, ph);
    const nIdx = c.legs.indexOf(n);
    const isMissed = mapIdx >= 0 && nIdx > mapIdx;

    if (isMissed) {
      dashedLine(pg, p1.x, p1.y, p2.x, p2.y, 5, 4, 1);
    } else {
      pg.drawLine({ start: p1, end: p2, thickness: 1.5, color: BLACK });
    }

    // Course label — only on segments long enough and avoid repeating same course
    const segLen = Math.sqrt((p2.x - p1.x) ** 2 + (p2.y - p1.y) ** 2);
    const prevCourse = i > 0 ? vis[i].magnetic_course : null;
    const showCourse = n.magnetic_course && !isMissed && segLen > 60
      && (prevCourse == null || Math.round(prevCourse) !== Math.round(n.magnetic_course!));
    if (showCourse) {
      const mx = (p1.x + p2.x) / 2, my = (p1.y + p2.y) / 2;
      const label = `${Math.round(n.magnetic_course!)}°`;
      const lw = tw(B, label, 8) + 6;
      pg.drawRectangle({ x: mx - lw / 2, y: my + 2, width: lw, height: 11, color: WHITE });
      cText(pg, label, mx, my + 4, B, 8);
    }
  }

  // ILS identification box (top-right of plan view, Jeppesen style)
  if (c.ils) {
    const boxW = 100, boxH = 20;
    const bx = px + pw - boxW - 5, by = PLN_T - boxH - 18;
    pg.drawRectangle({ x: bx, y: by, width: boxW, height: boxH, borderColor: BLACK, borderWidth: 1, color: WHITE });

    const ilsText = `${Math.round(c.ils.localizer_bearing)}°  ${c.ils.frequency.toFixed(2)}  ${c.ils.localizer_identifier}`;
    cText(pg, ilsText, bx + boxW / 2, by + 6, B, 7);
    cText(pg, 'ILS DME', bx + boxW / 2, by + boxH + 2, R, 5, GRAY);

    // Localizer course dashes inside the box
    pg.drawLine({ start: { x: bx + 3, y: by + boxH / 2 }, end: { x: bx + 12, y: by + boxH / 2 }, thickness: 0.8, color: BLACK });
    pg.drawLine({ start: { x: bx + boxW - 12, y: by + boxH / 2 }, end: { x: bx + boxW - 3, y: by + boxH / 2 }, thickness: 0.8, color: BLACK });
  }

  // Draw runway
  if (c.runway) {
    const rp = geoToXY(c.runway.threshold_latitude, c.runway.threshold_longitude, ext, px, py, pw, ph);
    const bear = (c.runway.runway_bearing || 0) * Math.PI / 180;
    const rLen = 20, rW = 3;
    const dx = Math.sin(bear), dy = -Math.cos(bear);
    const nx = -dy, ny = dx;
    const corners = [
      { x: rp.x - nx * rW / 2, y: rp.y - ny * rW / 2 },
      { x: rp.x + nx * rW / 2, y: rp.y + ny * rW / 2 },
      { x: rp.x + nx * rW / 2 + dx * rLen, y: rp.y + ny * rW / 2 - dy * rLen },
      { x: rp.x - nx * rW / 2 + dx * rLen, y: rp.y - ny * rW / 2 - dy * rLen },
    ];
    for (let i = 0; i < 4; i++) pg.drawLine({ start: corners[i], end: corners[(i + 1) % 4], thickness: 1.5, color: BLACK });
  }

  // Localizer feather — wider funnel like Jeppesen
  if (c.ils) {
    const lp = geoToXY(c.ils.localizer_latitude, c.ils.localizer_longitude, ext, px, py, pw, ph);
    const bear = (c.ils.localizer_bearing || 0) * Math.PI / 180;
    const fLen = 20; // wider crossbar
    const dx = Math.sin(bear), dy = -Math.cos(bear);
    const nx = -dy, ny = dx;

    // Main cross-bar
    pg.drawLine({
      start: { x: lp.x - nx * fLen, y: lp.y - ny * fLen },
      end: { x: lp.x + nx * fLen, y: lp.y + ny * fLen },
      thickness: 1.5, color: BLACK,
    });
    // Tick marks (inward facing, like Jeppesen)
    for (const t of [-1.0, -0.7, -0.4, 0.4, 0.7, 1.0]) {
      const bx = lp.x + nx * fLen * t, by = lp.y + ny * fLen * t;
      pg.drawLine({ start: { x: bx, y: by }, end: { x: bx + dx * 5, y: by - dy * 5 }, thickness: 0.7, color: BLACK });
    }
  }

  // Fix symbols and labels — track positions to avoid overlap
  const labelPositions: { x: number; y: number }[] = [];
  for (const leg of c.legs) {
    if (!leg.fix_latitude || !leg.fix_longitude) continue;
    const p = geoToXY(leg.fix_latitude, leg.fix_longitude, ext, px, py, pw, ph);
    const legIdx = c.legs.indexOf(leg);
    const isMissedFix = mapIdx >= 0 && legIdx > mapIdx;

    if (!leg.fix_identifier?.startsWith('RW')) {
      drawTriangle(pg, p.x, p.y, 5);
    }

    if (leg.fix_identifier && !leg.fix_identifier.startsWith('RW')) {
      let lx = p.x + 8, ly = p.y + 3;

      // Check for overlap with previous labels and offset
      for (const prev of labelPositions) {
        const dx = Math.abs(lx - prev.x), dy = Math.abs(ly - prev.y);
        if (dx < 40 && dy < 20) { ly -= 22; }
      }
      labelPositions.push({ x: lx, y: ly });

      // Bold fix name
      pg.drawText(leg.fix_identifier, { x: lx, y: ly, size: 6.5, font: B });

      // Role label
      let role = '';
      if (leg.is_iaf) role = '(IAF)';
      else if (leg.is_if) role = '(IF)';
      else if (leg.is_faf) role = '(FAF)';
      if (role) pg.drawText(role, { x: lx, y: ly - 7.5, size: 5, font: B });

      // DME info
      if (leg.recomm_navaid && leg.rho) {
        const dmeY = ly - (role ? 15 : 7.5);
        pg.drawText(`D${leg.rho.toFixed(1)} ${leg.recomm_navaid}`, { x: lx, y: dmeY, size: 4.5, font: R });
        // RADAR FIX label for approach fixes
        if (!isMissedFix) pg.drawText('RADAR FIX', { x: lx, y: dmeY - 7, size: 4, font: R, color: GRAY });
      }

      // MISSED APCH FIX label
      if (isMissedFix && leg.path_termination === 'CF') {
        pg.drawText('MISSED APCH FIX', { x: lx, y: ly - (role ? 22 : 15), size: 4, font: R, color: GRAY });
      }
    }
  }

  // Holding pattern
  const hLeg = c.legs.find(l => (l.path_termination === 'HM' || l.path_termination === 'HF') && l.fix_latitude && l.magnetic_course != null);
  if (hLeg) {
    const hp = geoToXY(hLeg.fix_latitude!, hLeg.fix_longitude!, ext, px, py, pw, ph);
    const hc = (hLeg.magnetic_course! || 0) * Math.PI / 180;
    const tLen = 28, tW = 12;
    const dx = Math.sin(hc), dy = -Math.cos(hc);
    const right = hLeg.turn_direction === 'R' ? 1 : -1;
    const nx = -dy * right, ny = dx * right;
    const ex = hp.x + dx * tLen, ey = hp.y - dy * tLen;

    dashedLine(pg, hp.x, hp.y, ex, ey, 4, 3, 0.8);
    dashedLine(pg, hp.x + nx * tW, hp.y + ny * tW, ex + nx * tW, ey + ny * tW, 4, 3, 0.8);

    // Arcs at ends
    const cr = tW / 2;
    for (let a = 0; a < Math.PI; a += Math.PI / 10) {
      const ba = Math.atan2(ny, nx);
      const cx1 = hp.x + nx * cr, cy1 = hp.y + ny * cr;
      const cx2 = ex + nx * cr, cy2 = ey + ny * cr;
      pg.drawLine({
        start: { x: cx1 + cr * Math.cos(ba + a * right), y: cy1 + cr * Math.sin(ba + a * right) },
        end: { x: cx1 + cr * Math.cos(ba + (a + Math.PI / 10) * right), y: cy1 + cr * Math.sin(ba + (a + Math.PI / 10) * right) },
        thickness: 0.8, color: BLACK,
      });
      pg.drawLine({
        start: { x: cx2 + cr * Math.cos(ba + Math.PI + a * right), y: cy2 + cr * Math.sin(ba + Math.PI + a * right) },
        end: { x: cx2 + cr * Math.cos(ba + Math.PI + (a + Math.PI / 10) * right), y: cy2 + cr * Math.sin(ba + Math.PI + (a + Math.PI / 10) * right) },
        thickness: 0.8, color: BLACK,
      });
    }
  }

  // Airport VOR symbol — larger compass rose with frequency like Jeppesen
  const ap = geoToXY(a.latitude, a.longitude, ext, px, py, pw, ph);
  // Outer compass rose circle
  pg.drawCircle({ x: ap.x, y: ap.y, size: 14, borderColor: BLACK, borderWidth: 0.4 });
  drawVor(pg, ap.x, ap.y, 8);
  // Compass tick marks every 30 degrees
  for (let a2 = 0; a2 < 360; a2 += 30) {
    const rad = a2 * Math.PI / 180;
    const inner = a2 % 90 === 0 ? 12 : 13;
    pg.drawLine({
      start: { x: ap.x + inner * Math.cos(rad), y: ap.y + inner * Math.sin(rad) },
      end: { x: ap.x + 16 * Math.cos(rad), y: ap.y + 16 * Math.sin(rad) },
      thickness: a2 % 90 === 0 ? 1 : 0.4, color: BLACK,
    });
  }
  // VOR name + frequency label
  pg.drawText(a.name.split(' ')[0].toUpperCase(), { x: ap.x + 18, y: ap.y + 10, size: 5, font: R });
  pg.drawText(`${a.identifier}`, { x: ap.x + 18, y: ap.y + 2, size: 6, font: B });
  pg.drawText(`(H)`, { x: ap.x + 18, y: ap.y - 6, size: 4.5, font: R });
  // VOR frequency from airport freqs
  if (a.frequencies) {
    const vorFreq = a.frequencies.find(f => (f.type || '').toUpperCase().includes('VOR'));
    if (vorFreq) {
      const fv = parseFloat(String(vorFreq.frequency).split(';')[0].trim());
      if (!isNaN(fv)) pg.drawText(`${fv.toFixed(1)} ${a.identifier}`, { x: ap.x + 18, y: ap.y - 14, size: 4.5, font: R });
    }
  }
}

function renderProfile(pg: PDFPage, c: ChartData, B: PDFFont, R: PDFFont) {
  const w = PAGE_W - 2 * M, h = PRO_T - PRO_B;
  pg.drawRectangle({ x: M, y: PRO_B, width: w, height: h, borderColor: BLACK, borderWidth: 0.8, color: WHITE });

  const pad = 8;
  const profX = M + pad, profW = w - 2 * pad;
  const groundY = PRO_B + 38, profH = PRO_T - groundY - 8;

  const mapIdx = c.legs.findIndex(l => l.is_map);
  const appLegs = (mapIdx >= 0 ? c.legs.slice(0, mapIdx) : c.legs).filter(l => l.fix_identifier);
  const missLegs = (mapIdx >= 0 ? c.legs.slice(mapIdx + 1) : []).filter(l => l.fix_identifier);
  const mapLeg = mapIdx >= 0 ? c.legs[mapIdx] : null;

  const tdze = c.runway?.threshold_elevation || 5355;
  const tch = c.runway?.threshold_crossing_height || 55;

  // Build distance array backwards from threshold
  const fixes: { name: string; dist: number; alt: number; leg: Leg }[] = [];
  let cum = mapLeg ? parseDist(mapLeg.route_distance_or_time) : 0;
  for (let i = appLegs.length - 1; i >= 0; i--) {
    fixes.unshift({ name: appLegs[i].fix_identifier!, dist: cum, alt: appLegs[i].altitude1 || tdze, leg: appLegs[i] });
    cum += parseDist(appLegs[i].route_distance_or_time);
  }
  const totalDist = Math.max(cum, 1);

  const holdLeg = missLegs.find(l => l.path_termination === 'HM' || l.path_termination === 'HF');
  const missAlt = holdLeg?.altitude1 || 10000;
  const missFix = holdLeg?.fix_identifier || '';

  // Identify FAF — last approach fix before MAP
  const fafLegProf = findFaf(c.legs);
  const fafFix = fafLegProf?.fix_identifier || fixes[fixes.length - 1]?.name || '';

  const maxAlt = Math.max(...c.legs.map(l => l.altitude1 || 0), tdze + 1000);
  const altRng = maxAlt - tdze + 500;

  // Ground line
  hLine(pg, groundY, profX, profX + profW, 1);

  // Coordinate functions — threshold LEFT, approach extends RIGHT, missed approach far RIGHT
  const threshFrac = 0.10, maxFrac = 0.64;
  const d2x = (d: number) => profX + threshFrac * profW + (d / totalDist) * (maxFrac - threshFrac) * profW;
  const a2y = (alt: number) => groundY + ((alt - tdze) / altRng) * profH;
  const threshX = d2x(0);

  // === APPROACH COURSE LINE (step-down depiction) ===
  for (let i = 0; i < fixes.length - 1; i++) {
    const f1 = fixes[i], f2 = fixes[i + 1];
    const stepAlt = Math.min(f1.alt, f2.alt);
    const x1 = d2x(f1.dist), x2 = d2x(f2.dist);
    const sy = a2y(stepAlt);
    pg.drawLine({ start: { x: x1, y: sy }, end: { x: x2, y: sy }, thickness: 0.8, color: BLACK });

    if (f1.alt !== f2.alt) {
      const sx = d2x(f2.dist);
      pg.drawLine({ start: { x: sx, y: a2y(f1.alt) }, end: { x: sx, y: a2y(f2.alt) }, thickness: 0.8, color: BLACK });
    }
  }

  // GS line from FAF to threshold
  if (c.ils) {
    const faf = fixes.find(f => f.name === fafFix);
    if (faf) {
      const gsx1 = d2x(faf.dist), gsy1 = a2y(faf.alt);
      const gsy2 = a2y(tdze + tch);

      pg.drawLine({ start: { x: gsx1, y: gsy1 }, end: { x: threshX, y: gsy2 }, thickness: 2, color: BLACK });

      // GS intercept arrow at FAF (small upward arrow)
      pg.drawLine({ start: { x: gsx1 + 5, y: gsy1 - 5 }, end: { x: gsx1 + 5, y: gsy1 + 5 }, thickness: 1, color: BLACK });
      pg.drawLine({ start: { x: gsx1 + 2, y: gsy1 + 2 }, end: { x: gsx1 + 5, y: gsy1 + 5 }, thickness: 1, color: BLACK });
      pg.drawLine({ start: { x: gsx1 + 8, y: gsy1 + 2 }, end: { x: gsx1 + 5, y: gsy1 + 5 }, thickness: 1, color: BLACK });
    }
  }

  // Fix markers — stagger labels when fixes are close
  const fixXPositions: number[] = [];
  for (const f of fixes) {
    const fx = d2x(f.dist), fy = a2y(f.alt);

    // Vertical tick from ground to altitude
    vLine(pg, fx, groundY, fy, 0.5);

    // Stagger labels if too close to previous fix
    let labelYOff = 0;
    for (const prevX of fixXPositions) {
      if (Math.abs(fx - prevX) < 35) { labelYOff = -14; break; }
    }
    fixXPositions.push(fx);

    // Fix name at top (bold)
    cText(pg, f.name, fx, PRO_T - 10 + labelYOff, B, 6);

    // DME info below name
    if (f.leg.recomm_navaid && f.leg.rho) {
      cText(pg, `D${f.leg.rho.toFixed(1)} ${f.leg.recomm_navaid}`, fx, PRO_T - 17 + labelYOff, R, 4);
      cText(pg, 'RADAR FIX', fx, PRO_T - 22 + labelYOff, R, 3.5, GRAY);
    }

    // Altitude label — "GS 7000'" at FAF, plain altitude elsewhere
    if (f.name === fafFix) {
      pg.drawText(`GS ${f.alt}'`, { x: fx + 5, y: fy + 2, size: 5.5, font: B });
      drawMalteseCross(pg, fx, groundY - 6, 3);
    } else {
      // Course and altitude label at far fix
      const isFirst = f === fixes[0];
      if (isFirst && c.legs[0]?.magnetic_course) {
        rText(pg, `${Math.round(c.legs[0].magnetic_course)}°`, fx - 4, fy + 2, B, 6);
      }
      pg.drawText(`${f.alt}'`, { x: fx + 3, y: fy + 2, size: 6, font: B });
    }
  }

  // MAP marker at threshold
  if (mapLeg) {
    drawMapSymbol(pg, threshX, groundY - 7, 3);
  }

  // Threshold marker (T-shape)
  vLine(pg, threshX, groundY - 3, groundY + 3, 1.2);
  pg.drawLine({ start: { x: threshX - 3, y: groundY + 4 }, end: { x: threshX + 3, y: groundY + 4 }, thickness: 1, color: BLACK });

  // TDZE and TCH labels
  pg.drawText(`TCH ${tch}'`, { x: threshX - 3, y: groundY + 6, size: 4.5, font: R });
  pg.drawText(`TDZE ${tdze}'`, { x: profX, y: groundY + 6, size: 5, font: B });

  // IERP DME label near threshold
  if (c.ils) {
    pg.drawText('IERP DME', { x: threshX + 8, y: PRO_T - 10, size: 5, font: R });
    // D0.7 label near threshold at top
    pg.drawText(`D0.7`, { x: threshX + 8, y: PRO_T - 18, size: 4.5, font: R });
    pg.drawText('IERP', { x: threshX + 8, y: PRO_T - 24, size: 4, font: R });
  }

  // Course label on GS line
  const courseLeg = c.legs.find(l => l.magnetic_course && !l.is_map && !l.is_missed_approach);
  if (courseLeg?.magnetic_course) {
    const crs = `${Math.round(courseLeg.magnetic_course)}°`;
    const faf = fixes.find(f => f.leg.is_faf) || fixes[fixes.length - 1];
    if (faf) {
      const crsX = (d2x(faf.dist) + threshX) / 2;
      const crsAlt = (faf.alt + tdze + tch) / 2;
      const crsY = a2y(crsAlt);
      const bw = tw(B, crs, 9) + 8;
      pg.drawRectangle({ x: crsX - bw / 2, y: crsY - 2, width: bw, height: 13, color: WHITE, borderColor: BLACK, borderWidth: 0.5 });
      cText(pg, crs, crsX, crsY, B, 9);
    }
  }

  // Distance annotations between fixes (boxes just below ground line)
  const distBoxY = groundY - 13;
  if (fixes.length > 0 && mapLeg) {
    const lastD = parseDist(mapLeg.route_distance_or_time);
    if (lastD > 0) {
      const mx = (threshX + d2x(fixes[fixes.length - 1].dist)) / 2;
      const dtxt = lastD.toFixed(1);
      const bw = tw(R, dtxt, 5.5) + 4;
      pg.drawRectangle({ x: mx - bw / 2, y: distBoxY, width: bw, height: 8, borderColor: BLACK, borderWidth: 0.3 });
      cText(pg, dtxt, mx, distBoxY + 1.5, R, 5.5);
    }
  }
  for (let i = 0; i < fixes.length - 1; i++) {
    const d = Math.abs(fixes[i].dist - fixes[i + 1].dist);
    if (d > 0) {
      const mx = (d2x(fixes[i].dist) + d2x(fixes[i + 1].dist)) / 2;
      const dtxt = d.toFixed(1);
      const bw = tw(R, dtxt, 5.5) + 4;
      pg.drawRectangle({ x: mx - bw / 2, y: distBoxY, width: bw, height: 8, borderColor: BLACK, borderWidth: 0.3 });
      cText(pg, dtxt, mx, distBoxY + 1.5, R, 5.5);
    }
  }

  // === MISSED APPROACH (RIGHT side, Jeppesen style) ===
  const missStartX = profX + profW * 0.68;
  if (missLegs.length > 0) {
    // MALSR/PAPI labels with dashed lines
    const mlY = groundY + profH * 0.32;
    pg.drawText('MALSR', { x: missStartX - 8, y: mlY, size: 4.5, font: R });
    dashedLine(pg, missStartX + 15, mlY + 2, missStartX + 28, mlY + 2, 2, 2, 0.3);
    pg.drawText('PAPI', { x: missStartX - 5, y: mlY - 8, size: 4.5, font: R });
    dashedLine(pg, missStartX + 12, mlY - 6, missStartX + 28, mlY - 6, 2, 2, 0.3);

    // Climb arrow
    const arrowX = missStartX + 34;
    const ay1 = groundY + 6, ay2 = a2y(missAlt);
    pg.drawLine({ start: { x: arrowX, y: ay1 }, end: { x: arrowX, y: ay2 }, thickness: 1, color: BLACK });
    pg.drawLine({ start: { x: arrowX - 3, y: ay2 - 5 }, end: { x: arrowX, y: ay2 }, thickness: 1, color: BLACK });
    pg.drawLine({ start: { x: arrowX + 3, y: ay2 - 5 }, end: { x: arrowX, y: ay2 }, thickness: 1, color: BLACK });

    // Missed approach info to right of arrow
    const txtX = arrowX + 6;
    pg.drawText(`${missAlt}'`, { x: txtX, y: ay2 + 2, size: 5.5, font: B });

    const mc = c.legs.find(l => l.is_map)?.magnetic_course;
    if (mc) {
      pg.drawText(`${Math.round(mc)}°`, { x: txtX, y: ay2 - 8, size: 6, font: B });
    }
    pg.drawText('on', { x: arrowX - 6, y: ay2 - 4, size: 3.5, font: R });
    pg.drawText('hdg', { x: arrowX - 8, y: ay2 - 10, size: 3.5, font: R });

    // Navaid info
    const cfLeg = missLegs.find(l => l.path_termination === 'CF' && l.recomm_navaid);
    if (cfLeg?.recomm_navaid) {
      pg.drawText(cfLeg.recomm_navaid, { x: txtX, y: groundY + profH * 0.28, size: 5.5, font: B });
      pg.drawText(`R-${Math.round(cfLeg.magnetic_course || 0)}`, { x: txtX, y: groundY + profH * 0.20, size: 5, font: R });
      if (missFix) {
        pg.drawText(missFix, { x: txtX, y: groundY + profH * 0.12, size: 5.5, font: B });
      }
    }
  }

  // GS angle / TCH — positioned in upper-right area above missed approach
  if (c.ils) {
    const labelX = missStartX - 6;
    rText(pg, `GS ${c.ils.gs_angle.toFixed(2)}°`, labelX, groundY + profH * 0.82, B, 6);
    rText(pg, `TCH ${tch}'`, labelX, groundY + profH * 0.72, R, 5);
  }

  // === SPEED/TIME TABLE (at bottom of profile section) ===
  const stY = PRO_B + 2;
  const stX = profX + profW * 0.06;
  const speeds = [70, 90, 100, 120, 140, 160];
  const fafDist = mapLeg ? parseDist(mapLeg.route_distance_or_time) : 5;

  pg.drawText('Gnd speed-Kts', { x: stX, y: stY + 16, size: 4.5, font: R });
  // GS descent rate row
  if (c.ils) {
    pg.drawText(`GS`, { x: stX, y: stY + 9, size: 4.5, font: R });
    pg.drawText(`${c.ils.gs_angle.toFixed(2)}°`, { x: stX + 10, y: stY + 9, size: 4.5, font: R });
  }
  pg.drawText(`${fafFix} to MAP`, { x: stX, y: stY + 2, size: 4.5, font: R });
  pg.drawText(`${fafDist.toFixed(1)}`, { x: stX + 48, y: stY + 2, size: 4.5, font: B });

  for (let i = 0; i < speeds.length; i++) {
    const sx = stX + 62 + i * 23;
    cText(pg, `${speeds[i]}`, sx, stY + 16, B, 4.5);

    // GS descent rate (ft/min) = speed * 101.27 * tan(gs_angle)
    if (c.ils) {
      const gsRad = c.ils.gs_angle * Math.PI / 180;
      const descentRate = Math.round(speeds[i] * 101.27 * Math.tan(gsRad));
      cText(pg, `${descentRate}`, sx, stY + 9, R, 4.5);
    }

    // Time: dist / speed * 60 = minutes
    const timeMin = (fafDist / speeds[i]) * 60;
    const mm = Math.floor(timeMin);
    const ss = Math.round((timeMin - mm) * 60);
    cText(pg, `${mm}:${String(ss).padStart(2, '0')}`, sx, stY + 2, R, 4.5);
  }
}

function renderMinimums(pg: PDFPage, c: ChartData, B: PDFFont, R: PDFFont) {
  const w = PAGE_W - 2 * M;
  pg.drawRectangle({ x: M, y: MIN_B, width: w, height: MIN_T - MIN_B, borderColor: BLACK, borderWidth: 1, color: WHITE });
  hLine(pg, MIN_T, M, PAGE_W - M, 1.5);

  const tdze = c.runway?.threshold_elevation || 5355;
  const rwyNum = c.approach.runway_identifier?.replace('RW', 'RWY ') || '';

  // Header
  cText(pg, `STRAIGHT-IN LANDING ${rwyNum}`, PAGE_W / 2, MIN_T - 11, B, 7);
  hLine(pg, MIN_T - 14, M, PAGE_W - M, 0.3);

  const midX = PAGE_W / 2;

  if (c.ils) {
    // ILS column
    cText(pg, 'ILS', midX - 65, MIN_T - 24, B, 8);
    const da = tdze + 200;
    cText(pg, `DA(H) ${da}'(200')`, midX - 65, MIN_T - 38, B, 9);

    // LOC column
    cText(pg, 'LOC (GS out)', midX + 55, MIN_T - 24, B, 8);
    const mda = tdze + 365;
    cText(pg, `MDA(H) ${mda}'(365')`, midX + 55, MIN_T - 38, B, 9);

    vLine(pg, midX - 5, MIN_B + 22, MIN_T - 14, 0.3);

    // RAIL/ALS out labels
    hLine(pg, MIN_T - 44, M, PAGE_W - M, 0.3);
    cText(pg, 'RAIL/ALS out', midX - 65, MIN_T - 53, R, 5.5);
    cText(pg, 'RAIL/ALS out', midX + 55, MIN_T - 53, R, 5.5);
  }

  // Category headers and RVR grid
  const catLineY = MIN_B + 14;
  hLine(pg, catLineY, M, PAGE_W - M, 0.5);
  const cats = ['A', 'B', 'C', 'D'];
  const catW = w / 4;
  for (let i = 0; i < 4; i++) {
    cText(pg, cats[i], M + catW * i + catW / 2, MIN_B + 3, B, 7);
    if (i < 3) vLine(pg, M + catW * (i + 1), MIN_B, catLineY, 0.3);
  }

  // RVR values in category cells (between category line and RAIL/ALS)
  if (c.ils) {
    const rvrY = catLineY + 6;
    // ILS side: A & B share ILS minimums
    cText(pg, 'RVR 24 or \u00BD', M + catW * 0.5, rvrY, R, 4.5);
    cText(pg, 'RVR 40 or \u00BE', M + catW * 1.5, rvrY, R, 4.5);
    // LOC side: C & D
    cText(pg, 'RVR 50 or 1', M + catW * 2.5, rvrY, R, 4.5);
    cText(pg, 'RVR 55 or 1', M + catW * 3.5, rvrY, R, 4.5);
    // Extend dividers through RVR area
    for (let i = 0; i < 3; i++) vLine(pg, M + catW * (i + 1), catLineY, catLineY + 14, 0.3);
  }

}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function generateChart(airportId: string, approachId: number) {
  console.log(`Fetching chart data for ${airportId} approach ${approachId}...`);

  const [chartData, airportData] = await Promise.all([
    fetchJson<ChartData>(`${API_BASE}/cifp/${airportId}/chart-data/${approachId}`),
    fetchJson<AirportInfo>(`${API_BASE}/airports/${airportId}`),
  ]);

  // For ILS approaches, merge LOC legs to get step-down fixes
  if (chartData.approach.route_type === 'I') {
    const rwy = chartData.approach.runway_identifier;
    const approaches = await fetchJson<{ id: number; route_type: string; runway_identifier: string }[]>(
      `${API_BASE}/cifp/${airportId}/approaches`,
    );
    const locAppr = approaches.find(a => a.route_type === 'L' && a.runway_identifier === rwy);
    if (locAppr) {
      const locData = await fetchJson<ChartData>(`${API_BASE}/cifp/${airportId}/chart-data/${locAppr.id}`);
      // Find MAP index in both
      const ilsMapIdx = chartData.legs.findIndex(l => l.is_map);
      const locMapIdx = locData.legs.findIndex(l => l.is_map);
      const ilsAppLegs = ilsMapIdx >= 0 ? chartData.legs.slice(0, ilsMapIdx) : chartData.legs;
      const locAppLegs = locMapIdx >= 0 ? locData.legs.slice(0, locMapIdx) : locData.legs;
      const ilsFixIds = new Set(ilsAppLegs.map(l => l.fix_identifier).filter(Boolean));
      // Add LOC-only fixes that the ILS is missing
      const newLegs: Leg[] = [];
      for (const ll of locAppLegs) {
        if (ll.fix_identifier && !ilsFixIds.has(ll.fix_identifier)) {
          newLegs.push(ll);
        }
      }
      if (newLegs.length > 0) {
        // Insert new legs before the MAP, sorted by sequence number
        const beforeMap = chartData.legs.slice(0, ilsMapIdx >= 0 ? ilsMapIdx : chartData.legs.length);
        const afterMap = ilsMapIdx >= 0 ? chartData.legs.slice(ilsMapIdx) : [];
        const combined = [...beforeMap, ...newLegs].sort((a, b) => a.sequence_number - b.sequence_number);
        // Replace MAP leg with LOC version (has correct distance from last LOC fix)
        const locMapLeg = locMapIdx >= 0 ? locData.legs[locMapIdx] : null;
        if (locMapLeg && afterMap.length > 0) {
          afterMap[0] = { ...afterMap[0], route_distance_or_time: locMapLeg.route_distance_or_time };
        }
        chartData.legs = [...combined, ...afterMap];
        console.log(`  Merged ${newLegs.length} LOC fixes: ${newLegs.map(l => l.fix_identifier).join(', ')}`);
      }
    }
  }

  console.log(`  Procedure: ${chartData.approach.procedure_name}`);
  console.log(`  Airport: ${airportData.name} (${airportData.identifier})`);
  console.log(`  Legs: ${chartData.legs.length}`);

  const doc = await PDFDocument.create();
  const R = await doc.embedFont(StandardFonts.Helvetica);
  const B = await doc.embedFont(StandardFonts.HelveticaBold);

  const pg = doc.addPage([PAGE_W, PAGE_H]);
  pg.drawRectangle({ x: 0, y: 0, width: PAGE_W, height: PAGE_H, color: WHITE });

  renderHeader(pg, chartData, airportData, B, R);
  renderComm(pg, airportData, B, R);
  renderBriefing(pg, chartData, airportData, B, R);
  renderNotes(pg, chartData, B, R);
  renderMsa(pg, chartData, B, R);
  renderPlanView(pg, chartData, airportData, B, R);
  renderProfile(pg, chartData, B, R);
  renderMinimums(pg, chartData, B, R);

  const pdfBytes = await doc.save();
  const outName = `${airportData.identifier}_${chartData.approach.procedure_name.replace(/\s+/g, '_')}.pdf`;
  const outPath = path.join(__dirname, '..', 'output', outName);
  fs.writeFileSync(outPath, pdfBytes);
  console.log(`\nChart saved: ${outPath} (${(pdfBytes.length / 1024).toFixed(1)} KB)`);
}

const args = process.argv.slice(2);
if (args.length < 2) {
  console.log('Usage: npx ts-node src/generate.ts <airportId> <approachId>');
  process.exit(1);
}

generateChart(args[0], parseInt(args[1])).catch((err) => {
  console.error('Generation failed:', err.message);
  process.exit(1);
});
