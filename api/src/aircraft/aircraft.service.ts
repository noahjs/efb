import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, ILike } from 'typeorm';
import { Aircraft } from './entities/aircraft.entity';
import { PerformanceProfile } from './entities/performance-profile.entity';
import { FuelTank } from './entities/fuel-tank.entity';
import { Equipment } from './entities/equipment.entity';
import { MasterWBProfile } from './entities/master-wb-profile.entity';
import { WBProfile } from '../weight-balance/entities/wb-profile.entity';
import { WBStation } from '../weight-balance/entities/wb-station.entity';
import { WBEnvelope } from '../weight-balance/entities/wb-envelope.entity';
import { CreateAircraftDto } from './dto/create-aircraft.dto';
import { UpdateAircraftDto } from './dto/update-aircraft.dto';
import { CreatePerformanceProfileDto } from './dto/create-performance-profile.dto';
import { UpdatePerformanceProfileDto } from './dto/update-performance-profile.dto';
import { CreateFuelTankDto } from './dto/create-fuel-tank.dto';
import { UpdateFuelTankDto } from './dto/update-fuel-tank.dto';
import { UpdateEquipmentDto } from './dto/update-equipment.dto';
import {
  TBM960_TAKEOFF_DATA,
  TBM960_LANDING_DATA,
} from './seed/tbm960-performance';

@Injectable()
export class AircraftService {
  private readonly logger = new Logger(AircraftService.name);

  constructor(
    @InjectRepository(Aircraft)
    private readonly aircraftRepo: Repository<Aircraft>,
    @InjectRepository(PerformanceProfile)
    private readonly profileRepo: Repository<PerformanceProfile>,
    @InjectRepository(FuelTank)
    private readonly tankRepo: Repository<FuelTank>,
    @InjectRepository(Equipment)
    private readonly equipmentRepo: Repository<Equipment>,
    @InjectRepository(MasterWBProfile)
    private readonly masterProfileRepo: Repository<MasterWBProfile>,
    @InjectRepository(WBProfile)
    private readonly wbProfileRepo: Repository<WBProfile>,
    @InjectRepository(WBStation)
    private readonly wbStationRepo: Repository<WBStation>,
    @InjectRepository(WBEnvelope)
    private readonly wbEnvelopeRepo: Repository<WBEnvelope>,
  ) {}

  // --- Aircraft CRUD ---

  async findAll(userId: string, query?: string, limit = 50, offset = 0) {
    const where = query
      ? [
          { user_id: userId, tail_number: ILike(`%${query}%`) },
          { user_id: userId, aircraft_type: ILike(`%${query}%`) },
          { user_id: userId, icao_type_code: ILike(`%${query}%`) },
        ]
      : { user_id: userId };

    const [items, total] = await this.aircraftRepo.findAndCount({
      where,
      order: { is_default: 'DESC', updated_at: 'DESC' },
      take: limit,
      skip: offset,
    });

    return { items, total };
  }

  async findOne(id: number, userId?: string): Promise<Aircraft> {
    const where: Record<string, any> = { id };
    if (userId) where.user_id = userId;
    const aircraft = await this.aircraftRepo.findOne({
      where,
      relations: ['performance_profiles', 'fuel_tanks', 'equipment'],
    });
    if (!aircraft) throw new NotFoundException(`Aircraft #${id} not found`);
    return aircraft;
  }

  async findDefault(userId: string): Promise<Aircraft | null> {
    return this.aircraftRepo.findOne({
      where: { is_default: true, user_id: userId },
      relations: ['performance_profiles', 'fuel_tanks', 'equipment'],
    });
  }

