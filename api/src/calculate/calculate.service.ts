import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, ILike } from 'typeorm';
import { PerformanceProfile } from '../aircraft/entities/performance-profile.entity';
import { Airport } from '../airports/entities/airport.entity';
import { NavaidsService } from '../navaids/navaids.service';

export interface CalculateInput {
  departure_identifier?: string;
  destination_identifier?: string;
  route_string?: string;
  cruise_altitude?: number;
  true_airspeed?: number;
  fuel_burn_rate?: number;
  etd?: string;
  performance_profile_id?: number;
}

export interface PhaseResult {
  phase: string;
  distance_nm: number;
  time_minutes: number;
  fuel_gallons: number;
  speed_knots: number;
  start_altitude_ft: number;
  end_altitude_ft: number;
}

export interface CalculateResult {
  distance_nm: number | null;
  ete_minutes: number | null;
  flight_fuel_gallons: number | null;
  eta: string | null;
  calculation_method: string;
  phases: PhaseResult[] | null;
  waypoints: {
    identifier: string;
    latitude: number;
    longitude: number;
    type: string;
  }[];
  calculated_at: string;
}

export interface CalculateDebugResult extends CalculateResult {
  steps: { label: string; value: string }[];
}

@Injectable()
export class CalculateService {
  constructor(
    private navaidsService: NavaidsService,
    @InjectRepository(Airport)
    private airportRepo: Repository<Airport>,
    @InjectRepository(PerformanceProfile)
    private profileRepo: Repository<PerformanceProfile>,
  ) {}

  async calculate(input: CalculateInput): Promise<CalculateResult> {
    return this.run(input, false) as Promise<CalculateResult>;
  }

  async calculateDebug(input: CalculateInput): Promise<CalculateDebugResult> {
    return this.run(input, true) as Promise<CalculateDebugResult>;
  }

  private async run(
    input: CalculateInput,
    debug: boolean,
  ): Promise<CalculateResult | CalculateDebugResult> {
    const steps: { label: string; value: string }[] = [];
    const now = new Date().toISOString();

    const nullResult = (method = 'none'): CalculateResult => ({
      distance_nm: null,
      ete_minutes: null,
      flight_fuel_gallons: null,
      eta: null,
      calculation_method: method,
      phases: null,
      waypoints: [],
      calculated_at: now,
    });

    // Build full route identifiers
    const routeIds = (input.route_string || '')
      .trim()
      .split(/\s+/)
      .filter(Boolean);
    const identifiers: string[] = [];
    if (input.departure_identifier) {
      identifiers.push(input.departure_identifier);
    }
    identifiers.push(...routeIds);
    if (input.destination_identifier) {
      identifiers.push(input.destination_identifier);
    }

    if (debug) {
      steps.push({
        label: 'Departure',
        value: input.departure_identifier || '(not set)',
      });
      steps.push({
        label: 'Route String',
        value: input.route_string || '(empty)',
      });
      steps.push({
        label: 'Destination',
        value: input.destination_identifier || '(not set)',
      });
    }

    if (identifiers.length < 2) {
      if (debug) {
        steps.push({
          label: 'Result',
          value: 'Need at least departure + destination',
        });
        return { ...nullResult(), steps };
      }
      return nullResult();
    }

    if (debug) {
      steps.push({ label: 'Full Route', value: identifiers.join(', ') });
    }

    // Resolve waypoints
    const waypoints = await this.navaidsService.resolveRoute(identifiers);

    if (debug) {
      steps.push({
        label: 'Resolved Waypoints',
        value: `${waypoints.length} of ${identifiers.length} resolved`,
      });
      for (const wp of waypoints) {
        steps.push({
          label: `  ${wp.identifier} (${wp.type})`,
          value: `${wp.latitude.toFixed(4)}, ${wp.longitude.toFixed(4)}`,
        });
      }
    }

    if (waypoints.length < 2) {
      if (debug) {
        steps.push({
          label: 'Result',
          value: 'Need at least 2 resolved waypoints',
        });
        return { ...nullResult(), steps };
      }
      return nullResult();
    }

    // Calculate total distance
    let totalNm = 0;
    for (let i = 1; i < waypoints.length; i++) {
      const legNm = haversineNm(
        waypoints[i - 1].latitude,
        waypoints[i - 1].longitude,
        waypoints[i].latitude,
        waypoints[i].longitude,
      );
      totalNm += legNm;
      if (debug) {
        steps.push({
          label: `Leg ${i}: ${waypoints[i - 1].identifier} → ${waypoints[i].identifier}`,
          value: `${legNm.toFixed(1)} nm`,
        });
      }
    }

    if (debug) {
      steps.push({ label: 'Total Distance', value: `${totalNm.toFixed(1)} nm` });
    }

    const distanceNm = Math.round(totalNm * 10) / 10;

    // Try 3-phase calculation
    const threePhase = await this.tryThreePhase(
      input,
      totalNm,
      steps,
      debug,
    );

    if (threePhase) {
      const eteMinutes = Math.round(
        threePhase.reduce((s, p) => s + p.time_minutes, 0),
      );
      const fuelGallons =
        Math.round(
          threePhase.reduce((s, p) => s + p.fuel_gallons, 0) * 10,
        ) / 10;

      let eta: string | null = null;
      if (input.etd) {
        const etdDate = new Date(input.etd);
        if (!isNaN(etdDate.getTime())) {
          eta = new Date(
            etdDate.getTime() + eteMinutes * 60_000,
          ).toISOString();
        }
      }

      if (debug) {
        steps.push({
          label: 'Calculation Method',
          value: 'three_phase',
        });
        for (const p of threePhase) {
          steps.push({
            label: `Phase: ${p.phase}`,
            value: `${p.distance_nm.toFixed(1)} nm, ${p.time_minutes.toFixed(1)} min, ${p.fuel_gallons.toFixed(1)} gal @ ${p.speed_knots} kt (${p.start_altitude_ft}→${p.end_altitude_ft} ft)`,
          });
        }
        steps.push({
          label: 'Totals',
          value: `${distanceNm} nm, ${eteMinutes} min, ${fuelGallons} gal`,
        });
      }

      const result: CalculateResult = {
        distance_nm: distanceNm,
        ete_minutes: eteMinutes,
        flight_fuel_gallons: fuelGallons,
        eta,
        calculation_method: 'three_phase',
        phases: threePhase,
        waypoints,
        calculated_at: now,
      };
      return debug ? { ...result, steps } : result;
    }

    // Fallback: single-phase
    return this.singlePhase(input, totalNm, distanceNm, waypoints, steps, debug, now);
  }

