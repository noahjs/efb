/**
 * Shared types and geo-projection for plan-view SVG components.
 */

export interface GeoExtent {
  south: number;  // min latitude
  north: number;  // max latitude
  west: number;   // min longitude (negative for W)
  east: number;   // max longitude (negative for W)
}

export interface SVGSize {
  width: number;
  height: number;
}

export interface Fix {
  id: string;
  lat: number;
  lon: number;
  role?: 'IAF' | 'IF' | 'FAF' | 'MAP' | 'MAHF';
  altitude?: number;
  hat?: number;          // height above TDZE
  dme?: string;          // e.g. "D10.5 IAPA"
  radarFix?: boolean;
}

export interface VORDef {
  id: string;
  name: string;
  freq: string;
  lat: number;
  lon: number;
  type: 'VOR' | 'VORTAC' | 'VOR/DME';
  class?: string;        // e.g. "(H)"
}

export interface RadialDef {
  vorId: string;
  vorLat: number;
  vorLon: number;
  radialMag: number;     // magnetic bearing FROM VOR
  magVar: number;        // east = positive
  label: string;         // e.g. "R-147"
  throughFix?: string;   // fix ID the radial passes through
}

export interface HoldDef {
  fixId: string;
  fixLat: number;
  fixLon: number;
  inboundCourseMag: number;
  turnDirection: 'L' | 'R';
  magVar: number;
}

export interface ILSInfo {
  locId: string;
  freq: string;
  course: number;        // magnetic
  locLat: number;
  locLon: number;
}

export interface TerrainPoint {
  lat: number;
  lon: number;
  elevation: number;
}

/**
 * Projects geographic coordinates to SVG pixel coordinates.
 * SVG origin is top-left; y increases downward (south).
 */
export class GeoProjection {
  private latRange: number;
  private lonRange: number;

  constructor(
    public readonly extent: GeoExtent,
    public readonly size: SVGSize,
  ) {
    this.latRange = extent.north - extent.south;
    this.lonRange = extent.east - extent.west;
  }

  /** Convert lat/lon to SVG (x, y). */
  project(lat: number, lon: number): { x: number; y: number } {
    return {
      x: ((lon - this.extent.west) / this.lonRange) * this.size.width,
      y: ((this.extent.north - lat) / this.latRange) * this.size.height,
    };
  }

  /** Nautical miles per SVG pixel (approximate, at center latitude). */
  get nmPerPx(): number {
    const centerLat = (this.extent.north + this.extent.south) / 2;
    const latNm = this.latRange * 60; // 1 deg lat ≈ 60 NM
    return latNm / this.size.height;
  }

  /** SVG pixels per nautical mile. */
  get pxPerNm(): number {
    return 1 / this.nmPerPx;
  }

  /**
   * Extend a line from a point in a given true heading direction
   * to the edge of the SVG viewBox. Returns start and end points
   * that span the visible area.
   */
  lineFromHeading(
    throughLat: number,
    throughLon: number,
    trueHeading: number,
  ): { x1: number; y1: number; x2: number; y2: number } {
    const p = this.project(throughLat, throughLon);

    // Convert true heading to SVG direction vector
    const rad = (trueHeading * Math.PI) / 180;
    // Heading 0 = north = -y in SVG; heading 90 = east = +x
    const dxGeo = Math.sin(rad); // east component
    const dyGeo = -Math.cos(rad); // south component (positive = south)

    // Scale for pixel aspect ratio
    const dx = (dxGeo / this.lonRange) * this.size.width;
    const dy = (-dyGeo / this.latRange) * this.size.height; // flip: geo south = SVG +y

    // Extend line to chart edges
    const tValues: number[] = [];
    if (dx !== 0) {
      tValues.push(-p.x / dx);                    // left edge
      tValues.push((this.size.width - p.x) / dx); // right edge
    }
    if (dy !== 0) {
      tValues.push(-p.y / dy);                     // top edge
      tValues.push((this.size.height - p.y) / dy); // bottom edge
    }

    const forward = tValues.filter((t) => t > 0);
    const backward = tValues.filter((t) => t < 0);

    const tMax = forward.length ? Math.min(...forward) : 100;
    const tMin = backward.length ? Math.max(...backward) : -100;

    return {
      x1: p.x + dx * tMin,
      y1: p.y + dy * tMin,
      x2: p.x + dx * tMax,
      y2: p.y + dy * tMax,
    };
  }
}
