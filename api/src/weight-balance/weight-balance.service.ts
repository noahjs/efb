import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { WBProfile } from './entities/wb-profile.entity';
import { WBStation } from './entities/wb-station.entity';
import { WBEnvelope } from './entities/wb-envelope.entity';
import { WBScenario } from './entities/wb-scenario.entity';
import { Flight } from '../flights/entities/flight.entity';
import { AircraftService } from '../aircraft/aircraft.service';
import { CreateWBProfileDto } from './dto/create-wb-profile.dto';
import { UpdateWBProfileDto } from './dto/update-wb-profile.dto';
import { CreateWBStationDto } from './dto/create-wb-station.dto';
import { UpdateWBStationDto } from './dto/update-wb-station.dto';
import { UpsertWBEnvelopeDto } from './dto/upsert-wb-envelope.dto';
import { CreateWBScenarioDto } from './dto/create-wb-scenario.dto';
import { UpdateWBScenarioDto } from './dto/update-wb-scenario.dto';
import { CalculateWBDto } from './dto/calculate-wb.dto';

@Injectable()
export class WeightBalanceService {
  constructor(
    @InjectRepository(WBProfile)
    private readonly profileRepo: Repository<WBProfile>,
    @InjectRepository(WBStation)
    private readonly stationRepo: Repository<WBStation>,
    @InjectRepository(WBEnvelope)
    private readonly envelopeRepo: Repository<WBEnvelope>,
    @InjectRepository(WBScenario)
    private readonly scenarioRepo: Repository<WBScenario>,
    @InjectRepository(Flight)
    private readonly flightRepo: Repository<Flight>,
    private readonly aircraftService: AircraftService,
  ) {}

  // --- Profiles ---

  async findProfiles(
    aircraftId: number,
    userId?: string,
  ): Promise<WBProfile[]> {
    await this.aircraftService.findOne(aircraftId, userId);
    return this.profileRepo.find({
      where: { aircraft_id: aircraftId },
      order: { is_default: 'DESC', name: 'ASC' },
    });
  }

  async findProfile(
    aircraftId: number,
    profileId: number,
    userId?: string,
  ): Promise<WBProfile> {
    await this.aircraftService.findOne(aircraftId, userId);
    const profile = await this.profileRepo.findOne({
      where: { id: profileId, aircraft_id: aircraftId },
      relations: ['stations', 'envelopes'],
      order: { stations: { sort_order: 'ASC' } },
    });
    if (!profile)
      throw new NotFoundException(`W&B Profile #${profileId} not found`);
    return profile;
  }

  async createProfile(
    aircraftId: number,
    dto: CreateWBProfileDto,
    userId?: string,
  ): Promise<WBProfile> {
    await this.aircraftService.findOne(aircraftId, userId);
    const moment =
      dto.empty_weight_moment ?? dto.empty_weight * dto.empty_weight_arm;
    const profile = this.profileRepo.create(
      Object.assign({}, dto, {
        aircraft_id: aircraftId,
        empty_weight_moment: moment,
        empty_weight_lateral_moment:
          dto.empty_weight_lateral_moment ??
          (dto.empty_weight_lateral_arm != null
            ? dto.empty_weight * dto.empty_weight_lateral_arm
            : undefined),
      }) as Partial<WBProfile>,
    );
    return this.profileRepo.save(profile);
  }

  async updateProfile(
    aircraftId: number,
    profileId: number,
    dto: UpdateWBProfileDto,
    userId?: string,
  ): Promise<WBProfile> {
    const profile = await this.findProfile(aircraftId, profileId, userId);
    Object.assign(profile, dto);
    // Recompute moment if weight or arm changed
    if (dto.empty_weight !== undefined || dto.empty_weight_arm !== undefined) {
      profile.empty_weight_moment =
        profile.empty_weight * profile.empty_weight_arm;
    }
    if (
      dto.empty_weight !== undefined ||
      dto.empty_weight_lateral_arm !== undefined
    ) {
      profile.empty_weight_lateral_moment =
        profile.empty_weight_lateral_arm != null
          ? profile.empty_weight * profile.empty_weight_lateral_arm
          : (null as any);
    }
    return this.profileRepo.save(profile);
  }

