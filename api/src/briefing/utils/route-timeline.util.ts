import {
  BriefingResponse,
  BriefingWaypoint,
  BriefingMetar,
  BriefingAdvisory,
  TafForecastPeriod,
  TimelinePoint,
  TimelineHazard,
  WindsAloftTable,
  FlightPhaseProfile,
} from '../interfaces/briefing-response.interface';
import { haversineNm, pointInPolygon } from './route-corridor.util';
import {
  getPhaseAwareAltitudeRelation,
  extractRings,
} from './advisory-context.util';
import { BRIEFING } from '../../config/constants';

const DEG_TO_RAD = Math.PI / 180;

/**
 * Estimate flight phase and altitude at a given distance along the route.
 * Returns null if no phase profile is available (graceful fallback).
 */
export function estimatePhaseAndAltitude(
  distNm: number,
  profile: FlightPhaseProfile | null,
): { phase: 'climb' | 'cruise' | 'descent'; estimatedAltitudeFt: number } | null {
  if (!profile) return null;

  // Round boundaries to match rounded waypoint distances, so TOC → cruise, TOD → descent
  const tocDist = Math.round(profile.tocDistanceNm);
  const todDist = Math.round(profile.todDistanceNm);

  if (distNm < tocDist) {
    // Climb phase: linear interpolation from departure elevation to cruise
    const fraction =
      profile.tocDistanceNm > 0 ? distNm / profile.tocDistanceNm : 1;
    const alt =
      profile.departureElevationFt +
      fraction * (profile.cruiseAltitudeFt - profile.departureElevationFt);
    return { phase: 'climb', estimatedAltitudeFt: Math.round(alt) };
  }

  if (distNm >= todDist) {
    // Descent phase: linear interpolation from cruise to destination elevation
    const descentDist = profile.totalDistanceNm - profile.todDistanceNm;
    const fraction =
      descentDist > 0
        ? (distNm - profile.todDistanceNm) / descentDist
        : 1;
    const alt =
      profile.cruiseAltitudeFt +
      fraction * (profile.destinationElevationFt - profile.cruiseAltitudeFt);
    return { phase: 'descent', estimatedAltitudeFt: Math.round(alt) };
  }

  // Cruise phase (includes TOC point itself)
  return { phase: 'cruise', estimatedAltitudeFt: profile.cruiseAltitudeFt };
}

/**
 * Build a route timeline with weather, winds, and hazards at each sampled waypoint.
 * Pure function.
 */
export function buildRouteTimeline(
  response: BriefingResponse,
  etdIso: string | null,
): TimelinePoint[] {
  const waypoints = response.flight.waypoints;
  if (waypoints.length === 0) return [];

  // Sample ~8-10 waypoints (always include dep + dest)
  let sampled = sampleWaypoints(waypoints, 10);
  const metars = response.currentWeather.metars;
  const tafs = response.forecasts.tafs;
  const windsTable = response.forecasts.windsAloftTable;
  const cruiseAlt = response.flight.cruiseAltitude;
  const phaseProfile = response.flight.phaseProfile || null;

  // Inject synthetic TOC/TOD waypoints if phase profile available
  if (phaseProfile) {
    sampled = injectPhaseWaypoints(sampled, waypoints, phaseProfile);
  }

  // Collect all advisories and pre-compute precise route overlaps
  const allAdvisories = collectAdvisories(response);
  const advisoryOverlaps = computeAdvisoryOverlaps(
    allAdvisories,
    waypoints,
    BRIEFING.HAZARD_SAMPLE_INTERVAL_NM ?? 50,
  );

  return sampled.map((wp, idx) => {
    // Compute ETA in Zulu
    const etaZulu = computeEtaZulu(etdIso, wp.etaMinutes);

    // Estimate flight phase and altitude at this waypoint
    const phaseInfo = estimatePhaseAndAltitude(wp.distanceFromDep, phaseProfile);

    // Find nearest METAR station
    const nearestMetar = findNearestMetar(wp, metars);

    // Find nearest TAF and match forecast period to ETA
    const forecastAtEta = findForecastAtEta(wp, tafs, etaZulu);

    // Compute wind components from winds aloft table
    const { headwind, crosswind } = computeWindComponents(
      wp,
      idx,
      sampled,
      windsTable,
      cruiseAlt,
    );

    // Find active hazards at this point using precise geometry overlaps
    const activeHazards = findActiveHazards(wp, advisoryOverlaps, phaseInfo, phaseProfile);

    return {
      waypoint: wp.identifier,
      latitude: wp.latitude,
      longitude: wp.longitude,
      distanceFromDep: wp.distanceFromDep,
      etaMinutes: wp.etaMinutes,
      etaZulu,
      flightPhase: phaseInfo?.phase || null,
      estimatedAltitudeFt: phaseInfo?.estimatedAltitudeFt ?? null,
      nearestStation: nearestMetar?.icaoId || null,
      flightCategory: nearestMetar?.flightCategory || null,
      ceiling: nearestMetar?.ceiling ?? null,
      visibility: nearestMetar?.visib ?? null,
      windDir: nearestMetar?.wdir ?? null,
      windSpd: nearestMetar?.wspd ?? null,
      forecastAtEta,
      headwindComponent: headwind,
      crosswindComponent: crosswind,
      activeHazards,
    };
  });
}

