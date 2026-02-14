/**
 * Missed approach path (dashed), heading label, and holding pattern.
 */
import { GeoProjection, Fix, HoldDef } from './types';

export interface MissedApproachOpts {
  mapFix: Fix;                 // missed approach point (runway threshold)
  hohum: Fix;                  // holding fix
  turnHeadingMag: number;      // heading after turn (e.g. 160)
  magVar: number;
  hold: HoldDef;
  /** Intermediate point where the turn begins (approximate) */
  turnLat: number;
  turnLon: number;
}

export function renderMissedApproach(
  proj: GeoProjection,
  opts: MissedApproachOpts,
): string {
  const lines: string[] = [];
  lines.push(`<g id="plan-missed-approach">`);

  const map = proj.project(opts.mapFix.lat, opts.mapFix.lon);
  const turn = proj.project(opts.turnLat, opts.turnLon);
  const hohum = proj.project(opts.hohum.lat, opts.hohum.lon);

  // --- Dashed path: MAP → turn point → HOHUM ---
  // Segment 1: straight ahead from MAP (runway heading, northward)
  lines.push(
    `  <line x1="${map.x.toFixed(1)}" y1="${map.y.toFixed(1)}" ` +
    `x2="${turn.x.toFixed(1)}" y2="${turn.y.toFixed(1)}" ` +
    `stroke="#000" stroke-width="1.5" stroke-dasharray="8,5"/>`,
  );

  // Segment 2: curved turn indication → heading 160°
  // Draw a small arc to suggest the right turn, then straight to HOHUM
  // For simplicity, use a quadratic bezier for the turn
  const midTurnX = turn.x + 15; // right turn bias
  const midTurnY = turn.y + 20;

  // Segment 3: from turn area to HOHUM along heading 160° / R-197
  lines.push(
    `  <path d="M ${turn.x.toFixed(1)},${turn.y.toFixed(1)} ` +
    `Q ${midTurnX.toFixed(1)},${midTurnY.toFixed(1)} ${hohum.x.toFixed(1)},${hohum.y.toFixed(1)}" ` +
    `fill="none" stroke="#000" stroke-width="1.5" stroke-dasharray="8,5"/>`,
  );

  // --- Heading label on the missed approach path ---
  const hdgLabelX = (turn.x + hohum.x) / 2 + 12;
  const hdgLabelY = (turn.y + hohum.y) / 2;
  lines.push(
    `  <rect x="${(hdgLabelX - 2).toFixed(1)}" y="${(hdgLabelY - 8).toFixed(1)}" width="32" height="18" fill="#fff"/>`,
  );
  lines.push(
    `  <text x="${hdgLabelX.toFixed(1)}" y="${(hdgLabelY + 1).toFixed(1)}" font-size="9" font-weight="700">${opts.turnHeadingMag}&deg;</text>`,
  );
  lines.push(
    `  <text x="${(hdgLabelX + 22).toFixed(1)}" y="${(hdgLabelY - 3).toFixed(1)}" font-size="5" font-weight="400">on</text>`,
  );
  lines.push(
    `  <text x="${(hdgLabelX + 22).toFixed(1)}" y="${(hdgLabelY + 5).toFixed(1)}" font-size="5" font-weight="400">hdg</text>`,
  );

  // --- Right turn symbol near the turn point ---
  lines.push(
    `  <use href="#sym-right-turn" x="${(turn.x + 6).toFixed(1)}" y="${(turn.y - 2).toFixed(1)}" width="16" height="14"/>`,
  );

  // --- Holding pattern at HOHUM ---
  renderHoldPattern(proj, opts.hold, lines);

  // --- HOHUM label ---
  lines.push(
    `  <text x="${(hohum.x + 10).toFixed(1)}" y="${(hohum.y - 2).toFixed(1)}" font-size="9" font-weight="700">${opts.hohum.id}</text>`,
  );
  if (opts.hohum.dme) {
    lines.push(
      `  <text x="${(hohum.x + 10).toFixed(1)}" y="${(hohum.y + 8).toFixed(1)}" font-size="6" font-weight="400">${opts.hohum.dme}</text>`,
    );
  }
  lines.push(
    `  <text x="${(hohum.x + 10).toFixed(1)}" y="${(hohum.y + 16).toFixed(1)}" font-size="5" font-weight="400">MISSED APCH FIX</text>`,
  );

  // --- HOHUM fix triangle ---
  const sz = 5;
  const h = sz * 0.866;
  lines.push(
    `  <polygon points="${hohum.x.toFixed(1)},${(hohum.y - h * 0.67).toFixed(1)} ` +
    `${(hohum.x - sz / 2).toFixed(1)},${(hohum.y + h * 0.33).toFixed(1)} ` +
    `${(hohum.x + sz / 2).toFixed(1)},${(hohum.y + h * 0.33).toFixed(1)}" ` +
    `fill="none" stroke="#000" stroke-width="1.8"/>`,
  );

  lines.push(`</g>`);
  return lines.join('\n');
}