  async removeProfile(
    aircraftId: number,
    profileId: number,
    userId?: string,
  ): Promise<void> {
    const profile = await this.findProfile(aircraftId, profileId, userId);
    await this.profileRepo.remove(profile);
  }

  // --- Stations ---

  async createStation(
    aircraftId: number,
    profileId: number,
    dto: CreateWBStationDto,
    userId?: string,
  ): Promise<WBStation> {
    await this.findProfile(aircraftId, profileId, userId);
    const station = this.stationRepo.create({
      ...dto,
      wb_profile_id: profileId,
    });
    return this.stationRepo.save(station);
  }

  async updateStation(
    aircraftId: number,
    profileId: number,
    stationId: number,
    dto: UpdateWBStationDto,
    userId?: string,
  ): Promise<WBStation> {
    await this.findProfile(aircraftId, profileId, userId);
    const station = await this.stationRepo.findOne({
      where: { id: stationId, wb_profile_id: profileId },
    });
    if (!station)
      throw new NotFoundException(`Station #${stationId} not found`);
    Object.assign(station, dto);
    return this.stationRepo.save(station);
  }

  async removeStation(
    aircraftId: number,
    profileId: number,
    stationId: number,
    userId?: string,
  ): Promise<void> {
    await this.findProfile(aircraftId, profileId, userId);
    const station = await this.stationRepo.findOne({
      where: { id: stationId, wb_profile_id: profileId },
    });
    if (!station)
      throw new NotFoundException(`Station #${stationId} not found`);
    await this.stationRepo.remove(station);
  }

  async reorderStations(
    aircraftId: number,
    profileId: number,
    stationIds: number[],
    userId?: string,
  ): Promise<WBStation[]> {
    await this.findProfile(aircraftId, profileId, userId);
    for (let i = 0; i < stationIds.length; i++) {
      await this.stationRepo.update(
        { id: stationIds[i], wb_profile_id: profileId },
        { sort_order: i },
      );
    }
    return this.stationRepo.find({
      where: { wb_profile_id: profileId },
      order: { sort_order: 'ASC' },
    });
  }

  // --- Envelopes ---

  async upsertEnvelope(
    aircraftId: number,
    profileId: number,
    dto: UpsertWBEnvelopeDto,
    userId?: string,
  ): Promise<WBEnvelope> {
    await this.findProfile(aircraftId, profileId, userId);
    let envelope = await this.envelopeRepo.findOne({
      where: {
        wb_profile_id: profileId,
        envelope_type: dto.envelope_type,
        axis: dto.axis,
      },
    });
    if (envelope) {
      envelope.points = dto.points;
    } else {
      envelope = this.envelopeRepo.create({
        ...dto,
        wb_profile_id: profileId,
      });
    }
    return this.envelopeRepo.save(envelope);
  }

  // --- Scenarios ---

  async findScenarios(
    aircraftId: number,
    profileId: number,
    userId?: string,
  ): Promise<WBScenario[]> {
    await this.findProfile(aircraftId, profileId, userId);
    return this.scenarioRepo.find({
      where: { wb_profile_id: profileId },
      order: { updated_at: 'DESC' },
    });
  }

  async findScenario(
    aircraftId: number,
    profileId: number,
    scenarioId: number,
    userId?: string,
  ): Promise<WBScenario> {
    await this.findProfile(aircraftId, profileId, userId);
    const scenario = await this.scenarioRepo.findOne({
      where: { id: scenarioId, wb_profile_id: profileId },
    });
    if (!scenario)
      throw new NotFoundException(`Scenario #${scenarioId} not found`);
    return scenario;
  }

