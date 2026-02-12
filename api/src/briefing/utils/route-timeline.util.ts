import {
  BriefingResponse,
  BriefingWaypoint,
  BriefingMetar,
  BriefingAdvisory,
  TafForecastPeriod,
  TimelinePoint,
  TimelineHazard,
  WindsAloftTable,
} from '../interfaces/briefing-response.interface';
import { haversineNm } from './route-corridor.util';

const DEG_TO_RAD = Math.PI / 180;

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
  const sampled = sampleWaypoints(waypoints, 10);
  const metars = response.currentWeather.metars;
  const tafs = response.forecasts.tafs;
  const windsTable = response.forecasts.windsAloftTable;
  const cruiseAlt = response.flight.cruiseAltitude;

  // Collect all advisories for hazard checking
  const allAdvisories = collectAdvisories(response);

  return sampled.map((wp, idx) => {
    // Compute ETA in Zulu
    const etaZulu = computeEtaZulu(etdIso, wp.etaMinutes);

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

    // Find active hazards at this point
    const activeHazards = findActiveHazards(wp, allAdvisories);

    return {
      waypoint: wp.identifier,
      latitude: wp.latitude,
      longitude: wp.longitude,
      distanceFromDep: wp.distanceFromDep,
      etaMinutes: wp.etaMinutes,
      etaZulu,
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
    const wpFraction = wp.etaMinutes / (metars.length > 0 ? Math.max(wp.etaMinutes, 1) : 1);

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
  tafs: { station: string; icaoId: string; section: string; fcsts: TafForecastPeriod[] }[],
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

function findActiveHazards(
  wp: BriefingWaypoint,
  advisories: BriefingAdvisory[],
): TimelineHazard[] {
  const hazards: TimelineHazard[] = [];

  for (const adv of advisories) {
    if (!adv.affectedSegment) continue;

    // Check if this waypoint's distance falls within the affected segment
    if (
      wp.distanceFromDep >= adv.affectedSegment.fromDistNm &&
      wp.distanceFromDep <= adv.affectedSegment.toDistNm
    ) {
      hazards.push({
        type: adv.hazardType,
        description: adv.plainEnglish || adv.hazardType,
        altitudeRelation: adv.altitudeRelation,
      });
    }
  }

  return hazards;
}