function sampleWaypoints(
  waypoints: BriefingWaypoint[],
  maxCount: number,
): BriefingWaypoint[] {
  if (waypoints.length <= maxCount) return waypoints;

  const result: BriefingWaypoint[] = [waypoints[0]];
  const step = (waypoints.length - 1) / (maxCount - 1);
  for (let i = 1; i < maxCount - 1; i++) {
    result.push(waypoints[Math.round(i * step)]);
  }
  result.push(waypoints[waypoints.length - 1]);
  return result;
}

/**
 * Inject synthetic TOC and TOD waypoints into the sampled list.
 * Interpolates lat/lng/eta from the full waypoint list.
 * Skips if TOC/TOD would be too close to an existing waypoint (<5nm).
 */
function injectPhaseWaypoints(
  sampled: BriefingWaypoint[],
  allWaypoints: BriefingWaypoint[],
  profile: FlightPhaseProfile,
): BriefingWaypoint[] {
  const totalDist = profile.totalDistanceNm;
  if (totalDist <= 0) return sampled;

  const result = [...sampled];
  const minSeparationNm = 5;

  // Build TOC waypoint
  if (
    profile.tocDistanceNm > minSeparationNm &&
    profile.tocDistanceNm < totalDist - minSeparationNm
  ) {
    const tooClose = result.some(
      (wp) => Math.abs(wp.distanceFromDep - profile.tocDistanceNm) < minSeparationNm,
    );
    if (!tooClose) {
      const tocWp = interpolateWaypoint(
        'T.O.C.',
        profile.tocDistanceNm,
        allWaypoints,
      );
      if (tocWp) result.push(tocWp);
    }
  }

  // Build TOD waypoint
  if (
    profile.todDistanceNm > minSeparationNm &&
    profile.todDistanceNm < totalDist - minSeparationNm
  ) {
    const tooClose = result.some(
      (wp) => Math.abs(wp.distanceFromDep - profile.todDistanceNm) < minSeparationNm,
    );
    if (!tooClose) {
      const todWp = interpolateWaypoint(
        'T.O.D.',
        profile.todDistanceNm,
        allWaypoints,
      );
      if (todWp) result.push(todWp);
    }
  }

  // Sort by distance along route
  result.sort((a, b) => a.distanceFromDep - b.distanceFromDep);
  return result;
}

/**
 * Create a synthetic waypoint at a given distance by interpolating
 * lat/lng/eta from the full waypoint list.
 */
function interpolateWaypoint(
  identifier: string,
  distNm: number,
  waypoints: BriefingWaypoint[],
): BriefingWaypoint | null {
  const pos = interpolatePosition(distNm, waypoints);
  if (!pos) return null;

  // Find bracketing waypoints for ETA interpolation
  let before = waypoints[0];
  let after = waypoints[waypoints.length - 1];
  for (let i = 0; i < waypoints.length - 1; i++) {
    if (
      waypoints[i].distanceFromDep <= distNm &&
      waypoints[i + 1].distanceFromDep >= distNm
    ) {
      before = waypoints[i];
      after = waypoints[i + 1];
      break;
    }
  }

  const segDist = after.distanceFromDep - before.distanceFromDep;
  const fraction = segDist > 0 ? (distNm - before.distanceFromDep) / segDist : 0;

  return {
    identifier,
    latitude: pos.lat,
    longitude: pos.lng,
    type: 'phase',
    distanceFromDep: Math.round(distNm),
    etaMinutes: Math.round(
      before.etaMinutes + fraction * (after.etaMinutes - before.etaMinutes),
    ),
  };
}