  async createScenario(
    aircraftId: number,
    profileId: number,
    dto: CreateWBScenarioDto,
    userId?: string,
  ): Promise<WBScenario> {
    const profile = await this.findProfile(aircraftId, profileId, userId);
    const aircraft = await this.aircraftService.findOne(aircraftId, userId);
    const result = this.computeWB(
      profile,
      dto.station_loads,
      aircraft.fuel_weight_per_gallon ?? 6.7,
      dto.starting_fuel_gallons,
      dto.ending_fuel_gallons,
    );
    const scenario = this.scenarioRepo.create(
      Object.assign(
        {},
        dto,
        {
          wb_profile_id: profileId,
        },
        this.computedResultToEntity(result),
      ) as Partial<WBScenario>,
    );
    return this.scenarioRepo.save(scenario);
  }

  async updateScenario(
    aircraftId: number,
    profileId: number,
    scenarioId: number,
    dto: UpdateWBScenarioDto,
    userId?: string,
  ): Promise<WBScenario> {
    const profile = await this.findProfile(aircraftId, profileId, userId);
    const scenario = await this.findScenario(
      aircraftId,
      profileId,
      scenarioId,
      userId,
    );
    Object.assign(scenario, dto);
    // Recompute if loads changed
    if (
      dto.station_loads ||
      dto.starting_fuel_gallons !== undefined ||
      dto.ending_fuel_gallons !== undefined
    ) {
      const aircraft = await this.aircraftService.findOne(aircraftId, userId);
      const result = this.computeWB(
        profile,
        scenario.station_loads,
        aircraft.fuel_weight_per_gallon ?? 6.7,
        scenario.starting_fuel_gallons,
        scenario.ending_fuel_gallons,
      );
      Object.assign(scenario, this.computedResultToEntity(result));
    }
    return this.scenarioRepo.save(scenario);
  }

  async removeScenario(
    aircraftId: number,
    profileId: number,
    scenarioId: number,
    userId?: string,
  ): Promise<void> {
    const scenario = await this.findScenario(
      aircraftId,
      profileId,
      scenarioId,
      userId,
    );
    await this.scenarioRepo.remove(scenario);
  }

  // --- Calculate (stateless) ---

  async calculate(
    aircraftId: number,
    profileId: number,
    dto: CalculateWBDto,
    userId?: string,
  ) {
    const profile = await this.findProfile(aircraftId, profileId, userId);
    const aircraft = await this.aircraftService.findOne(aircraftId, userId);
    return this.computeWB(
      profile,
      dto.station_loads,
      aircraft.fuel_weight_per_gallon ?? 6.7,
      dto.starting_fuel_gallons,
      dto.ending_fuel_gallons,
    );
  }

  // --- Flight W&B Integration ---

