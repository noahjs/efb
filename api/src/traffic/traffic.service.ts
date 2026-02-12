import {
  Injectable,
  Logger,
  OnModuleInit,
  OnModuleDestroy,
} from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';
import { TRAFFIC } from '../config/constants';

interface TrafficTarget {
  icaoHex: string;
  callsign: string;
  latitude: number;
  longitude: number;
  altitude: number;
  groundspeed: number;
  track: number;
  verticalRate: number;
  emitterCategory: string;
  isAirborne: boolean;
  positionAgeSeconds: number;
  lastSeen: number;
}

export interface TrafficResponse {
  targets: TrafficTarget[];
  count: number;
  source: string;
  dataAgeSeconds: number;
  cellKey: string;
}

interface GridCell {
  key: string;
  centerLat: number;
  centerLon: number;
  targets: TrafficTarget[];
  fetchedAt: number;
  lastRequestedAt: number;
}

@Injectable()
export class TrafficService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(TrafficService.name);

  // Grid cells keyed by "lat:lon" (snapped to grid)
  private cells = new Map<string, GridCell>();
  private pollTimer: ReturnType<typeof setInterval> | null = null;

  // API status tracking
  private _totalRequests = 0;
  private _totalErrors = 0;
  private _lastFetchAt = 0;
  private _lastErrorAt = 0;
  private _lastError = '';

  constructor(private readonly http: HttpService) {}

  onModuleInit() {
    this.pollTimer = setInterval(
      () => this.pollNextCell(),
      TRAFFIC.POLL_INTERVAL_MS,
    );
    this.logger.log(
      `Traffic grid polling started (every ${TRAFFIC.POLL_INTERVAL_MS}ms, ${TRAFFIC.GRID_CELL_DEG}° cells)`,
    );
  }

  onModuleDestroy() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer);
      this.pollTimer = null;
    }
  }

  /**
   * Snap a coordinate to the grid cell key.
   * E.g. lat=39.57, lon=-104.85 with 0.5° grid → "39.50:-105.00"
   */
  private cellKey(lat: number, lon: number): string {
    const step = TRAFFIC.GRID_CELL_DEG;
    const snappedLat = (Math.floor(lat / step) * step).toFixed(2);
    const snappedLon = (Math.floor(lon / step) * step).toFixed(2);
    return `${snappedLat}:${snappedLon}`;
  }

  private cellCenter(lat: number, lon: number): { lat: number; lon: number } {
    const step = TRAFFIC.GRID_CELL_DEG;
    return {
      lat: Math.floor(lat / step) * step + step / 2,
      lon: Math.floor(lon / step) * step + step / 2,
    };
  }

  /**
   * Called by the controller. Returns cached data and marks the cell as active.
   */
  getTrafficNearby(
    lat: number,
    lon: number,
    radiusNm: number,
  ): TrafficResponse {
    const key = this.cellKey(lat, lon);
    const now = Date.now();

    let cell = this.cells.get(key);
    if (!cell) {
      const center = this.cellCenter(lat, lon);
      cell = {
        key,
        centerLat: center.lat,
        centerLon: center.lon,
        targets: [],
        fetchedAt: 0,
        lastRequestedAt: now,
      };
      this.cells.set(key, cell);
      this.logger.debug(`New grid cell activated: ${key}`);
    } else {
      cell.lastRequestedAt = now;
    }

    // Filter targets within the requested radius from the user's actual position
    const targets = this.filterByRadius(cell.targets, lat, lon, radiusNm);
    const dataAge = cell.fetchedAt > 0 ? (now - cell.fetchedAt) / 1000 : -1;

    return {
      targets,
      count: targets.length,
      source: 'adsb_lol',
      dataAgeSeconds: Math.round(dataAge),
      cellKey: key,
    };
  }

  /**
   * Background poller: picks the most stale active cell and refreshes it.
   */
  private async pollNextCell() {
    const now = Date.now();

    // Prune inactive cells
    for (const [key, cell] of this.cells) {
      if (now - cell.lastRequestedAt > TRAFFIC.CELL_INACTIVE_MS) {
        this.cells.delete(key);
        this.logger.debug(`Grid cell expired: ${key}`);
      }
    }

    if (this.cells.size === 0) return;

    // Find the most stale cell (oldest fetchedAt)
    let stalestCell: GridCell | null = null;
    for (const cell of this.cells.values()) {
      if (!stalestCell || cell.fetchedAt < stalestCell.fetchedAt) {
        stalestCell = cell;
      }
    }

    if (!stalestCell) return;

    try {
      this._totalRequests++;
      const url = `${TRAFFIC.ADSB_LOL_BASE_URL}/point/${stalestCell.centerLat}/${stalestCell.centerLon}/${TRAFFIC.GRID_QUERY_RADIUS_NM}`;
      const { data } = await firstValueFrom(
        this.http.get(url, { timeout: TRAFFIC.TIMEOUT_MS }),
      );

      const aircraft = Array.isArray(data?.ac) ? data.ac : [];

      stalestCell.targets = aircraft
        .filter((ac: any) => {
          const cat = ac.category;
          if (cat === 'C1' || cat === 'C2') return false;
          if (ac.lat == null || ac.lon == null) return false;
          return true;
        })
        .map((ac: any) => {
          const seen = ac.seen ?? 0;
          return {
            icaoHex: ac.hex ?? '',
            callsign: (ac.flight ?? '').trim(),
            latitude: ac.lat,
            longitude: ac.lon,
            altitude: ac.alt_baro === 'ground' ? 0 : (ac.alt_baro ?? 0),
            groundspeed: Math.round(ac.gs ?? 0),
            track: Math.round(ac.track ?? 0),
            verticalRate: Math.round(ac.baro_rate ?? 0),
            emitterCategory: ac.category ?? '',
            isAirborne: ac.alt_baro !== 'ground',
            positionAgeSeconds: seen,
            lastSeen: now - seen * 1000,
          };
        });

      stalestCell.fetchedAt = now;
      this._lastFetchAt = now;
    } catch (error) {
      this._totalErrors++;
      this._lastErrorAt = Date.now();
      this._lastError = error?.message || String(error);
      this.logger.error(
        `Failed to poll cell ${stalestCell.key}`,
        error?.message ?? error,
      );
    }
  }

  /**
   * Haversine filter: only return targets within radiusNm of the point.
   */
  private filterByRadius(
    targets: TrafficTarget[],
    lat: number,
    lon: number,
    radiusNm: number,
  ): TrafficTarget[] {
    const R = 3440.065; // Earth radius in nm
    const toRad = Math.PI / 180;
    const lat1 = lat * toRad;
    const lon1 = lon * toRad;

    return targets.filter((t) => {
      const lat2 = t.latitude * toRad;
      const lon2 = t.longitude * toRad;
      const dLat = lat2 - lat1;
      const dLon = lon2 - lon1;
      const a =
        Math.sin(dLat / 2) ** 2 +
        Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
      const dist = 2 * R * Math.asin(Math.sqrt(a));
      return dist <= radiusNm;
    });
  }

  /** Expose active cell count for health/debug */
  getStats() {
    const now = Date.now();
    const cells = Array.from(this.cells.values()).map((c) => ({
      key: c.key,
      targetCount: c.targets.length,
      dataAgeSec: c.fetchedAt > 0 ? Math.round((now - c.fetchedAt) / 1000) : -1,
      idleSec: Math.round((now - c.lastRequestedAt) / 1000),
    }));
    return {
      name: 'Traffic',
      baseUrl: TRAFFIC.ADSB_LOL_BASE_URL,
      cacheEntries: this.cells.size,
      totalRequests: this._totalRequests,
      totalErrors: this._totalErrors,
      lastFetchAt: this._lastFetchAt || null,
      lastErrorAt: this._lastErrorAt || null,
      lastError: this._lastError || null,
      activeCells: cells.length,
      cells,
    };
  }
}