  private async tryThreePhase(
    input: CalculateInput,
    totalNm: number,
    steps: { label: string; value: string }[],
    debug: boolean,
  ): Promise<PhaseResult[] | null> {
    if (!input.performance_profile_id || !input.cruise_altitude) {
      if (debug) {
        steps.push({
          label: '3-Phase Check',
          value: !input.performance_profile_id
            ? 'No performance profile set'
            : 'No cruise altitude set',
        });
      }
      return null;
    }

    const profile = await this.profileRepo.findOne({
      where: { id: input.performance_profile_id },
    });
    if (!profile) {
      if (debug) {
        steps.push({
          label: '3-Phase Check',
          value: `Profile ${input.performance_profile_id} not found`,
        });
      }
      return null;
    }

    // Check all required climb/descent fields
    if (
      !profile.climb_rate ||
      !profile.climb_speed ||
      !profile.climb_fuel_flow ||
      !profile.descent_rate ||
      !profile.descent_speed ||
      !profile.descent_fuel_flow
    ) {
      if (debug) {
        steps.push({
          label: '3-Phase Check',
          value: 'Profile missing climb/descent fields — falling back',
        });
      }
      return null;
    }

    // Lookup airport elevations
    const depElev = await this.getAirportElevation(input.departure_identifier);
    const destElev = await this.getAirportElevation(
      input.destination_identifier,
    );

    if (debug) {
      steps.push({
        label: 'Departure Elevation',
        value: `${depElev} ft`,
      });
      steps.push({
        label: 'Destination Elevation',
        value: `${destElev} ft`,
      });
      steps.push({
        label: 'Cruise Altitude',
        value: `${input.cruise_altitude} ft`,
      });
    }

    // Climb phase
    const climbAlt = Math.max(0, input.cruise_altitude - depElev);
    const climbTimeMin = climbAlt > 0 ? climbAlt / profile.climb_rate : 0;
    const climbDist = profile.climb_speed * (climbTimeMin / 60);
    const climbFuel = profile.climb_fuel_flow * (climbTimeMin / 60);

    // Descent phase
    const descentAlt = Math.max(0, input.cruise_altitude - destElev);
    const descentTimeMin =
      descentAlt > 0 ? descentAlt / profile.descent_rate : 0;
    const descentDist = profile.descent_speed * (descentTimeMin / 60);
    const descentFuel = profile.descent_fuel_flow * (descentTimeMin / 60);

    // Check if climb+descent exceeds total
    if (climbDist + descentDist > totalNm) {
      if (debug) {
        steps.push({
          label: '3-Phase Check',
          value: `Climb (${climbDist.toFixed(1)}) + descent (${descentDist.toFixed(1)}) > total (${totalNm.toFixed(1)}) — falling back`,
        });
      }
      return null;
    }

    // Cruise phase
    const cruiseDist = totalNm - climbDist - descentDist;
    const cruiseTimeMin =
      profile.cruise_tas > 0
        ? (cruiseDist / profile.cruise_tas) * 60
        : 0;
    const cruiseFuel = profile.cruise_fuel_burn
      ? profile.cruise_fuel_burn * (cruiseTimeMin / 60)
      : 0;

    const phases: PhaseResult[] = [
      {
        phase: 'climb',
        distance_nm: Math.round(climbDist * 10) / 10,
        time_minutes: Math.round(climbTimeMin * 10) / 10,
        fuel_gallons: Math.round(climbFuel * 10) / 10,
        speed_knots: profile.climb_speed,
        start_altitude_ft: depElev,
        end_altitude_ft: input.cruise_altitude,
      },
      {
        phase: 'cruise',
        distance_nm: Math.round(cruiseDist * 10) / 10,
        time_minutes: Math.round(cruiseTimeMin * 10) / 10,
        fuel_gallons: Math.round(cruiseFuel * 10) / 10,
        speed_knots: profile.cruise_tas,
        start_altitude_ft: input.cruise_altitude,
        end_altitude_ft: input.cruise_altitude,
      },
      {
        phase: 'descent',
        distance_nm: Math.round(descentDist * 10) / 10,
        time_minutes: Math.round(descentTimeMin * 10) / 10,
        fuel_gallons: Math.round(descentFuel * 10) / 10,
        speed_knots: profile.descent_speed,
        start_altitude_ft: input.cruise_altitude,
        end_altitude_ft: destElev,
      },
    ];

    return phases;
  }