function renderHoldPattern(
  proj: GeoProjection,
  hold: HoldDef,
  lines: string[],
): void {
  const fp = proj.project(hold.fixLat, hold.fixLon);

  // Inbound course direction in SVG
  const inboundTrue = hold.inboundCourseMag + hold.magVar;
  const inbRad = (inboundTrue * Math.PI) / 180;

  // Inbound leg direction (SVG coordinates)
  // Heading to SVG: dx = sin(hdg), dy_svg = -cos(hdg) but SVG y is flipped
  // We need to account for the geo projection's aspect ratio
  const W = proj.size.width;
  const H = proj.size.height;
  const lonRange = proj.extent.east - proj.extent.west;
  const latRange = proj.extent.north - proj.extent.south;

  // Direction vector in SVG pixels for the inbound course
  const dxGeo = Math.sin(inbRad);
  const dyGeo = -Math.cos(inbRad); // positive = south in geo
  const dx = (dxGeo / lonRange) * W;
  const dy = -(dyGeo / latRange) * H; // geo south = SVG +y
  const dLen = Math.sqrt(dx * dx + dy * dy);
  const ndx = dx / dLen;
  const ndy = dy / dLen;

  // Hold dimensions
  const legLen = 28; // inbound leg length in pixels
  const trackW = 14; // width between parallel legs

  // Perpendicular direction (right turn = perpendicular to the right)
  const right = hold.turnDirection === 'R' ? 1 : -1;
  const pnx = -ndy * right;
  const pny = ndx * right;

  // Four corners of the racetrack
  // Fix is at the inbound end; outbound end is along the inbound course direction
  const outEnd = { x: fp.x + ndx * legLen, y: fp.y + ndy * legLen };
  const outEndOffset = {
    x: outEnd.x + pnx * trackW,
    y: outEnd.y + pny * trackW,
  };
  const fixOffset = {
    x: fp.x + pnx * trackW,
    y: fp.y + pny * trackW,
  };

  // Draw the racetrack as dashed lines + arcs
  // Inbound leg (fix to outbound end)
  lines.push(
    `  <line x1="${fp.x.toFixed(1)}" y1="${fp.y.toFixed(1)}" ` +
    `x2="${outEnd.x.toFixed(1)}" y2="${outEnd.y.toFixed(1)}" ` +
    `stroke="#000" stroke-width="0.9" stroke-dasharray="5,3"/>`,
  );

  // Outbound leg (parallel, offset)
  lines.push(
    `  <line x1="${fixOffset.x.toFixed(1)}" y1="${fixOffset.y.toFixed(1)}" ` +
    `x2="${outEndOffset.x.toFixed(1)}" y2="${outEndOffset.y.toFixed(1)}" ` +
    `stroke="#000" stroke-width="0.9" stroke-dasharray="5,3"/>`,
  );

  // Semi-circular arcs at each end
  const arcR = trackW / 2;
  // Arc at the fix end (connecting outbound return to inbound start)
  const fixArcCenter = {
    x: (fp.x + fixOffset.x) / 2,
    y: (fp.y + fixOffset.y) / 2,
  };
  // Arc at the outbound end
  const outArcCenter = {
    x: (outEnd.x + outEndOffset.x) / 2,
    y: (outEnd.y + outEndOffset.y) / 2,
  };

  // Use SVG arc paths
  // Sweep flag depends on turn direction
  const sweep = hold.turnDirection === 'R' ? 1 : 0;

  // Arc at fix end: from fixOffset to fix
  lines.push(
    `  <path d="M ${fixOffset.x.toFixed(1)},${fixOffset.y.toFixed(1)} ` +
    `A ${arcR.toFixed(1)},${arcR.toFixed(1)} 0 0,${sweep} ` +
    `${fp.x.toFixed(1)},${fp.y.toFixed(1)}" ` +
    `fill="none" stroke="#000" stroke-width="0.9" stroke-dasharray="5,3"/>`,
  );

  // Arc at outbound end: from outEnd to outEndOffset
  lines.push(
    `  <path d="M ${outEnd.x.toFixed(1)},${outEnd.y.toFixed(1)} ` +
    `A ${arcR.toFixed(1)},${arcR.toFixed(1)} 0 0,${sweep} ` +
    `${outEndOffset.x.toFixed(1)},${outEndOffset.y.toFixed(1)}" ` +
    `fill="none" stroke="#000" stroke-width="0.9" stroke-dasharray="5,3"/>`,
  );

  // Entry arrow on inbound leg (small arrowhead near the fix)
  const arrowX = fp.x + ndx * 8;
  const arrowY = fp.y + ndy * 8;
  const arrowSize = 3;
  // Arrowhead pointing towards fix (inbound direction = opposite of ndx/ndy)
  lines.push(
    `  <polygon points="${fp.x.toFixed(1)},${fp.y.toFixed(1)} ` +
    `${(arrowX + pnx * arrowSize).toFixed(1)},${(arrowY + pny * arrowSize).toFixed(1)} ` +
    `${(arrowX - pnx * arrowSize).toFixed(1)},${(arrowY - pny * arrowSize).toFixed(1)}" ` +
    `fill="#000"/>`,
  );
}