  async findOrCreateScenarioForFlight(flightId: number, userId?: string) {
    // 1. Check for existing scenario linked to this flight
    const existing = await this.scenarioRepo.findOne({
      where: { flight_id: flightId },
    });

    if (existing) {
      const profile = await this.profileRepo.findOne({
        where: { id: existing.wb_profile_id },
        relations: ['stations', 'envelopes'],
        order: { stations: { sort_order: 'ASC' } },
      });
      if (!profile) {
        throw new NotFoundException(
          `W&B Profile #${existing.wb_profile_id} not found`,
        );
      }
      return { scenario: existing, profile };
    }

    // 2. Look up the flight
    const where: Record<string, any> = { id: flightId };
    if (userId) where.user_id = userId;
    const flight = await this.flightRepo.findOne({ where });
    if (!flight) {
      throw new NotFoundException(`Flight #${flightId} not found`);
    }
    if (!flight.aircraft_id) {
      throw new NotFoundException(
        `Flight #${flightId} has no aircraft assigned`,
      );
    }

    // 3. Find default W&B profile for the aircraft
    let profile = await this.profileRepo.findOne({
      where: { aircraft_id: flight.aircraft_id, is_default: true },
      relations: ['stations', 'envelopes'],
      order: { stations: { sort_order: 'ASC' } },
    });
    if (!profile) {
      profile = await this.profileRepo.findOne({
        where: { aircraft_id: flight.aircraft_id },
        relations: ['stations', 'envelopes'],
        order: { stations: { sort_order: 'ASC' } },
      });
    }
    if (!profile) {
      throw new NotFoundException(
        `No W&B profile configured for aircraft #${flight.aircraft_id}`,
      );
    }

    // 4. Build default station loads from profile stations
    const stationLoads = (profile.stations || []).map((s) => ({
      station_id: s.id,
      weight: s.default_weight ?? 0,
    }));

    // 5. Get fuel from the flight
    const startingFuelGallons = flight.start_fuel_gallons ?? 0;
    const endingFuelGallons = flight.fuel_at_shutdown_gallons ?? 0;

    // 6. Compute W&B
    const aircraft = await this.aircraftService.findOne(
      flight.aircraft_id,
      userId,
    );
    const fuelWpg = aircraft.fuel_weight_per_gallon ?? 6.7;
    const result = this.computeWB(
      profile,
      stationLoads,
      fuelWpg,
      startingFuelGallons,
      endingFuelGallons,
    );

    // 7. Build scenario name
    const dep = flight.departure_identifier ?? '----';
    const dest = flight.destination_identifier ?? '----';
    const name = `${dep} - ${dest}`;

    // 8. Create and save scenario
    const scenario = this.scenarioRepo.create(
      Object.assign(
        {},
        {
          wb_profile_id: profile.id,
          flight_id: flightId,
          name,
          station_loads: stationLoads,
          starting_fuel_gallons: startingFuelGallons,
          ending_fuel_gallons: endingFuelGallons,
        },
        this.computedResultToEntity(result),
      ) as Partial<WBScenario>,
    );
    const saved = await this.scenarioRepo.save(scenario);

    return { scenario: saved, profile };
  }

  // --- CG Calculation Engine ---

