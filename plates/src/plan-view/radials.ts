/**
 * Radial lines (dashed) connecting VORs through fixes,
 * with course labels.
 */
import { GeoProjection, RadialDef, Fix } from './types';

export function renderRadials(
  proj: GeoProjection,
  radials: RadialDef[],
  fixes: Fix[],
): string {
  const lines: string[] = [];
  lines.push(`<g id="plan-radials">`);

  for (const rad of radials) {
    const trueHdg = rad.radialMag + rad.magVar;

    // If the radial passes through a known fix, draw from VOR direction
    // through fix and beyond
    if (rad.throughFix) {
      const fix = fixes.find((f) => f.id === rad.throughFix);
      if (!fix) continue;

      const line = proj.lineFromHeading(fix.lat, fix.lon, trueHdg);

      // Trim line to not extend too far past the fix
      const fp = proj.project(fix.lat, fix.lon);
      // Extend ~80px past the fix in each direction
      const dx = line.x2 - line.x1;
      const dy = line.y2 - line.y1;
      const len = Math.sqrt(dx * dx + dy * dy);
      if (len < 1) continue;

      // Find parameter t for the fix position on the line
      const tFix = ((fp.x - line.x1) * dx + (fp.y - line.y1) * dy) / (len * len);

      // Draw from tFix - 120px to tFix + 120px (clamped to line)
      const extend = 120 / len;
      const t1 = Math.max(0, tFix - extend);
      const t2 = Math.min(1, tFix + extend);

      const x1 = line.x1 + dx * t1;
      const y1 = line.y1 + dy * t1;
      const x2 = line.x1 + dx * t2;
      const y2 = line.y1 + dy * t2;

      lines.push(
        `  <line x1="${x1.toFixed(1)}" y1="${y1.toFixed(1)}" ` +
        `x2="${x2.toFixed(1)}" y2="${y2.toFixed(1)}" ` +
        `stroke="#000" stroke-width="0.5" stroke-dasharray="5,3"/>`,
      );

      // Radial label along the line, offset from fix towards VOR
      const labelT = Math.max(0, tFix - extend * 0.6);
      const labelX = line.x1 + dx * labelT;
      const labelY = line.y1 + dy * labelT;

      // Rotate label to align with the line
      const angle = (Math.atan2(dy, dx) * 180) / Math.PI;
      // Keep text readable (not upside down)
      const textAngle = angle > 90 || angle < -90 ? angle + 180 : angle;

      lines.push(
        `  <text x="${labelX.toFixed(1)}" y="${(labelY - 3).toFixed(1)}" ` +
        `font-size="5.5" font-weight="400" ` +
        `transform="rotate(${textAngle.toFixed(1)},${labelX.toFixed(1)},${(labelY - 3).toFixed(1)})">${rad.label}</text>`,
      );
    } else {
      // Draw from VOR to chart edge
      const line = proj.lineFromHeading(rad.vorLat, rad.vorLon, trueHdg);
      lines.push(
        `  <line x1="${line.x1.toFixed(1)}" y1="${line.y1.toFixed(1)}" ` +
        `x2="${line.x2.toFixed(1)}" y2="${line.y2.toFixed(1)}" ` +
        `stroke="#000" stroke-width="0.5" stroke-dasharray="5,3"/>`,
      );
    }
  }

  lines.push(`</g>`);
  return lines.join('\n');
}