  private singlePhase(
    input: CalculateInput,
    totalNm: number,
    distanceNm: number,
    waypoints: {
      identifier: string;
      latitude: number;
      longitude: number;
      type: string;
    }[],
    steps: { label: string; value: string }[],
    debug: boolean,
    now: string,
  ): CalculateResult | CalculateDebugResult {
    const tas = input.true_airspeed;

    if (debug) {
      steps.push({ label: 'Calculation Method', value: 'single_phase' });
      steps.push({
        label: 'True Airspeed (TAS)',
        value: tas ? `${tas} kt` : '(not set)',
      });
    }

    if (!tas || tas <= 0) {
      const result: CalculateResult = {
        distance_nm: distanceNm,
        ete_minutes: null,
        flight_fuel_gallons: null,
        eta: null,
        calculation_method: 'single_phase',
        phases: null,
        waypoints,
        calculated_at: now,
      };
      return debug ? { ...result, steps } : result;
    }

    const eteHours = totalNm / tas;
    const eteMinutes = Math.round(eteHours * 60);

    let eta: string | null = null;
    if (input.etd) {
      const etdDate = new Date(input.etd);
      if (!isNaN(etdDate.getTime())) {
        eta = new Date(etdDate.getTime() + eteMinutes * 60_000).toISOString();
      }
    }

    const burnRate = input.fuel_burn_rate;
    const fuelGallons =
      burnRate && burnRate > 0
        ? Math.round(eteHours * burnRate * 10) / 10
        : null;

    if (debug) {
      const h = Math.floor(eteMinutes / 60);
      const m = eteMinutes % 60;
      steps.push({
        label: 'ETE Calculation',
        value: `${totalNm.toFixed(1)} nm ÷ ${tas} kt = ${eteHours.toFixed(3)} hr = ${h}h${String(m).padStart(2, '0')}m`,
      });
      if (input.etd) {
        steps.push({ label: 'ETD', value: input.etd });
        if (eta) {
          steps.push({ label: 'ETA', value: eta });
        }
      }
      steps.push({
        label: 'Fuel Burn Rate',
        value: burnRate ? `${burnRate} GPH` : '(not set)',
      });
      if (fuelGallons != null) {
        steps.push({
          label: 'Fuel Calculation',
          value: `${eteHours.toFixed(3)} hr × ${burnRate} GPH = ${fuelGallons} gal`,
        });
      }
    }

    const result: CalculateResult = {
      distance_nm: distanceNm,
      ete_minutes: eteMinutes,
      flight_fuel_gallons: fuelGallons,
      eta,
      calculation_method: 'single_phase',
      phases: null,
      waypoints,
      calculated_at: now,
    };
    return debug ? { ...result, steps } : result;
  }

  private async getAirportElevation(
    identifier?: string,
  ): Promise<number> {
    if (!identifier) return 0;
    const airport = await this.airportRepo.findOne({
      where: [
        { identifier: ILike(identifier) },
        { icao_identifier: ILike(identifier) },
      ],
    });
    return airport?.elevation ?? 0;
  }
}

/** Great-circle distance between two points in nautical miles. */
export function haversineNm(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {
  const R = 3440.065; // Earth radius in nautical miles
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}