function computeEtaZulu(
  etdIso: string | null,
  etaMinutes: number,
): string | null {
  if (!etdIso) return null;
  const etd = new Date(etdIso);
  if (isNaN(etd.getTime())) return null;
  const eta = new Date(etd.getTime() + etaMinutes * 60 * 1000);
  return eta.toISOString();
}

function findNearestMetar(
  wp: BriefingWaypoint,
  metars: BriefingMetar[],
): BriefingMetar | null {
  if (metars.length === 0) return null;

  let nearest: BriefingMetar | null = null;
  let bestDist = Infinity;

  // We don't have lat/lng on metars directly, but we match by section logic
  // For departure waypoint → departure metar, destination → destination metar
  // For route waypoints → find nearest route metar by index proximity
  // Since metars are ordered dep, route..., dest, and waypoints similarly,
  // we can use a simple distance heuristic

  // First try exact section match for dep/dest
  if (wp.distanceFromDep === 0) {
    const depMetar = metars.find((m) => m.section === 'departure');
    if (depMetar) return depMetar;
  }

  // For the last waypoint, try destination
  const lastWpDist = Math.max(...metars.map(() => 0));
  const destMetar = metars.find((m) => m.section === 'destination');

  // Simple: return the metar whose station is nearest in the ordered list
  // based on section ordering
  const routeMetars = metars.filter((m) => m.section === 'route');

  // If this is near departure, return departure metar
  const dep = metars.find((m) => m.section === 'departure');
  if (dep && wp.distanceFromDep < 30) return dep;

  // If this is near destination, return destination metar
  if (destMetar && routeMetars.length === 0) return destMetar;

  // For route waypoints, find the closest route metar
  // We'll estimate station positions from their order in the metars array
  if (routeMetars.length > 0) {
    // Since we don't have lat/lng for stations, use the ordered index
    // as a proxy for route distance
    const totalDist = metars.length > 1 ? metars.length - 1 : 1;
    const wpFraction =
      wp.etaMinutes / (metars.length > 0 ? Math.max(wp.etaMinutes, 1) : 1);

    // Just pick the metar with the closest index
    for (const metar of metars) {
      // Simple heuristic — works because metars are ordered along route
      const idx = metars.indexOf(metar);
      const metarFraction = idx / totalDist;
      const dist = Math.abs(metarFraction - wpFraction);
      if (dist < bestDist) {
        bestDist = dist;
        nearest = metar;
      }
    }
  }

  return nearest || destMetar || dep || null;
}

function findForecastAtEta(
  wp: BriefingWaypoint,
  tafs: {
    station: string;
    icaoId: string;
    section: string;
    fcsts: TafForecastPeriod[];
  }[],
  etaZulu: string | null,
): TafForecastPeriod | null {
  if (tafs.length === 0) return null;

  // Find nearest TAF by section
  let taf = tafs.find((t) => {
    if (wp.distanceFromDep === 0) return t.section === 'departure';
    return t.section === 'destination';
  });

  // For route waypoints, find nearest route TAF
  if (!taf) {
    const routeTafs = tafs.filter((t) => t.section === 'route');
    taf = routeTafs[0] || tafs[0];
  }

  if (!taf?.fcsts?.length) return null;
  if (!etaZulu) return taf.fcsts[0] || null;

  const eta = new Date(etaZulu).getTime();
  if (isNaN(eta)) return taf.fcsts[0] || null;

  // Find the forecast period that covers the ETA
  for (let i = taf.fcsts.length - 1; i >= 0; i--) {
    const from = new Date(taf.fcsts[i].timeFrom).getTime();
    const to = new Date(taf.fcsts[i].timeTo).getTime();
    if (!isNaN(from) && !isNaN(to) && eta >= from && eta <= to) {
      return taf.fcsts[i];
    }
  }

  return taf.fcsts[taf.fcsts.length - 1] || null;
}