  async create(dto: CreateAircraftDto, userId: string): Promise<Aircraft> {
    // Look up master profile by ICAO type code
    let masterProfile: MasterWBProfile | null = null;
    if (dto.icao_type_code) {
      masterProfile = await this.masterProfileRepo.findOne({
        where: { icao_type_code: dto.icao_type_code },
      });
    }

    // Apply aircraft_defaults for fields the user didn't provide
    const data: Partial<Aircraft> = { ...dto, user_id: userId };
    if (masterProfile?.aircraft_defaults) {
      const defaults = masterProfile.aircraft_defaults;
      for (const [key, value] of Object.entries(defaults)) {
        if (value != null && data[key] == null) {
          data[key] = value;
        }
      }
    }

    const aircraft = this.aircraftRepo.create(data);
    const saved = await this.aircraftRepo.save(aircraft);

    // Clone master profile data (fuel tanks, perf profiles, W&B profiles)
    if (masterProfile) {
      await this.cloneMasterProfile(saved, masterProfile);
      return this.findOne(saved.id, userId);
    }

    return saved;
  }

  async update(
    id: number,
    dto: UpdateAircraftDto,
    userId: string,
  ): Promise<Aircraft> {
    const aircraft = await this.findOne(id, userId);
    Object.assign(aircraft, dto);
    return this.aircraftRepo.save(aircraft);
  }

  async remove(id: number, userId: string): Promise<void> {
    const aircraft = await this.findOne(id, userId);
    await this.aircraftRepo.remove(aircraft);
  }

  async setDefault(id: number, userId: string): Promise<Aircraft> {
    // Clear all defaults for this user
    await this.aircraftRepo.update({ user_id: userId }, { is_default: false });
    // Set new default
    await this.aircraftRepo.update(id, { is_default: true });
    return this.findOne(id, userId);
  }

  // --- Master Profile Clone ---

  private async cloneMasterProfile(
    aircraft: Aircraft,
    master: MasterWBProfile,
  ): Promise<void> {
    try {
      // 1. Create fuel tanks → build index-to-ID mapping
      const tankIndexToId = new Map<number, number>();
      if (master.fuel_tanks?.length) {
        for (let i = 0; i < master.fuel_tanks.length; i++) {
          const t = master.fuel_tanks[i];
          const tank = await this.tankRepo.save(
            this.tankRepo.create({
              aircraft_id: aircraft.id,
              name: t.name,
              capacity_gallons: t.capacity_gallons,
              tab_fuel_gallons: t.tab_fuel_gallons,
              sort_order: t.sort_order,
            }),
          );
          tankIndexToId.set(i, tank.id);
        }
      }

      // 2. Create performance profiles
      if (master.performance_profiles?.length) {
        for (const pp of master.performance_profiles) {
          await this.profileRepo.save(
            this.profileRepo.create({
              aircraft_id: aircraft.id,
              name: pp.name,
              is_default: pp.is_default ?? false,
              cruise_tas: pp.cruise_tas,
              cruise_fuel_burn: pp.cruise_fuel_burn,
              climb_rate: pp.climb_rate,
              climb_speed: pp.climb_speed,
              climb_fuel_flow: pp.climb_fuel_flow,
              descent_rate: pp.descent_rate,
              descent_speed: pp.descent_speed,
              descent_fuel_flow: pp.descent_fuel_flow,
              takeoff_data: pp.takeoff_data,
              landing_data: pp.landing_data,
            }),
          );
        }
      }

      // 3. Create W&B profiles with stations and envelopes
      if (master.wb_profiles?.length) {
        for (const wp of master.wb_profiles) {
          const moment =
            wp.empty_weight_moment ?? wp.empty_weight * wp.empty_weight_arm;
          const lateralMoment =
            wp.empty_weight_lateral_moment ??
            (wp.empty_weight_lateral_arm != null
              ? wp.empty_weight * wp.empty_weight_lateral_arm
              : undefined);

          const wbProfile = await this.wbProfileRepo.save(
            this.wbProfileRepo.create({
              aircraft_id: aircraft.id,
              name: wp.name,
              is_default: wp.is_default ?? false,
              datum_description: wp.datum_description,
              lateral_cg_enabled: wp.lateral_cg_enabled ?? false,
              empty_weight: wp.empty_weight,
              empty_weight_arm: wp.empty_weight_arm,
              empty_weight_moment: moment,
              empty_weight_lateral_arm: wp.empty_weight_lateral_arm,
              empty_weight_lateral_moment: lateralMoment,
              max_ramp_weight: wp.max_ramp_weight,
              max_takeoff_weight: wp.max_takeoff_weight,
              max_landing_weight: wp.max_landing_weight,
              max_zero_fuel_weight: wp.max_zero_fuel_weight,
              fuel_arm: wp.fuel_arm,
              fuel_lateral_arm: wp.fuel_lateral_arm,
              taxi_fuel_gallons: wp.taxi_fuel_gallons,
              notes: wp.notes,
            } as Partial<WBProfile>),
          );

          // Create stations (mapping fuel_tank_index → real fuel_tank_id)
          if (wp.stations?.length) {
            for (const st of wp.stations) {
              const fuelTankId =
                st.fuel_tank_index != null
                  ? tankIndexToId.get(st.fuel_tank_index)
                  : undefined;

              await this.wbStationRepo.save(
                this.wbStationRepo.create({
                  wb_profile_id: wbProfile.id,
                  name: st.name,
                  category: st.category,
                  arm: st.arm,
                  lateral_arm: st.lateral_arm,
                  max_weight: st.max_weight,
                  default_weight: st.default_weight,
                  fuel_tank_id: fuelTankId,
                  sort_order: st.sort_order,
                  group_name: st.group_name,
                }),
              );
            }
          }

          // Create envelopes
          if (wp.envelopes?.length) {
            for (const env of wp.envelopes) {
              await this.wbEnvelopeRepo.save(
                this.wbEnvelopeRepo.create({
                  wb_profile_id: wbProfile.id,
                  envelope_type: env.envelope_type,
                  axis: env.axis,
                  points: env.points,
                }),
              );
            }
          }
        }
      }

      this.logger.log(
        `Cloned master profile "${master.display_name}" for aircraft #${aircraft.id}`,
      );
    } catch (err) {
      this.logger.error(
        `Failed to clone master profile for aircraft #${aircraft.id}: ${err.message}`,
      );
    }
  }

