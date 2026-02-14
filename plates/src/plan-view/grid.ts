/**
 * Lat/lon grid lines with tick marks and labels.
 */
import { GeoProjection } from './types';

function fmtDegMin(dd: number): string {
  const a = Math.abs(dd);
  const d = Math.floor(a + 0.0001);
  const m = Math.round((a - d) * 60);
  return m >= 60 ? `${d + 1}-00` : `${d}-${String(m).padStart(2, '0')}`;
}

export function renderGrid(proj: GeoProjection): string {
  const { extent, size } = proj;
  const W = size.width;
  const H = size.height;
  const step = 10 / 60; // 10-minute grid
  const lines: string[] = [];

  lines.push(`<g id="plan-grid">`);

  // --- Latitude lines (horizontal) ---
  for (
    let lat = Math.ceil(extent.south / step) * step;
    lat <= extent.north;
    lat += step
  ) {
    const { y } = proj.project(lat, extent.west);
    if (y < 8 || y > H - 8) continue;

    // Subtle grid line
    lines.push(
      `  <line x1="2" y1="${y.toFixed(1)}" x2="${W - 2}" y2="${y.toFixed(1)}" stroke="#000" stroke-width="0.12"/>`,
    );
    // Tick on left border
    lines.push(
      `  <line x1="1" y1="${y.toFixed(1)}" x2="5" y2="${y.toFixed(1)}" stroke="#000" stroke-width="0.5"/>`,
    );
    // Label
    lines.push(
      `  <text x="7" y="${(y - 2).toFixed(1)}" font-size="5" font-weight="400">${fmtDegMin(lat)}</text>`,
    );
  }

  // --- Longitude lines (vertical) ---
  for (
    let lon = Math.ceil(extent.west / step) * step;
    lon <= extent.east;
    lon += step
  ) {
    const { x } = proj.project(extent.north, lon);
    if (x < 8 || x > W - 8) continue;

    lines.push(
      `  <line x1="${x.toFixed(1)}" y1="2" x2="${x.toFixed(1)}" y2="${H - 2}" stroke="#000" stroke-width="0.12"/>`,
    );
    // Tick on bottom border
    lines.push(
      `  <line x1="${x.toFixed(1)}" y1="${H - 4}" x2="${x.toFixed(1)}" y2="${H}" stroke="#000" stroke-width="0.5"/>`,
    );
    // Label at bottom
    lines.push(
      `  <text x="${(x - 8).toFixed(1)}" y="${H - 5}" font-size="5" font-weight="400">${fmtDegMin(Math.abs(lon))}</text>`,
    );
  }

  lines.push(`</g>`);
  return lines.join('\n');
}