function computeWindComponents(
  wp: BriefingWaypoint,
  wpIdx: number,
  allWaypoints: BriefingWaypoint[],
  windsTable: WindsAloftTable | null,
  cruiseAlt: number | null,
): { headwind: number | null; crosswind: number | null } {
  if (!windsTable?.data?.length || !windsTable.waypoints.length) {
    return { headwind: null, crosswind: null };
  }

  // Find the altitude column closest to cruise
  const altIdx = findClosestAltIndex(windsTable.altitudes, cruiseAlt || 0);

  // Find the table row closest to this waypoint
  const tableRowIdx = findClosestTableRow(wp, windsTable, allWaypoints);

  if (
    tableRowIdx < 0 ||
    tableRowIdx >= windsTable.data.length ||
    altIdx < 0 ||
    altIdx >= windsTable.altitudes.length
  ) {
    return { headwind: null, crosswind: null };
  }

  const cell = windsTable.data[tableRowIdx]?.[altIdx];
  if (!cell?.direction || !cell?.speed) {
    return { headwind: null, crosswind: null };
  }

  // Compute course heading from this waypoint to next
  const courseDeg = computeCourseDeg(wp, wpIdx, allWaypoints);
  if (courseDeg == null) return { headwind: null, crosswind: null };

  const windDir = cell.direction;
  const windSpd = cell.speed;

  // Headwind is positive when wind opposes direction of travel
  const angleDiff = (windDir - courseDeg) * DEG_TO_RAD;
  const headwind = Math.round(windSpd * Math.cos(angleDiff));
  const crosswind = Math.round(windSpd * Math.sin(angleDiff));

  return { headwind, crosswind };
}

function findClosestAltIndex(altitudes: number[], target: number): number {
  let bestIdx = 0;
  let bestDiff = Math.abs(altitudes[0] - target);
  for (let i = 1; i < altitudes.length; i++) {
    const diff = Math.abs(altitudes[i] - target);
    if (diff < bestDiff) {
      bestDiff = diff;
      bestIdx = i;
    }
  }
  return bestIdx;
}

function findClosestTableRow(
  wp: BriefingWaypoint,
  windsTable: WindsAloftTable,
  allWaypoints: BriefingWaypoint[],
): number {
  // Map waypoint fraction of total distance to table row
  const totalDist =
    allWaypoints.length > 1
      ? allWaypoints[allWaypoints.length - 1].distanceFromDep
      : 1;
  const fraction = totalDist > 0 ? wp.distanceFromDep / totalDist : 0;
  const rowIdx = Math.round(fraction * (windsTable.data.length - 1));
  return Math.max(0, Math.min(windsTable.data.length - 1, rowIdx));
}

function computeCourseDeg(
  wp: BriefingWaypoint,
  wpIdx: number,
  allWaypoints: BriefingWaypoint[],
): number | null {
  let nextWp: BriefingWaypoint | null = null;
  if (wpIdx < allWaypoints.length - 1) {
    nextWp = allWaypoints[wpIdx + 1];
  } else if (wpIdx > 0) {
    nextWp = allWaypoints[wpIdx]; // use self
    wp = allWaypoints[wpIdx - 1]; // and previous as start
  }

  if (!nextWp) return null;

  const lat1 = wp.latitude * DEG_TO_RAD;
  const lat2 = nextWp.latitude * DEG_TO_RAD;
  const dLng = (nextWp.longitude - wp.longitude) * DEG_TO_RAD;

  const y = Math.sin(dLng) * Math.cos(lat2);
  const x =
    Math.cos(lat1) * Math.sin(lat2) -
    Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLng);
  const bearing = Math.atan2(y, x) / DEG_TO_RAD;

  return (bearing + 360) % 360;
}

function collectAdvisories(response: BriefingResponse): BriefingAdvisory[] {
  const airmets = response.adverseConditions.airmets;
  return [
    ...response.adverseConditions.convectiveSigmets,
    ...response.adverseConditions.sigmets,
    ...airmets.ifr,
    ...airmets.mountainObscuration,
    ...airmets.icing,
    ...airmets.turbulenceLow,
    ...airmets.turbulenceHigh,
    ...airmets.lowLevelWindShear,
    ...airmets.other,
  ];
}

interface AdvisoryOverlap {
  advisory: BriefingAdvisory;
  /** Distance ranges along route where this advisory's geometry intersects */
  ranges: { fromDist: number; toDist: number }[];
}

/**
 * Walk the route at a fixed interval and check each sample point against
 * each advisory's polygon geometry. Returns precise distance ranges.
 */
