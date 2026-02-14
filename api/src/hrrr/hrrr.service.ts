import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { HrrrCycle } from '../data-platform/entities/hrrr-cycle.entity';
import { HrrrSurface } from '../data-platform/entities/hrrr-surface.entity';
import { HrrrPressure } from '../data-platform/entities/hrrr-pressure.entity';
import { WindGrid } from '../data-platform/entities/wind-grid.entity';
import { WINDS } from '../config/constants';

@Injectable()
export class HrrrService {
  private readonly logger = new Logger(HrrrService.name);

  constructor(
    @InjectRepository(HrrrCycle)
    private readonly cycleRepo: Repository<HrrrCycle>,
    @InjectRepository(HrrrSurface)
    private readonly surfaceRepo: Repository<HrrrSurface>,
    @InjectRepository(HrrrPressure)
    private readonly pressureRepo: Repository<HrrrPressure>,
    @InjectRepository(WindGrid)
    private readonly windGridRepo: Repository<WindGrid>,
  ) {}

  // --- Admin ---

  async getCycles(limit = 10) {
    const cycles = await this.cycleRepo.find({
      order: { init_time: 'DESC' },
      take: limit,
    });

    const activeCycle = cycles.find((c) => c.is_active);

    return {
      active_cycle: activeCycle?.init_time || null,
      cycles: cycles.map((c) => ({
        init_time: c.init_time,
        status: c.status,
        is_active: c.is_active,
        download: {
          completed: c.download_completed,
          failed: c.download_failed,
          total: c.download_total,
          bytes: Number(c.download_bytes),
        },
        processing: {
          completed: c.process_completed,
          failed: c.process_failed,
          total: c.process_total,
        },
        ingest: {
          surface_rows: c.ingest_surface_rows,
          pressure_rows: c.ingest_pressure_rows,
        },
        tiles: {
          completed: c.tiles_completed,
          failed: c.tiles_failed,
          total: c.tiles_total,
          count: c.tiles_count,
        },
        timing: {
          download_started_at: c.download_started_at,
          download_completed_at: c.download_completed_at,
          process_started_at: c.process_started_at,
          process_completed_at: c.process_completed_at,
          ingest_completed_at: c.ingest_completed_at,
          tiles_started_at: c.tiles_started_at,
          tiles_completed_at: c.tiles_completed_at,
          activated_at: c.activated_at,
          total_duration_ms: c.total_duration_ms,
        },
        errors: {
          total: c.total_errors,
          last_error: c.last_error,
        },
      })),
    };
  }

  // --- Metadata ---

  async getMeta() {
    const activeCycle = await this.cycleRepo.findOne({
      where: { is_active: true },
    });

    if (!activeCycle) {
      return { model: 'hrrr', latest_init: null, products: {} };
    }

    // Find distinct forecast hours available
    const hours = await this.surfaceRepo
      .createQueryBuilder('s')
      .select('DISTINCT s.forecast_hour', 'fh')
      .where('s.init_time = :init', { init: activeCycle.init_time })
      .orderBy('fh', 'ASC')
      .getRawMany();

    const forecastHours = hours.map((h) => h.fh);

    return {
      model: 'hrrr',
      latest_init: activeCycle.init_time,
      products: {
        clouds: {
          levels: [
            'low',
            'mid',
            'high',
            'total',
            '1000',
            '925',
            '850',
            '700',
            '500',
            '400',
            '300',
            '250',
            '200',
          ],
          forecast_hours: forecastHours,
        },
        'flight-cat': {
          forecast_hours: forecastHours,
        },
      },
      level_altitudes: WINDS.LEVEL_ALTITUDES,
    };
  }

  // --- Route Weather Query ---

