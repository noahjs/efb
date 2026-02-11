// GFA region bounding boxes (approximate lat/lng)
const GFA_REGIONS: Record<
  string,
  { name: string; minLat: number; maxLat: number; minLng: number; maxLng: number }
> = {
  ne: { name: 'Northeast', minLat: 39, maxLat: 48, minLng: -80, maxLng: -66 },
  e: { name: 'East', minLat: 34, maxLat: 42, minLng: -84, maxLng: -74 },
  se: { name: 'Southeast', minLat: 24, maxLat: 36, minLng: -90, maxLng: -75 },
  nc: {
    name: 'North Central',
    minLat: 42,
    maxLat: 50,
    minLng: -104,
    maxLng: -82,
  },
  c: { name: 'Central', minLat: 34, maxLat: 44, minLng: -104, maxLng: -84 },
  sc: {
    name: 'South Central',
    minLat: 25,
    maxLat: 37,
    minLng: -106,
    maxLng: -88,
  },
  nw: {
    name: 'Northwest',
    minLat: 42,
    maxLat: 50,
    minLng: -126,
    maxLng: -104,
  },
  w: { name: 'West', minLat: 34, maxLat: 44, minLng: -125, maxLng: -104 },
  sw: {
    name: 'Southwest',
    minLat: 30,
    maxLat: 38,
    minLng: -125,
    maxLng: -108,
  },
};

interface LatLng {
  latitude: number;
  longitude: number;
}

/**
 * Determine which GFA regions a route passes through.
 * Always includes 'us' (CONUS).
 */
export function determineGfaRegions(
  waypoints: LatLng[],
): { region: string; regionName: string }[] {
  const matched = new Set<string>();

  for (const wp of waypoints) {
    for (const [region, bounds] of Object.entries(GFA_REGIONS)) {
      if (
        wp.latitude >= bounds.minLat &&
        wp.latitude <= bounds.maxLat &&
        wp.longitude >= bounds.minLng &&
        wp.longitude <= bounds.maxLng
      ) {
        matched.add(region);
      }
    }
  }

  const result: { region: string; regionName: string }[] = [
    { region: 'us', regionName: 'CONUS' },
  ];

  for (const region of matched) {
    result.push({ region, regionName: GFA_REGIONS[region].name });
  }

  return result;
}