function computeAdvisoryOverlaps(
  advisories: BriefingAdvisory[],
  waypoints: BriefingWaypoint[],
  sampleIntervalNm: number,
): AdvisoryOverlap[] {
  if (waypoints.length < 2) return [];

  const totalDist = waypoints[waypoints.length - 1].distanceFromDep;
  if (totalDist <= 0) return [];

  // Generate sample points along the route at fixed intervals
  const samplePoints: { dist: number; lat: number; lng: number }[] = [];
  for (let d = 0; d <= totalDist; d += sampleIntervalNm) {
    const pos = interpolatePosition(d, waypoints);
    if (pos) samplePoints.push({ dist: d, ...pos });
  }
  // Always include the final point
  if (
    samplePoints.length === 0 ||
    samplePoints[samplePoints.length - 1].dist < totalDist
  ) {
    const pos = interpolatePosition(totalDist, waypoints);
    if (pos) samplePoints.push({ dist: totalDist, ...pos });
  }

  return advisories.map((adv) => ({
    advisory: adv,
    ranges: computeAffectedRanges(adv.geometry, samplePoints, sampleIntervalNm),
  }));
}

/**
 * Check which sample points fall within a geometry polygon and merge
 * consecutive hits into distance ranges.
 */
function computeAffectedRanges(
  geometry: any,
  samplePoints: { dist: number; lat: number; lng: number }[],
  sampleInterval: number,
): { fromDist: number; toDist: number }[] {
  if (!geometry) return [];
  const rings = extractRings(geometry);
  if (rings.length === 0) return [];

  const ranges: { fromDist: number; toDist: number }[] = [];
  let rangeStart: number | null = null;
  let lastHitDist = 0;

  for (const pt of samplePoints) {
    const hit = rings.some((ring) => pointInPolygon(pt.lat, pt.lng, ring));

    if (hit) {
      if (rangeStart === null) rangeStart = pt.dist;
      lastHitDist = pt.dist;
    } else {
      if (rangeStart !== null) {
        ranges.push({ fromDist: rangeStart, toDist: lastHitDist });
        rangeStart = null;
      }
    }
  }

  // Close any open range
  if (rangeStart !== null) {
    ranges.push({ fromDist: rangeStart, toDist: lastHitDist });
  }

  return ranges;
}

/**
 * Interpolate lat/lng at a given distance along the route waypoints.
 */
function interpolatePosition(
  distNm: number,
  waypoints: BriefingWaypoint[],
): { lat: number; lng: number } | null {
  if (waypoints.length < 2) return null;

  // Find the two bracketing waypoints
  let before = waypoints[0];
  let after = waypoints[waypoints.length - 1];
  for (let i = 0; i < waypoints.length - 1; i++) {
    if (
      waypoints[i].distanceFromDep <= distNm &&
      waypoints[i + 1].distanceFromDep >= distNm
    ) {
      before = waypoints[i];
      after = waypoints[i + 1];
      break;
    }
  }

  const segDist = after.distanceFromDep - before.distanceFromDep;
  const fraction =
    segDist > 0 ? (distNm - before.distanceFromDep) / segDist : 0;

  return {
    lat: before.latitude + fraction * (after.latitude - before.latitude),
    lng: before.longitude + fraction * (after.longitude - before.longitude),
  };
}

function findActiveHazards(
  wp: BriefingWaypoint,
  overlaps: AdvisoryOverlap[],
  phaseInfo: { phase: 'climb' | 'cruise' | 'descent'; estimatedAltitudeFt: number } | null,
  phaseProfile: FlightPhaseProfile | null,
): TimelineHazard[] {
  const hazards: TimelineHazard[] = [];

  for (const { advisory: adv, ranges } of overlaps) {
    // Check if this waypoint's distance falls within any affected range
    const inRange = ranges.some(
      (r) => wp.distanceFromDep >= r.fromDist && wp.distanceFromDep <= r.toDist,
    );
    if (!inRange) continue;

    // Use phase-aware altitude relation if we have phase info
    let altRelation: string | null = adv.altitudeRelation;
    if (phaseInfo) {
      altRelation = getPhaseAwareAltitudeRelation(
        phaseInfo.estimatedAltitudeFt,
        phaseInfo.phase,
        adv.base,
        adv.top,
      );
    }

    const alertLevel = computeAlertLevel(
      altRelation,
      phaseInfo?.phase || null,
      adv,
      phaseProfile,
    );

    hazards.push({
      type: adv.hazardType,
      description: buildTimelineHazardDescription(
        adv,
        altRelation,
        phaseInfo?.phase || null,
        phaseProfile,
      ),
      altitudeRelation: altRelation,
      alertLevel,
    });
  }

  return hazards;
}

