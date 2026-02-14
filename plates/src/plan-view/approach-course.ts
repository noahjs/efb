/**
 * Approach course: thick line, localizer feather, runway bar,
 * FAF maltese cross, and large course label.
 */
import { GeoProjection, Fix, ILSInfo } from './types';

export interface ApproachCourseOpts {
  fixes: Fix[];            // ordered from first approach fix to last (before MAP)
  mapFix: Fix;             // MAP fix (runway threshold)
  ils: ILSInfo;
  locLat: number;
  locLon: number;
  runwayLat: number;
  runwayLon: number;
  runwayBearingTrue: number;
  courseMag: number;       // e.g. 350
  magVar: number;          // east positive
}

export function renderApproachCourse(
  proj: GeoProjection,
  opts: ApproachCourseOpts,
): string {
  const lines: string[] = [];
  lines.push(`<g id="plan-approach-course">`);

  const courseTrue = opts.courseMag + opts.magVar;
  const rwy = proj.project(opts.runwayLat, opts.runwayLon);
  const loc = proj.project(opts.locLat, opts.locLon);

  // --- Approach course line: from farthest fix through all fixes to localizer ---
  // Collect all points along the approach course (south to north)
  const coursePts = [
    ...opts.fixes.map((f) => proj.project(f.lat, f.lon)),
    proj.project(opts.mapFix.lat, opts.mapFix.lon),
    loc,
  ];

  // Extend the line south of the farthest fix
  const farthest = proj.project(opts.fixes[0].lat, opts.fixes[0].lon);
  const second = proj.project(opts.fixes[1]?.lat ?? opts.mapFix.lat, opts.fixes[1]?.lon ?? opts.mapFix.lon);
  const extDx = farthest.x - second.x;
  const extDy = farthest.y - second.y;
  const extLen = Math.sqrt(extDx * extDx + extDy * extDy);
  if (extLen > 0) {
    const extX = farthest.x + (extDx / extLen) * 40;
    const extY = farthest.y + (extDy / extLen) * 40;
    coursePts.unshift({ x: extX, y: extY });
  }

  // Draw as one thick polyline
  const ptsStr = coursePts.map((p) => `${p.x.toFixed(1)},${p.y.toFixed(1)}`).join(' ');
  lines.push(
    `  <polyline points="${ptsStr}" fill="none" stroke="#000" stroke-width="3.5"/>`,
  );

  // --- Course label (large, centered on approach course) ---
  // Place between JIDOG area and RONNI area (midpoint of approach)
  const midIdx = Math.floor(opts.fixes.length / 2);
  const midFix = opts.fixes[midIdx];
  const mid = proj.project(midFix.lat, midFix.lon);
  // White background box
  lines.push(
    `  <rect x="${(mid.x - 26).toFixed(1)}" y="${(mid.y - 18).toFixed(1)}" width="52" height="16" fill="#fff"/>`,
  );
  lines.push(
    `  <text x="${mid.x.toFixed(1)}" y="${(mid.y - 5).toFixed(1)}" text-anchor="middle" font-size="14" font-weight="700">${opts.courseMag}&deg;</text>`,
  );

  // --- Localizer feather (wide crossbar with tick marks) ---
  const bearRad = (opts.runwayBearingTrue * Math.PI) / 180;
  // Perpendicular to runway bearing
  const featherLen = 22;
  // In SVG, perpendicular to the approach course
  // Approach direction: from south to north ≈ nearly vertical
  // Compute actual perpendicular from course bearing
  const cRad = (courseTrue * Math.PI) / 180;
  const perpDxNorm = Math.cos(cRad); // perpendicular in normalized geo
  const perpDyNorm = Math.sin(cRad);
  // Convert to SVG pixels
  const perpDx = (perpDxNorm / (proj.extent.east - proj.extent.west)) * proj.size.width;
  const perpDy = (perpDyNorm / (proj.extent.north - proj.extent.south)) * proj.size.height;
  const perpLen = Math.sqrt(perpDx * perpDx + perpDy * perpDy);
  const pnx = perpDx / perpLen;
  const pny = perpDy / perpLen;

  // Main crossbar
  lines.push(
    `  <line x1="${(loc.x - pnx * featherLen).toFixed(1)}" y1="${(loc.y - pny * featherLen).toFixed(1)}" ` +
    `x2="${(loc.x + pnx * featherLen).toFixed(1)}" y2="${(loc.y + pny * featherLen).toFixed(1)}" ` +
    `stroke="#000" stroke-width="2.5"/>`,
  );

  // Tick marks (3 each side, inward-facing)
  const courseDx = (Math.sin(cRad) / (proj.extent.east - proj.extent.west)) * proj.size.width;
  const courseDy = -(Math.cos(cRad) / (proj.extent.north - proj.extent.south)) * proj.size.height;
  const cLen = Math.sqrt(courseDx * courseDx + courseDy * courseDy);
  const cnx = courseDx / cLen;
  const cny = courseDy / cLen;

  for (const t of [-1.0, -0.7, -0.4, 0.4, 0.7, 1.0]) {
    const bx = loc.x + pnx * featherLen * t;
    const by = loc.y + pny * featherLen * t;
    // Tick points inward (towards runway = opposite of course heading)
    lines.push(
      `  <line x1="${bx.toFixed(1)}" y1="${by.toFixed(1)}" ` +
      `x2="${(bx - cnx * 5).toFixed(1)}" y2="${(by - cny * 5).toFixed(1)}" ` +
      `stroke="#000" stroke-width="1.2"/>`,
    );
  }

  // --- Runway bar (thick filled rectangle) ---
  const rwyLen = 20;
  const rwyW = 5;
  lines.push(
    `  <rect x="${(rwy.x - rwyW / 2).toFixed(1)}" y="${(rwy.y - 2).toFixed(1)}" ` +
    `width="${rwyW}" height="${rwyLen}" fill="#000" ` +
    `transform="rotate(${(courseTrue - 180).toFixed(1)},${rwy.x.toFixed(1)},${(rwy.y + rwyLen / 2 - 2).toFixed(1)})"/>`,
  );

  // --- FAF Maltese Cross ---
  const fafFix = opts.fixes.find((f) => f.role === 'FAF');
  if (fafFix) {
    const faf = proj.project(fafFix.lat, fafFix.lon);
    lines.push(`  <g transform="translate(${faf.x.toFixed(1)},${faf.y.toFixed(1)})">`);
    lines.push(`    <line x1="-5" y1="0" x2="5" y2="0" stroke="#000" stroke-width="3"/>`);
    lines.push(`    <line x1="0" y1="-5" x2="0" y2="5" stroke="#000" stroke-width="3"/>`);
    lines.push(`    <line x1="-5" y1="-2" x2="-5" y2="2" stroke="#000" stroke-width="1.5"/>`);
    lines.push(`    <line x1="5" y1="-2" x2="5" y2="2" stroke="#000" stroke-width="1.5"/>`);
    lines.push(`    <line x1="-2" y1="-5" x2="2" y2="-5" stroke="#000" stroke-width="1.5"/>`);
    lines.push(`    <line x1="-2" y1="5" x2="2" y2="5" stroke="#000" stroke-width="1.5"/>`);
    lines.push(`  </g>`);
  }

  lines.push(`</g>`);
  return lines.join('\n');
}