  async getRouteWeather(
    waypoints: Array<{ lat: number; lng: number }>,
    altitudeFt: number,
  ) {
    const activeCycle = await this.cycleRepo.findOne({
      where: { is_active: true },
    });
    if (!activeCycle) {
      return { model: 'hrrr', init_time: null, waypoints: [] };
    }

    // Find nearest pressure level for requested altitude
    const pressureLevel = this.altitudeToPressureLevel(altitudeFt);
    const initTime = activeCycle.init_time;

    const results: any[] = [];
    for (const wp of waypoints) {
      // Get nearest surface data
      const surface = await this.surfaceRepo
        .createQueryBuilder('s')
        .where('s.init_time = :init', { init: initTime })
        .orderBy(
          `(s.lat - :lat) * (s.lat - :lat) + (s.lng - :lng) * (s.lng - :lng)`,
          'ASC',
        )
        .setParameters({ lat: wp.lat, lng: wp.lng })
        .limit(1)
        .getOne();

      // Get pressure-level data at the requested altitude
      const pressure = await this.pressureRepo
        .createQueryBuilder('p')
        .where('p.init_time = :init', { init: initTime })
        .andWhere('p.pressure_level = :level', { level: pressureLevel })
        .orderBy(
          `(p.lat - :lat) * (p.lat - :lat) + (p.lng - :lng) * (p.lng - :lng)`,
          'ASC',
        )
        .setParameters({ lat: wp.lat, lng: wp.lng })
        .limit(1)
        .getOne();

      results.push({
        lat: wp.lat,
        lng: wp.lng,
        forecast_hour: surface?.forecast_hour ?? null,
        valid_time: surface?.valid_time ?? null,
        clouds: {
          at_altitude_rh: pressure?.relative_humidity ?? null,
          at_altitude_coverage: this.rhToCloudCategory(
            pressure?.relative_humidity,
          ),
          total: surface?.cloud_total ?? null,
          low: surface?.cloud_low ?? null,
          mid: surface?.cloud_mid ?? null,
          high: surface?.cloud_high ?? null,
          ceiling_ft: surface?.ceiling_ft ?? null,
          cloud_base_ft: surface?.cloud_base_ft ?? null,
          cloud_top_ft: surface?.cloud_top_ft ?? null,
          flight_category: surface?.flight_category ?? null,
        },
        wind: {
          direction: pressure?.wind_dir ?? null,
          speed_kt: pressure?.wind_speed_kt ?? null,
          temperature_c: pressure?.temperature_c ?? null,
        },
        surface: {
          wind_dir: surface?.wind_dir ?? null,
          wind_speed_kt: surface?.wind_speed_kt ?? null,
          wind_gust_kt: surface?.wind_gust_kt ?? null,
          temperature_c: surface?.temperature_c ?? null,
          visibility_sm: surface?.visibility_sm ?? null,
        },
      });
    }

    return {
      model: 'hrrr',
      init_time: initTime,
      altitude_ft: altitudeFt,
      pressure_level: pressureLevel,
      waypoints: results,
    };
  }

  // --- Route Profile (cross-section) ---

  async getRouteProfile(waypoints: Array<{ lat: number; lng: number }>) {
    const activeCycle = await this.cycleRepo.findOne({
      where: { is_active: true },
    });
    if (!activeCycle) {
      return { model: 'hrrr', init_time: null, waypoints: [] };
    }

    const initTime = activeCycle.init_time;
    const results: any[] = [];

    for (const wp of waypoints) {
      // Get surface data
      const surface = await this.surfaceRepo
        .createQueryBuilder('s')
        .where('s.init_time = :init', { init: initTime })
        .orderBy(
          `(s.lat - :lat) * (s.lat - :lat) + (s.lng - :lng) * (s.lng - :lng)`,
          'ASC',
        )
        .setParameters({ lat: wp.lat, lng: wp.lng })
        .limit(1)
        .getOne();

      if (!surface) continue;

      // Get all pressure levels at nearest grid point
      const pressureLevels = await this.pressureRepo
        .createQueryBuilder('p')
        .where('p.init_time = :init', { init: initTime })
        .andWhere('p.forecast_hour = :fh', { fh: surface.forecast_hour })
        .andWhere('p.lat = :lat AND p.lng = :lng', {
          lat: surface.lat,
          lng: surface.lng,
        })
        .orderBy('p.pressure_level', 'DESC')
        .getMany();

      results.push({
        lat: wp.lat,
        lng: wp.lng,
        valid_time: surface.valid_time,
        ceiling_ft: surface.ceiling_ft,
        cloud_base_ft: surface.cloud_base_ft,
        cloud_top_ft: surface.cloud_top_ft,
        visibility_sm: surface.visibility_sm,
        flight_category: surface.flight_category,
        levels: pressureLevels.map((p) => ({
          pressure: p.pressure_level,
          altitude_ft: p.altitude_ft,
          relative_humidity: p.relative_humidity,
          wind_dir: p.wind_dir,
          wind_speed_kt: p.wind_speed_kt,
          temp_c: p.temperature_c,
        })),
      });
    }

    return { model: 'hrrr', init_time: initTime, waypoints: results };
  }

