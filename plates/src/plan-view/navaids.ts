/**
 * VOR / VORTAC symbols with compass rose, frequency, and label.
 * Handles both on-chart and off-chart (edge) VORs.
 */
import { GeoProjection, VORDef } from './types';

export function renderNavaids(proj: GeoProjection, vors: VORDef[]): string {
  const lines: string[] = [];
  lines.push(`<g id="plan-navaids">`);

  for (const vor of vors) {
    let p = proj.project(vor.lat, vor.lon);
    const W = proj.size.width;
    const H = proj.size.height;

    // Check if VOR is off-chart; if so, place at edge
    const onChart =
      p.x >= -10 && p.x <= W + 10 && p.y >= -10 && p.y <= H + 10;

    if (!onChart) {
      // Clamp to chart edge with margin
      p = {
        x: Math.max(20, Math.min(W - 20, p.x)),
        y: Math.max(20, Math.min(H - 20, p.y)),
      };
    }

    const r = 8; // hexagon radius

    lines.push(`  <g transform="translate(${p.x.toFixed(1)},${p.y.toFixed(1)})">`);

    // Hexagon (VOR symbol)
    const hex: string[] = [];
    for (let i = 0; i < 6; i++) {
      const a = ((i * 60 - 30) * Math.PI) / 180;
      hex.push(`${(r * Math.cos(a)).toFixed(1)},${(r * Math.sin(a)).toFixed(1)}`);
    }
    lines.push(`    <polygon points="${hex.join(' ')}" fill="none" stroke="#000" stroke-width="1.2"/>`);

    // Center dot
    lines.push(`    <circle cx="0" cy="0" r="1.5" fill="#000"/>`);

    // VORTAC: X through center
    if (vor.type === 'VORTAC') {
      lines.push(`    <line x1="-3.5" y1="-3.5" x2="3.5" y2="3.5" stroke="#000" stroke-width="0.8"/>`);
      lines.push(`    <line x1="3.5" y1="-3.5" x2="-3.5" y2="3.5" stroke="#000" stroke-width="0.8"/>`);
    }

    // Outer compass rose circle
    const cr = 12;
    lines.push(`    <circle cx="0" cy="0" r="${cr}" fill="none" stroke="#000" stroke-width="0.5"/>`);

    // Cardinal tick marks
    for (const a of [0, 90, 180, 270]) {
      const rad = (a * Math.PI) / 180;
      lines.push(
        `    <line x1="${(cr * Math.cos(rad)).toFixed(1)}" y1="${(cr * Math.sin(rad)).toFixed(1)}" ` +
        `x2="${((cr + 3) * Math.cos(rad)).toFixed(1)}" y2="${((cr + 3) * Math.sin(rad)).toFixed(1)}" ` +
        `stroke="#000" stroke-width="0.7"/>`,
      );
    }

    lines.push(`  </g>`);

    // Labels (offset to right of symbol)
    const lx = p.x + 17;
    lines.push(
      `  <text x="${lx.toFixed(1)}" y="${(p.y - 6).toFixed(1)}" font-size="7" font-weight="400">${vor.name}</text>`,
    );
    lines.push(
      `  <text x="${lx.toFixed(1)}" y="${(p.y + 2).toFixed(1)}" font-size="7.5" font-weight="700">` +
      `<tspan font-size="5" font-weight="400">${vor.class || ''} </tspan>${vor.freq} ${vor.id}</text>`,
    );
  }

  lines.push(`</g>`);
  return lines.join('\n');
}
