import {
  BriefingAdvisory,
  BriefingWaypoint,
  AffectedSegment,
} from '../interfaces/briefing-response.interface';
import {
  haversineNm,
  isPointInCorridor,
  pointInPolygon,
} from './route-corridor.util';
import { BRIEFING } from '../../config/constants';

/**
 * Parse an altitude string to feet MSL.
 * Handles: "FL180" → 18000, "SFC"/"GND" → 0, "18000" → 18000, null → null.
 */
export function parseAltitudeToFeet(altStr: string | null): number | null {
  if (altStr == null) return null;
  const s = altStr.trim().toUpperCase();
  if (!s) return null;
  if (s === 'SFC' || s === 'GND' || s === 'SURFACE') return 0;
  const flMatch = s.match(/^FL\s*(\d+)$/);
  if (flMatch) return parseInt(flMatch[1], 10) * 100;
  const num = parseInt(s, 10);
  return isNaN(num) ? null : num;
}

/**
 * Determine the altitude relation of a cruise altitude to an advisory band.
 */
export function getAltitudeRelation(
  cruiseAlt: number,
  baseStr: string | null,
  topStr: string | null,
): 'within' | 'above' | 'below' | null {
  const baseFt = parseAltitudeToFeet(baseStr);
  const topFt = parseAltitudeToFeet(topStr);
  if (baseFt == null && topFt == null) return null;

  const effectiveBase = baseFt ?? 0;
  const effectiveTop = topFt ?? 60000;

  if (cruiseAlt >= effectiveBase && cruiseAlt <= effectiveTop) return 'within';
  if (cruiseAlt > effectiveTop) return 'above';
  return 'below';
}

/**
 * Find the route segment(s) affected by an advisory's geometry.
 */
export function findAffectedSegment(
  geometry: any,
  waypoints: BriefingWaypoint[],
  corridorNm: number,
): AffectedSegment | null {
  if (!geometry || waypoints.length < 2) return null;

  const rings = extractRings(geometry);
  if (rings.length === 0) return null;

  let firstMatchIdx: number | null = null;
  let lastMatchIdx: number | null = null;

  for (let i = 0; i < waypoints.length; i++) {
    const wp = waypoints[i];
    let wpAffected = false;

    // Check if this waypoint falls inside any polygon ring
    for (const ring of rings) {
      if (pointInPolygon(wp.latitude, wp.longitude, ring)) {
        wpAffected = true;
        break;
      }
    }

    // Check if any polygon vertex is near this waypoint (within corridor)
    if (!wpAffected) {
      for (const ring of rings) {
        for (const coord of ring) {
          const dist = haversineNm(
            wp.latitude,
            wp.longitude,
            coord[1],
            coord[0],
          );
          if (dist <= corridorNm) {
            wpAffected = true;
            break;
          }
        }
        if (wpAffected) break;
      }
    }

    if (wpAffected) {
      if (firstMatchIdx == null) firstMatchIdx = i;
      lastMatchIdx = i;
    }
  }

  if (firstMatchIdx == null || lastMatchIdx == null) return null;

  // Expand to include neighboring waypoints for better context
  const fromIdx = Math.max(0, firstMatchIdx - 1);
  const toIdx = Math.min(waypoints.length - 1, lastMatchIdx + 1);

  return {
    fromWaypoint: waypoints[fromIdx].identifier,
    toWaypoint: waypoints[toIdx].identifier,
    fromDistNm: waypoints[fromIdx].distanceFromDep,
    toDistNm: waypoints[toIdx].distanceFromDep,
    fromEtaMin: waypoints[fromIdx].etaMinutes,
    toEtaMin: waypoints[toIdx].etaMinutes,
  };
}

/**
 * Build a plain-English description of an advisory's impact on the route.
 */
export function buildPlainEnglish(
  advisory: BriefingAdvisory,
  segment: AffectedSegment | null,
  altRelation: 'within' | 'above' | 'below' | null,
): string {
  const parts: string[] = [];

  // Hazard type + severity
  const severity = advisory.severity ? `${advisory.severity} ` : '';
  parts.push(`${severity}${advisory.hazardType}`.trim());

  // Altitude band
  if (advisory.base || advisory.top) {
    const base = advisory.base || 'SFC';
    const top = advisory.top || '';
    if (top) {
      parts.push(`${base}-${top}`);
    } else {
      parts.push(`from ${base}`);
    }
  }

  // Route segment
  if (segment) {
    if (segment.fromWaypoint === segment.toWaypoint) {
      parts.push(`near ${segment.fromWaypoint}`);
    } else {
      parts.push(`between ${segment.fromWaypoint} and ${segment.toWaypoint}`);
    }
  }

  // Altitude relation
  if (altRelation) {
    parts.push(`\u2014 your altitude is ${altRelation}`);
  }

  return parts.join(' ');
}

/**
 * Contextualize a list of advisories with route segment, altitude relation, and plain English.
 */
export function contextualizeAdvisories(
  advisories: BriefingAdvisory[],
  waypoints: BriefingWaypoint[],
  cruiseAlt: number | null,
  corridorNm = BRIEFING.ROUTE_CORRIDOR_NM,
): void {
  for (const advisory of advisories) {
    advisory.baseFt = parseAltitudeToFeet(advisory.base);
    advisory.topFt = parseAltitudeToFeet(advisory.top);

    advisory.altitudeRelation =
      cruiseAlt != null
        ? getAltitudeRelation(cruiseAlt, advisory.base, advisory.top)
        : null;

    advisory.affectedSegment = findAffectedSegment(
      advisory.geometry,
      waypoints,
      corridorNm,
    );

    advisory.plainEnglish = buildPlainEnglish(
      advisory,
      advisory.affectedSegment,
      advisory.altitudeRelation,
    );
  }
}

/**
 * Determine the phase-aware altitude relation at a specific point along the route.
 * Returns 'climbing_through' / 'descending_through' when the aircraft is in climb/descent
 * and its estimated altitude falls within the hazard band.
 */
export function getPhaseAwareAltitudeRelation(
  estimatedAltFt: number,
  phase: 'climb' | 'cruise' | 'descent',
  baseStr: string | null,
  topStr: string | null,
): string | null {
  const baseFt = parseAltitudeToFeet(baseStr);
  const topFt = parseAltitudeToFeet(topStr);
  if (baseFt == null && topFt == null) return null;

  const effectiveBase = baseFt ?? 0;
  const effectiveTop = topFt ?? 60000;

  if (estimatedAltFt >= effectiveBase && estimatedAltFt <= effectiveTop) {
    if (phase === 'climb') return 'climbing_through';
    if (phase === 'descent') return 'descending_through';
    return 'within';
  }
  if (estimatedAltFt > effectiveTop) return 'above';
  return 'below';
}

export function extractRings(geometry: any): number[][][] {
  if (!geometry || !geometry.type) return [];
  if (geometry.type === 'Polygon') return geometry.coordinates || [];
  if (geometry.type === 'MultiPolygon') {
    const rings: number[][][] = [];
    for (const poly of geometry.coordinates || []) {
      for (const ring of poly) {
        rings.push(ring);
      }
    }
    return rings;
  }
  return [];
}