  computeWB(
    profile: WBProfile,
    stationLoads: { station_id: number; weight: number }[],
    fuelWeightPerGallon: number,
    startingFuelGallons?: number,
    endingFuelGallons?: number,
  ) {
    const stations = profile.stations || [];
    const loadMap = new Map(stationLoads.map((l) => [l.station_id, l.weight]));

    // 1. Start with BEW
    const bewWeight = profile.empty_weight;
    const bewLongMoment = profile.empty_weight * profile.empty_weight_arm;
    const bewLatMoment = profile.lateral_cg_enabled
      ? profile.empty_weight * (profile.empty_weight_lateral_arm ?? 0)
      : 0;

    // 2. Add payload stations (non-fuel) → ZFW
    let payloadWeight = 0;
    let payloadLongMoment = 0;
    let payloadLatMoment = 0;
    const payloadStations = stations.filter((s) => s.category !== 'fuel');
    for (const station of payloadStations) {
      const weight = loadMap.get(station.id) ?? 0;
      if (weight > 0) {
        payloadWeight += weight;
        payloadLongMoment += weight * station.arm;
        if (profile.lateral_cg_enabled) {
          payloadLatMoment += weight * (station.lateral_arm ?? 0);
        }
      }
    }

    const zfw = bewWeight + payloadWeight;
    const zfwLongMoment = bewLongMoment + payloadLongMoment;
    const zfwLatMoment = bewLatMoment + payloadLatMoment;
    const zfwCg = zfw > 0 ? zfwLongMoment / zfw : 0;
    const zfwLatCg =
      profile.lateral_cg_enabled && zfw > 0 ? zfwLatMoment / zfw : null;

    // 3. Fuel moment helper — uses fuel stations if they exist,
    //    otherwise falls back to profile-level fuel_arm.
    const fuelStations = stations.filter((s) => s.category === 'fuel');
    const totalMaxWeight = fuelStations.reduce(
      (sum, s) => sum + (s.max_weight ?? 0),
      0,
    );

    const fuelProportions = (): number[] => {
      if (fuelStations.length === 0) return [];
      if (totalMaxWeight > 0) {
        return fuelStations.map((s) => (s.max_weight ?? 0) / totalMaxWeight);
      }
      const even = 1.0 / fuelStations.length;
      return Array(fuelStations.length).fill(even);
    };

    const proportions = fuelProportions();

    const fuelMoment = (
      gallons: number,
    ): { weight: number; longMoment: number; latMoment: number } => {
      const fuelWeight = gallons * fuelWeightPerGallon;
      let longMom = 0;
      let latMom = 0;

      if (fuelStations.length > 0) {
        for (let i = 0; i < fuelStations.length; i++) {
          const stationFuel = fuelWeight * proportions[i];
          longMom += stationFuel * fuelStations[i].arm;
          if (profile.lateral_cg_enabled) {
            latMom += stationFuel * (fuelStations[i].lateral_arm ?? 0);
          }
        }
      } else if (profile.fuel_arm != null) {
        longMom = fuelWeight * profile.fuel_arm;
        if (profile.lateral_cg_enabled) {
          latMom = fuelWeight * (profile.fuel_lateral_arm ?? 0);
        }
      }

      return { weight: fuelWeight, longMoment: longMom, latMoment: latMom };
    };

    // 4. Ramp weight = ZFW + starting fuel
    const startFuel = fuelMoment(startingFuelGallons ?? 0);
    const rampWeight = zfw + startFuel.weight;
    const rampLongMoment = zfwLongMoment + startFuel.longMoment;
    const rampLatMoment = zfwLatMoment + startFuel.latMoment;
    const rampCg = rampWeight > 0 ? rampLongMoment / rampWeight : 0;
    const rampLatCg =
      profile.lateral_cg_enabled && rampWeight > 0
        ? rampLatMoment / rampWeight
        : null;

    // 5. TOW = Ramp - taxi fuel
    const taxiFuel = fuelMoment(profile.taxi_fuel_gallons ?? 1);
    const tow = rampWeight - taxiFuel.weight;
    const towLongMoment = rampLongMoment - taxiFuel.longMoment;
    const towLatMoment = rampLatMoment - taxiFuel.latMoment;
    const towCg = tow > 0 ? towLongMoment / tow : 0;
    const towLatCg =
      profile.lateral_cg_enabled && tow > 0 ? towLatMoment / tow : null;

    // 6. LDW = ZFW + ending fuel (from first principles, not subtraction)
    const endFuel = fuelMoment(endingFuelGallons ?? 0);
    const ldw = zfw + endFuel.weight;
    const ldwLongMoment = zfwLongMoment + endFuel.longMoment;
    const ldwLatMoment = zfwLatMoment + endFuel.latMoment;
    const ldwCg = ldw > 0 ? ldwLongMoment / ldw : 0;
    const ldwLatCg =
      profile.lateral_cg_enabled && ldw > 0 ? ldwLatMoment / ldw : null;

    // Envelope checks
    const envelopes = profile.envelopes || [];
    const longEnvelopes = envelopes.filter((e) => e.axis === 'longitudinal');
    const latEnvelopes = envelopes.filter((e) => e.axis === 'lateral');

    const checkLong = (cg: number, weight: number) =>
      longEnvelopes.length === 0 ||
      longEnvelopes.some((env) => this.pointInPolygon(cg, weight, env.points));

    const checkLat = (cg: number | null, weight: number) => {
      if (!profile.lateral_cg_enabled || cg === null) return true;
      return (
        latEnvelopes.length === 0 ||
        latEnvelopes.some((env) => this.pointInPolygon(cg, weight, env.points))
      );
    };

    const checkWeightLimit = (weight: number, limit: number | null) =>
      limit === null ? true : weight <= limit;

    const zfwOk =
      checkLong(zfwCg, zfw) &&
      checkLat(zfwLatCg, zfw) &&
      checkWeightLimit(zfw, profile.max_zero_fuel_weight);
    const rampOk =
      checkLong(rampCg, rampWeight) &&
      checkLat(rampLatCg, rampWeight) &&
      checkWeightLimit(
        rampWeight,
        profile.max_ramp_weight ?? profile.max_takeoff_weight,
      );
    const towOk =
      checkLong(towCg, tow) &&
      checkLat(towLatCg, tow) &&
      checkWeightLimit(tow, profile.max_takeoff_weight);
    const ldwOk =
      checkLong(ldwCg, ldw) &&
      checkLat(ldwLatCg, ldw) &&
      checkWeightLimit(ldw, profile.max_landing_weight);

    const isWithinEnvelope = zfwOk && rampOk && towOk && ldwOk;

    return {
      computed_zfw: Math.round(zfw * 10) / 10,
      computed_zfw_cg: Math.round(zfwCg * 100) / 100,
      computed_zfw_lateral_cg:
        zfwLatCg !== null ? Math.round(zfwLatCg * 100) / 100 : null,
      computed_ramp_weight: Math.round(rampWeight * 10) / 10,
      computed_ramp_cg: Math.round(rampCg * 100) / 100,
      computed_ramp_lateral_cg:
        rampLatCg !== null ? Math.round(rampLatCg * 100) / 100 : null,
      computed_tow: Math.round(tow * 10) / 10,
      computed_tow_cg: Math.round(towCg * 100) / 100,
      computed_tow_lateral_cg:
        towLatCg !== null ? Math.round(towLatCg * 100) / 100 : null,
      computed_ldw: Math.round(ldw * 10) / 10,
      computed_ldw_cg: Math.round(ldwCg * 100) / 100,
      computed_ldw_lateral_cg:
        ldwLatCg !== null ? Math.round(ldwLatCg * 100) / 100 : null,
      is_within_envelope: isWithinEnvelope,
      conditions: {
        zfw: {
          weight: Math.round(zfw * 10) / 10,
          cg: Math.round(zfwCg * 100) / 100,
          lateral_cg:
            zfwLatCg !== null ? Math.round(zfwLatCg * 100) / 100 : null,
          within_limits: zfwOk,
        },
        ramp: {
          weight: Math.round(rampWeight * 10) / 10,
          cg: Math.round(rampCg * 100) / 100,
          lateral_cg:
            rampLatCg !== null ? Math.round(rampLatCg * 100) / 100 : null,
          within_limits: rampOk,
        },
        tow: {
          weight: Math.round(tow * 10) / 10,
          cg: Math.round(towCg * 100) / 100,
          lateral_cg:
            towLatCg !== null ? Math.round(towLatCg * 100) / 100 : null,
          within_limits: towOk,
        },
        ldw: {
          weight: Math.round(ldw * 10) / 10,
          cg: Math.round(ldwCg * 100) / 100,
          lateral_cg:
            ldwLatCg !== null ? Math.round(ldwLatCg * 100) / 100 : null,
          within_limits: ldwOk,
        },
      },
    };
  }

  private computedResultToEntity(result: ReturnType<typeof this.computeWB>) {
    const { conditions, ...entity } = result;
    return entity;
  }

  // Ray-casting point-in-polygon
  private pointInPolygon(
    x: number,
    y: number,
    polygon: { weight: number; cg: number }[],
  ): boolean {
    if (polygon.length < 3) return false;
    let inside = false;
    for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      const xi = polygon[i].cg,
        yi = polygon[i].weight;
      const xj = polygon[j].cg,
        yj = polygon[j].weight;

      const intersect =
        yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi;
      if (intersect) inside = !inside;
    }
    return inside;
  }
}