  // --- Performance Profiles ---

  async findProfiles(
    aircraftId: number,
    userId?: string,
  ): Promise<PerformanceProfile[]> {
    await this.findOne(aircraftId, userId);
    return this.profileRepo.find({
      where: { aircraft_id: aircraftId },
      order: { is_default: 'DESC', name: 'ASC' },
    });
  }

  async createProfile(
    aircraftId: number,
    dto: CreatePerformanceProfileDto,
    userId?: string,
  ): Promise<PerformanceProfile> {
    await this.findOne(aircraftId, userId);
    const profile = this.profileRepo.create({
      ...dto,
      aircraft_id: aircraftId,
    });
    return this.profileRepo.save(profile);
  }

  async updateProfile(
    aircraftId: number,
    profileId: number,
    dto: UpdatePerformanceProfileDto,
    userId?: string,
  ): Promise<PerformanceProfile> {
    await this.findOne(aircraftId, userId);
    const profile = await this.profileRepo.findOne({
      where: { id: profileId, aircraft_id: aircraftId },
    });
    if (!profile)
      throw new NotFoundException(`Profile #${profileId} not found`);
    Object.assign(profile, dto);
    return this.profileRepo.save(profile);
  }

  async removeProfile(
    aircraftId: number,
    profileId: number,
    userId?: string,
  ): Promise<void> {
    await this.findOne(aircraftId, userId);
    const profile = await this.profileRepo.findOne({
      where: { id: profileId, aircraft_id: aircraftId },
    });
    if (!profile)
      throw new NotFoundException(`Profile #${profileId} not found`);
    await this.profileRepo.remove(profile);
  }