  // --- Wind Comparison ---

  async compareWinds(lat: number, lng: number) {
    // HRRR data
    const activeCycle = await this.cycleRepo.findOne({
      where: { is_active: true },
    });

    let hrrrData: any = null;
    if (activeCycle) {
      const pressureLevels = await this.pressureRepo
        .createQueryBuilder('p')
        .where('p.init_time = :init', { init: activeCycle.init_time })
        .andWhere('p.forecast_hour = 1')
        .orderBy(
          `(p.lat - :lat) * (p.lat - :lat) + (p.lng - :lng) * (p.lng - :lng)`,
          'ASC',
        )
        .setParameters({ lat, lng })
        .limit(9) // 9 pressure levels
        .getMany();

      const levels: Record<string, any> = {};
      for (const p of pressureLevels) {
        levels[String(p.pressure_level)] = {
          dir: p.wind_dir,
          speed: p.wind_speed_kt,
          temp: p.temperature_c,
        };
      }

      hrrrData = {
        init_time: activeCycle.init_time,
        levels,
      };
    }

    // Open-Meteo data
    const windGrid = await this.windGridRepo
      .createQueryBuilder('w')
      .orderBy(
        `(w.lat - :lat) * (w.lat - :lat) + (w.lng - :lng) * (w.lng - :lng)`,
        'ASC',
      )
      .setParameters({ lat, lng })
      .limit(1)
      .getOne();

    let openMeteoData: any = null;
    if (windGrid?.levels) {
      const levels: Record<string, any> = {};
      for (const level of windGrid.levels) {
        if (level.level === 'surface') continue;
        const hPa = level.level.replace('hPa', '');
        const latest = level.winds?.[0];
        if (latest) {
          levels[hPa] = {
            dir: latest.direction,
            speed: latest.speed,
            temp: latest.temperature,
          };
        }
      }
      openMeteoData = {
        updated_at: windGrid.updated_at,
        levels,
      };
    }

    return {
      lat,
      lng,
      hrrr: hrrrData,
      open_meteo: openMeteoData,
    };
  }

  // --- Helpers ---

  private altitudeToPressureLevel(altFt: number): number {
    const levels = WINDS.LEVEL_ALTITUDES;
    let closest = 1000;
    let closestDiff = Infinity;

    for (const [key, alt] of Object.entries(levels)) {
      if (key === 'surface') continue;
      const diff = Math.abs(alt - altFt);
      if (diff < closestDiff) {
        closestDiff = diff;
        closest = Number(key);
      }
    }

    return closest;
  }

  /**
   * Derive approximate cloud coverage from relative humidity.
   * RH thresholds are standard NWP cloud diagnostics:
   *   <50% → CLR, 50-70% → FEW, 70-80% → SCT, 80-90% → BKN, >90% → OVC
   */
  private rhToCloudCategory(rh: number | null | undefined): string {
    if (rh == null) return 'N/A';
    if (rh < 50) return 'CLR';
    if (rh < 70) return 'FEW';
    if (rh < 80) return 'SCT';
    if (rh < 90) return 'BKN';
    return 'OVC';
  }
}
