/**
 * Assembles all plan-view components into a complete SVG string
 * for the KAPA ILS or LOC Rwy 35R approach.
 *
 * Usage: npx ts-node src/plan-view/assemble.ts
 * Output: output/apa-ils35r-planview.svg
 */
import * as fs from 'fs';
import * as path from 'path';
import { GeoProjection, GeoExtent, SVGSize, Fix, VORDef, RadialDef, HoldDef, ILSInfo, TerrainPoint } from './types';
import { renderGrid } from './grid';
import { renderApproachCourse } from './approach-course';
import { renderIlsBox } from './ils-box';
import { renderFixes } from './fixes';
import { renderNavaids } from './navaids';
import { renderRadials } from './radials';
import { renderMissedApproach } from './missed-approach';
import { renderTerrain, TerrainContour } from './terrain';

// ═══════════════════════════════════════════════════════════════
// Chart data for KAPA ILS or LOC Rwy 35R
// ═══════════════════════════════════════════════════════════════

const EXTENT: GeoExtent = {
  south: 39.10,
  north: 39.617,
  west: -105.200,
  east: -104.467,
};

const SIZE: SVGSize = { width: 540, height: 360 };
const MAG_VAR = 8; // 8°E

// --- ILS ---
const ILS: ILSInfo = {
  locId: 'IAPA',
  freq: '111.3',
  course: 350,
  locLat: 39.587,
  locLon: -104.852,
};

// --- Fixes (ordered far-to-near along approach course) ---
const XBEEE: Fix = { id: 'XBEEE', lat: 39.279, lon: -104.838, dme: 'D18.5 IAPA' };
const FIRPI: Fix = { id: 'FIRPI', lat: 39.345, lon: -104.840, role: 'IF', dme: 'D14.2 IAPA', radarFix: true };
const JIDOG: Fix = { id: 'JIDOG', lat: 39.452, lon: -104.845, role: 'FAF', dme: 'D8.2 IAPA', radarFix: true };
const RONNI: Fix = { id: 'RONNI', lat: 39.500, lon: -104.848, dme: 'D5.5 IAPA' };
const LECET: Fix = { id: 'LECET', lat: 39.518, lon: -104.848, dme: 'D4.5 IAPA' };
const RW35R: Fix = { id: 'RW35R', lat: 39.557, lon: -104.850, role: 'MAP' };

const APPROACH_FIXES = [XBEEE, FIRPI, JIDOG, RONNI, LECET];

// --- Missed approach fix ---
const HOHUM: Fix = { id: 'HOHUM', lat: 39.359, lon: -104.848, role: 'MAHF', dme: 'D22.5 FQF' };

// --- VORs ---
// FQF (Falcon) computed from HOHUM position + R-197 bearing at D22.5
const FQF: VORDef = {
  id: 'FQF',
  name: 'FALCON',
  freq: '116.3',
  lat: 39.699,
  lon: -104.643,
  type: 'VORTAC',
  class: '(H)',
};

// BJC (Jeffco) — off chart to northwest
const BJC_LAT = 39.909;
const BJC_LON = -105.117;

// --- Radials ---
const RADIALS: RadialDef[] = [
  {
    vorId: 'BJC',
    vorLat: BJC_LAT,
    vorLon: BJC_LON,
    radialMag: 147,
    magVar: MAG_VAR,
    label: 'BJC R-147',
    throughFix: 'JIDOG',
  },
  {
    vorId: 'FQF',
    vorLat: FQF.lat,
    vorLon: FQF.lon,
    radialMag: 197,
    magVar: MAG_VAR,
    label: 'FQF R-197',
    throughFix: 'HOHUM',
  },
];

// --- Hold at HOHUM ---
const HOLD: HoldDef = {
  fixId: 'HOHUM',
  fixLat: HOHUM.lat,
  fixLon: HOHUM.lon,
  inboundCourseMag: 17, // inbound to FQF on R-197 reciprocal
  turnDirection: 'R',
  magVar: MAG_VAR,
};

// --- Terrain ---
const TERRAIN_POINTS: TerrainPoint[] = [
  { lat: 39.45, lon: -105.05, elevation: 7543 },
  { lat: 39.35, lon: -105.08, elevation: 8214 },
  { lat: 39.25, lon: -105.10, elevation: 9127 },
  { lat: 39.50, lon: -104.95, elevation: 6280 },
  { lat: 39.40, lon: -104.70, elevation: 6143 },
  { lat: 39.55, lon: -104.75, elevation: 5920 },
  { lat: 39.30, lon: -104.65, elevation: 6540 },
  { lat: 39.20, lon: -104.85, elevation: 7210 },
];

