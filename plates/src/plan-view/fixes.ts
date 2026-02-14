/**
 * Fix triangles with labels (name, role, altitude, DME).
 */
import { GeoProjection, Fix } from './types';

export function renderFixes(proj: GeoProjection, fixes: Fix[]): string {
  const lines: string[] = [];
  lines.push(`<g id="plan-fixes">`);

  for (const fix of fixes) {
    const p = proj.project(fix.lat, fix.lon);

    // Skip runway threshold fixes (drawn by approach-course component)
    if (fix.id.startsWith('RW')) continue;

    // --- Triangle symbol ---
    const sz = 5;
    const h = sz * 0.866;
    lines.push(
      `  <polygon points="${p.x.toFixed(1)},${(p.y - h * 0.67).toFixed(1)} ` +
      `${(p.x - sz / 2).toFixed(1)},${(p.y + h * 0.33).toFixed(1)} ` +
      `${(p.x + sz / 2).toFixed(1)},${(p.y + h * 0.33).toFixed(1)}" ` +
      `fill="none" stroke="#000" stroke-width="1.8"/>`,
    );

    // --- Label block (offset to the right by default) ---
    let lx = p.x + 8;
    let ly = p.y - 2;

    // For fixes on the left side of chart, label to the right
    // For fixes that might overlap, alternate sides
    const labelLines: string[] = [];

    // Fix name (bold)
    labelLines.push(
      `  <text x="${lx.toFixed(1)}" y="${ly.toFixed(1)}" font-size="9" font-weight="700">${fix.id}</text>`,
    );

    // Role label (IAF, IF, FAF, etc.)
    if (fix.role && fix.role !== 'MAP') {
      ly += 9;
      labelLines.push(
        `  <text x="${lx.toFixed(1)}" y="${ly.toFixed(1)}" font-size="6" font-weight="600">(${fix.role})</text>`,
      );
    }

    // DME info
    if (fix.dme) {
      ly += 8;
      labelLines.push(
        `  <text x="${lx.toFixed(1)}" y="${ly.toFixed(1)}" font-size="6" font-weight="400">${fix.dme}</text>`,
      );
    }

    // RADAR FIX label
    if (fix.radarFix) {
      ly += 7;
      labelLines.push(
        `  <text x="${lx.toFixed(1)}" y="${ly.toFixed(1)}" font-size="5" font-weight="400">RADAR FIX</text>`,
      );
    }

    lines.push(...labelLines);
  }

  lines.push(`</g>`);
  return lines.join('\n');
}