  async setDefaultProfile(
    aircraftId: number,
    profileId: number,
    userId?: string,
  ): Promise<PerformanceProfile> {
    await this.findOne(aircraftId, userId);
    await this.profileRepo.update(
      { aircraft_id: aircraftId },
      { is_default: false },
    );
    await this.profileRepo.update(
      { id: profileId, aircraft_id: aircraftId },
      { is_default: true },
    );
    const profile = await this.profileRepo.findOne({
      where: { id: profileId, aircraft_id: aircraftId },
    });
    if (!profile)
      throw new NotFoundException(`Profile #${profileId} not found`);
    return profile;
  }

  async applyTemplate(
    aircraftId: number,
    profileId: number,
    templateType: string,
    userId?: string,
  ): Promise<PerformanceProfile> {
    await this.findOne(aircraftId, userId);
    const profile = await this.profileRepo.findOne({
      where: { id: profileId, aircraft_id: aircraftId },
    });
    if (!profile)
      throw new NotFoundException(`Profile #${profileId} not found`);

    const templates: Record<string, { takeoff: object; landing: object }> = {
      tbm960: {
        takeoff: TBM960_TAKEOFF_DATA,
        landing: TBM960_LANDING_DATA,
      },
    };

    const tmpl = templates[templateType];
    if (!tmpl)
      throw new NotFoundException(`Template "${templateType}" not found`);

    profile.takeoff_data = JSON.stringify(tmpl.takeoff);
    profile.landing_data = JSON.stringify(tmpl.landing);
    return this.profileRepo.save(profile);
  }

  // --- Fuel Tanks ---

  async findTanks(aircraftId: number, userId?: string): Promise<FuelTank[]> {
    await this.findOne(aircraftId, userId);
    return this.tankRepo.find({
      where: { aircraft_id: aircraftId },
      order: { sort_order: 'ASC' },
    });
  }

  async createTank(
    aircraftId: number,
    dto: CreateFuelTankDto,
    userId?: string,
  ): Promise<FuelTank> {
    await this.findOne(aircraftId, userId);
    const tank = this.tankRepo.create({ ...dto, aircraft_id: aircraftId });
    return this.tankRepo.save(tank);
  }

  async updateTank(
    aircraftId: number,
    tankId: number,
    dto: UpdateFuelTankDto,
    userId?: string,
  ): Promise<FuelTank> {
    await this.findOne(aircraftId, userId);
    const tank = await this.tankRepo.findOne({
      where: { id: tankId, aircraft_id: aircraftId },
    });
    if (!tank) throw new NotFoundException(`Fuel tank #${tankId} not found`);
    Object.assign(tank, dto);
    return this.tankRepo.save(tank);
  }

  async removeTank(
    aircraftId: number,
    tankId: number,
    userId?: string,
  ): Promise<void> {
    await this.findOne(aircraftId, userId);
    const tank = await this.tankRepo.findOne({
      where: { id: tankId, aircraft_id: aircraftId },
    });
    if (!tank) throw new NotFoundException(`Fuel tank #${tankId} not found`);
    await this.tankRepo.remove(tank);
  }

  // --- Equipment ---

  async findEquipment(
    aircraftId: number,
    userId?: string,
  ): Promise<Equipment | null> {
    await this.findOne(aircraftId, userId);
    return this.equipmentRepo.findOne({
      where: { aircraft_id: aircraftId },
    });
  }

  async upsertEquipment(
    aircraftId: number,
    dto: UpdateEquipmentDto,
    userId?: string,
  ): Promise<Equipment> {
    await this.findOne(aircraftId, userId);
    let equipment = await this.equipmentRepo.findOne({
      where: { aircraft_id: aircraftId },
    });
    if (equipment) {
      Object.assign(equipment, dto);
    } else {
      equipment = this.equipmentRepo.create({
        ...dto,
        aircraft_id: aircraftId,
      });
    }
    return this.equipmentRepo.save(equipment);
  }
}
