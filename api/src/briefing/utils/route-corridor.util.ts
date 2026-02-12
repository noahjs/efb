const EARTH_RADIUS_NM = 3440.065;
const DEG_TO_RAD = Math.PI / 180;

interface LatLng {
  latitude: number;
  longitude: number;
}

export interface BoundingBox {
  minLat: number;
  maxLat: number;
  minLng: number;
  maxLng: number;
}

/**
 * Compute a bounding box around a set of waypoints with a buffer in NM.
 */
export function computeBoundingBox(
  waypoints: LatLng[],
  bufferNm: number,
): BoundingBox {
  if (waypoints.length === 0) {
    return { minLat: 0, maxLat: 0, minLng: 0, maxLng: 0 };
  }

  let minLat = 90,
    maxLat = -90,
    minLng = 180,
    maxLng = -180;
  for (const wp of waypoints) {
    if (wp.latitude < minLat) minLat = wp.latitude;
    if (wp.latitude > maxLat) maxLat = wp.latitude;
    if (wp.longitude < minLng) minLng = wp.longitude;
    if (wp.longitude > maxLng) maxLng = wp.longitude;
  }

  // 1 degree latitude ≈ 60 NM
  const latBuffer = bufferNm / 60;
  // Longitude degrees vary with latitude
  const midLat = (minLat + maxLat) / 2;
  const lngBuffer = bufferNm / (60 * Math.cos(midLat * DEG_TO_RAD));

  return {
    minLat: minLat - latBuffer,
    maxLat: maxLat + latBuffer,
    minLng: minLng - lngBuffer,
    maxLng: maxLng + lngBuffer,
  };
}

/**
 * Haversine distance between two points in NM.
 */
export function haversineNm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const dLat = (lat2 - lat1) * DEG_TO_RAD;
  const dLng = (lng2 - lng1) * DEG_TO_RAD;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * DEG_TO_RAD) *
      Math.cos(lat2 * DEG_TO_RAD) *
      Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_NM * Math.asin(Math.sqrt(a));
}

/**
 * Compute along-track and cross-track position of a point relative to a route.
 * Returns whether the point is in the corridor, its perpendicular distance
 * from the route, and its distance along the route from the first waypoint.
 */
export function getPositionAlongRoute(
  lat: number,
  lng: number,
  waypoints: LatLng[],
  corridorNm: number,
): { inCorridor: boolean; crossTrackNm: number; alongTrackNm: number } {
  if (waypoints.length === 0) {
    return { inCorridor: false, crossTrackNm: Infinity, alongTrackNm: 0 };
  }

  if (waypoints.length === 1) {
    const d = haversineNm(
      lat,
      lng,
      waypoints[0].latitude,
      waypoints[0].longitude,
    );
    return { inCorridor: d <= corridorNm, crossTrackNm: d, alongTrackNm: 0 };
  }

  let bestXtd = Infinity;
  let bestAlongTrack = 0;
  let cumDist = 0;

  for (let i = 0; i < waypoints.length - 1; i++) {
    const segLen = haversineNm(
      waypoints[i].latitude,
      waypoints[i].longitude,
      waypoints[i + 1].latitude,
      waypoints[i + 1].longitude,
    );

    const xtd = crossTrackDistanceNm(
      lat,
      lng,
      waypoints[i].latitude,
      waypoints[i].longitude,
      waypoints[i + 1].latitude,
      waypoints[i + 1].longitude,
    );

    const d1 = haversineNm(
      waypoints[i].latitude,
      waypoints[i].longitude,
      lat,
      lng,
    );
    const d2 = haversineNm(
      waypoints[i + 1].latitude,
      waypoints[i + 1].longitude,
      lat,
      lng,
    );

    // Point projects onto this segment (with buffer)
    if (d1 <= segLen + corridorNm && d2 <= segLen + corridorNm) {
      if (xtd < bestXtd) {
        const atd = Math.sqrt(Math.max(0, d1 * d1 - xtd * xtd));
        bestXtd = xtd;
        bestAlongTrack = cumDist + atd;
      }
    }

    cumDist += segLen;
  }

  // Also check proximity to endpoints
  const dFirst = haversineNm(
    lat,
    lng,
    waypoints[0].latitude,
    waypoints[0].longitude,
  );
  if (dFirst < bestXtd) {
    bestXtd = dFirst;
    bestAlongTrack = 0;
  }

  const dLast = haversineNm(
    lat,
    lng,
    waypoints[waypoints.length - 1].latitude,
    waypoints[waypoints.length - 1].longitude,
  );
  if (dLast < bestXtd) {
    bestXtd = dLast;
    bestAlongTrack = cumDist;
  }

  return {
    inCorridor: bestXtd <= corridorNm,
    crossTrackNm: bestXtd,
    alongTrackNm: bestAlongTrack,
  };
}

