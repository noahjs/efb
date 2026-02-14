/**
 * Terrain elevation dots and contour-like arcs.
 */
import { GeoProjection, TerrainPoint } from './types';

export interface TerrainContour {
  /** Elevation label for this contour */
  elevation: number;
  /** Array of lat/lon points forming the contour arc */
  points: { lat: number; lon: number }[];
}

export function renderTerrain(
  proj: GeoProjection,
  points: TerrainPoint[],
  contours: TerrainContour[] = [],
): string {
  const lines: string[] = [];
  lines.push(`<g id="plan-terrain">`);

  // --- Elevation dots with labels ---
  for (const pt of points) {
    const p = proj.project(pt.lat, pt.lon);
    lines.push(`  <circle cx="${p.x.toFixed(1)}" cy="${p.y.toFixed(1)}" r="1.2" fill="#000"/>`);
    lines.push(
      `  <text x="${(p.x + 3).toFixed(1)}" y="${(p.y + 3).toFixed(1)}" font-size="5.5" font-weight="400">${pt.elevation}'</text>`,
    );
  }

  // --- Contour arcs (subtle, showing terrain rise to the west) ---
  for (const contour of contours) {
    if (contour.points.length < 2) continue;

    const svgPts = contour.points.map((cp) => proj.project(cp.lat, cp.lon));
    const pathParts = svgPts.map((p, i) =>
      i === 0 ? `M ${p.x.toFixed(1)},${p.y.toFixed(1)}` : `L ${p.x.toFixed(1)},${p.y.toFixed(1)}`,
    );

    lines.push(
      `  <path d="${pathParts.join(' ')}" fill="none" stroke="#000" stroke-width="0.4" stroke-dasharray="2,3"/>`,
    );

    // Contour label at the midpoint
    const midIdx = Math.floor(svgPts.length / 2);
    const mid = svgPts[midIdx];
    lines.push(
      `  <text x="${(mid.x - 10).toFixed(1)}" y="${(mid.y - 3).toFixed(1)}" font-size="5" font-weight="400">${contour.elevation}'</text>`,
    );
  }

  lines.push(`</g>`);
  return lines.join('\n');
}