const TERRAIN_CONTOURS: TerrainContour[] = [
  {
    elevation: 7000,
    points: [
      { lat: 39.60, lon: -105.12 },
      { lat: 39.50, lon: -105.05 },
      { lat: 39.40, lon: -105.02 },
      { lat: 39.30, lon: -105.03 },
      { lat: 39.20, lon: -105.06 },
      { lat: 39.10, lon: -105.10 },
    ],
  },
  {
    elevation: 8000,
    points: [
      { lat: 39.55, lon: -105.15 },
      { lat: 39.45, lon: -105.10 },
      { lat: 39.35, lon: -105.10 },
      { lat: 39.25, lon: -105.12 },
      { lat: 39.15, lon: -105.15 },
    ],
  },
];

// ═══════════════════════════════════════════════════════════════
// Assembly
// ═══════════════════════════════════════════════════════════════

function assemblePlanView(): string {
  const proj = new GeoProjection(EXTENT, SIZE);

  const allFixes = [...APPROACH_FIXES, HOHUM];

  const components = [
    renderGrid(proj),
    renderTerrain(proj, TERRAIN_POINTS, TERRAIN_CONTOURS),
    renderApproachCourse(proj, {
      fixes: APPROACH_FIXES,
      mapFix: RW35R,
      ils: ILS,
      locLat: ILS.locLat,
      locLon: ILS.locLon,
      runwayLat: RW35R.lat,
      runwayLon: RW35R.lon,
      runwayBearingTrue: 350 + MAG_VAR, // 358° true
      courseMag: 350,
      magVar: MAG_VAR,
    }),
    renderIlsBox(proj, ILS),
    renderFixes(proj, APPROACH_FIXES),
    renderRadials(proj, RADIALS, allFixes),
    renderNavaids(proj, [FQF]),
    renderMissedApproach(proj, {
      mapFix: RW35R,
      hohum: HOHUM,
      turnHeadingMag: 160,
      magVar: MAG_VAR,
      hold: HOLD,
      // Turn begins roughly 2NM north of runway (climbing through 7400')
      turnLat: 39.590,
      turnLon: -104.852,
    }),
  ];

  const svg = [
    `<svg viewBox="0 0 ${SIZE.width} ${SIZE.height}" xmlns="http://www.w3.org/2000/svg">`,
    `  <rect x="0" y="0" width="${SIZE.width}" height="${SIZE.height}" fill="#fff"/>`,
    `  <style>`,
    `    svg text { font-family: Helvetica, 'Helvetica Neue', Arial, sans-serif; fill: #000; }`,
    `  </style>`,
    '',
    ...components.map((c) => '  ' + c.replace(/\n/g, '\n  ')),
    '',
    `  <!-- Scale bar -->`,
    `  <g transform="translate(20,340)">`,
    `    <line x1="0" y1="0" x2="${(proj.pxPerNm * 5).toFixed(1)}" y2="0" stroke="#000" stroke-width="1"/>`,
    `    <line x1="0" y1="-3" x2="0" y2="3" stroke="#000" stroke-width="0.5"/>`,
    `    <line x1="${(proj.pxPerNm * 5).toFixed(1)}" y1="-3" x2="${(proj.pxPerNm * 5).toFixed(1)}" y2="3" stroke="#000" stroke-width="0.5"/>`,
    `    <text x="${(proj.pxPerNm * 2.5).toFixed(1)}" y="-4" text-anchor="middle" font-size="5" font-weight="400">5 NM</text>`,
    `  </g>`,
    '',
    `</svg>`,
  ];

  return svg.join('\n');
}

// ═══════════════════════════════════════════════════════════════
// CLI entry point
// ═══════════════════════════════════════════════════════════════

const svgContent = assemblePlanView();
const outDir = path.join(__dirname, '..', '..', 'output');
if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

const outPath = path.join(outDir, 'apa-ils35r-planview.svg');
fs.writeFileSync(outPath, svgContent);
console.log(`Plan view SVG written to: ${outPath}`);
console.log(`Size: ${(Buffer.byteLength(svgContent) / 1024).toFixed(1)} KB`);

// Also export for use in HTML assembly
export { assemblePlanView };