/**
 * Cross-track distance from a point to a great-circle path (A→B), in NM.
 */
function crossTrackDistanceNm(
  pointLat: number,
  pointLng: number,
  startLat: number,
  startLng: number,
  endLat: number,
  endLng: number,
): number {
  const d13 = haversineNm(startLat, startLng, pointLat, pointLng);
  const theta13 = bearingRad(startLat, startLng, pointLat, pointLng);
  const theta12 = bearingRad(startLat, startLng, endLat, endLng);
  return Math.abs(
    Math.asin(Math.sin(d13 / EARTH_RADIUS_NM) * Math.sin(theta13 - theta12)) *
      EARTH_RADIUS_NM,
  );
}

function bearingRad(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const φ1 = lat1 * DEG_TO_RAD;
  const φ2 = lat2 * DEG_TO_RAD;
  const Δλ = (lng2 - lng1) * DEG_TO_RAD;
  const y = Math.sin(Δλ) * Math.cos(φ2);
  const x =
    Math.cos(φ1) * Math.sin(φ2) - Math.sin(φ1) * Math.cos(φ2) * Math.cos(Δλ);
  return Math.atan2(y, x);
}

/**
 * Check if a point is within corridorNm of the route defined by waypoints.
 */
export function isPointInCorridor(
  lat: number,
  lng: number,
  waypoints: LatLng[],
  corridorNm: number,
): boolean {
  if (waypoints.length < 2) {
    return (
      waypoints.length === 1 &&
      haversineNm(lat, lng, waypoints[0].latitude, waypoints[0].longitude) <=
        corridorNm
    );
  }

  for (let i = 0; i < waypoints.length - 1; i++) {
    const xtd = crossTrackDistanceNm(
      lat,
      lng,
      waypoints[i].latitude,
      waypoints[i].longitude,
      waypoints[i + 1].latitude,
      waypoints[i + 1].longitude,
    );
    if (xtd <= corridorNm) {
      // Also check along-track: point should project onto this segment
      const segLen = haversineNm(
        waypoints[i].latitude,
        waypoints[i].longitude,
        waypoints[i + 1].latitude,
        waypoints[i + 1].longitude,
      );
      const d1 = haversineNm(
        waypoints[i].latitude,
        waypoints[i].longitude,
        lat,
        lng,
      );
      const d2 = haversineNm(
        waypoints[i + 1].latitude,
        waypoints[i + 1].longitude,
        lat,
        lng,
      );
      // Point is between endpoints (with some buffer) or near an endpoint
      if (d1 <= segLen + corridorNm && d2 <= segLen + corridorNm) {
        return true;
      }
    }
  }
  return false;
}

/**
 * Ray-casting point-in-polygon test.
 */
export function pointInPolygon(
  lat: number,
  lng: number,
  coordinates: number[][],
): boolean {
  let inside = false;
  for (let i = 0, j = coordinates.length - 1; i < coordinates.length; j = i++) {
    const xi = coordinates[i][1],
      yi = coordinates[i][0]; // GeoJSON is [lng, lat]
    const xj = coordinates[j][1],
      yj = coordinates[j][0];
    const intersect =
      yi > lng !== yj > lng && lat < ((xj - xi) * (lng - yi)) / (yj - yi) + xi;
    if (intersect) inside = !inside;
  }
  return inside;
}

/**
 * Check if a GeoJSON geometry (polygon/multipolygon) intersects a route corridor.
 * Uses two checks: any polygon vertex in corridor OR any waypoint in polygon.
 */
export function doesPolygonIntersectCorridor(
  geometry: any,
  waypoints: LatLng[],
  corridorNm: number,
): boolean {
  if (!geometry) return false;

  const rings = extractRings(geometry);
  for (const ring of rings) {
    // Check if any polygon vertex is within the corridor
    for (const coord of ring) {
      if (isPointInCorridor(coord[1], coord[0], waypoints, corridorNm)) {
        return true;
      }
    }
    // Check if any waypoint is inside the polygon
    for (const wp of waypoints) {
      if (pointInPolygon(wp.latitude, wp.longitude, ring)) {
        return true;
      }
    }
  }
  return false;
}

/**
 * Extract coordinate rings from a GeoJSON geometry.
 */
function extractRings(geometry: any): number[][][] {
  if (!geometry || !geometry.type) return [];
  if (geometry.type === 'Polygon') {
    return geometry.coordinates || [];
  }
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