/**
 * Compute alert level (color) for a timeline hazard based on flight phase
 * and altitude relation.
 *
 * Red:    within / climbing_through / descending_through (direct exposure)
 * Yellow: passed through recently (below you in climb, below you in descent)
 * Green:  clear — not at your altitude in cruise, or above cruise alt in climb,
 *         or above you in descent
 */
function computeAlertLevel(
  altRelation: string | null,
  phase: 'climb' | 'cruise' | 'descent' | null,
  advisory: BriefingAdvisory,
  phaseProfile: FlightPhaseProfile | null,
): 'red' | 'yellow' | 'green' {
  // Direct exposure — always red
  if (
    altRelation === 'within' ||
    altRelation === 'climbing_through' ||
    altRelation === 'descending_through'
  ) {
    return 'red';
  }

  // No phase info — fall back to simple logic
  if (!phase) {
    return altRelation === 'above' || altRelation === 'below' ? 'yellow' : 'yellow';
  }

  // Cruise: above or below you → green
  if (phase === 'cruise') {
    return 'green';
  }

  // Climb phase
  if (phase === 'climb') {
    if (altRelation === 'above') {
      // Band is below you — you climbed past it
      return 'yellow';
    }
    if (altRelation === 'below') {
      // Band is above you — check if it's above cruise altitude
      if (phaseProfile && advisory.baseFt != null) {
        if (advisory.baseFt > phaseProfile.cruiseAltitudeFt) {
          return 'green'; // entirely above cruise, will never reach it
        }
      }
      return 'yellow'; // will climb into it
    }
  }

  // Descent phase
  if (phase === 'descent') {
    if (altRelation === 'below') {
      // Band is above you — you've descended past it
      return 'green';
    }
    if (altRelation === 'above') {
      // Band is below you — you'll descend into it
      return 'yellow';
    }
  }

  return 'yellow';
}

/**
 * Build a pilot-friendly description for a timeline hazard.
 *
 * Climb:   "climbing through" / "climbed through" / "will climb through" / "above cruise alt"
 * Cruise:  "at your altitude" / "below you" / "above you"
 * Descent: "descending through" / "will descend through" / "above you"
 */
function buildTimelineHazardDescription(
  advisory: BriefingAdvisory,
  altRelation: string | null,
  phase: 'climb' | 'cruise' | 'descent' | null,
  phaseProfile: FlightPhaseProfile | null,
): string {
  const parts: string[] = [];

  const severity = advisory.severity ? `${advisory.severity} ` : '';
  parts.push(`${severity}${advisory.hazardType}`.trim());

  if (advisory.base || advisory.top) {
    const base = advisory.base || 'SFC';
    const top = advisory.top || '';
    parts.push(top ? `${base}-${top}` : `from ${base}`);
  }

  const label = getHazardLabel(altRelation, phase, advisory, phaseProfile);
  if (label) {
    parts.push(`\u2014 ${label}`);
  }

  return parts.join(' ');
}

function getHazardLabel(
  altRelation: string | null,
  phase: 'climb' | 'cruise' | 'descent' | null,
  advisory: BriefingAdvisory,
  phaseProfile: FlightPhaseProfile | null,
): string | null {
  if (!altRelation) return null;

  // Direct exposure labels (any phase)
  if (altRelation === 'climbing_through') return 'climbing through';
  if (altRelation === 'descending_through') return 'descending through';
  if (altRelation === 'within') return 'at your altitude';

  if (phase === 'climb') {
    if (altRelation === 'above') {
      // You're above the band — you climbed past it
      return 'climbed through';
    }
    if (altRelation === 'below') {
      // Band is above you — will you reach it?
      if (
        phaseProfile &&
        advisory.baseFt != null &&
        advisory.baseFt > phaseProfile.cruiseAltitudeFt
      ) {
        return 'above cruise alt';
      }
      return 'will climb through';
    }
  }

  if (phase === 'cruise') {
    return altRelation === 'above' ? 'below you' : 'above you';
  }

  if (phase === 'descent') {
    if (altRelation === 'above') {
      // Band is below you — you'll descend into it
      return 'will descend through';
    }
    if (altRelation === 'below') {
      // Band is above you — you've descended past it
      return 'above you';
    }
  }

  // Fallback (no phase info)
  return altRelation === 'above' ? 'below you' : 'above you';
}
