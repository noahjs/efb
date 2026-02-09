import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, ILike } from 'typeorm';
import { Aircraft } from './entities/aircraft.entity';
import { PerformanceProfile } from './entities/performance-profile.entity';
import { FuelTank } from './entities/fuel-tank.entity';
import { Equipment } from './entities/equipment.entity';
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
  constructor(
    @InjectRepository(Aircraft)
    private readonly aircraftRepo: Repository<Aircraft>,
    @InjectRepository(PerformanceProfile)
    private readonly profileRepo: Repository<PerformanceProfile>,
    @InjectRepository(FuelTank)
    private readonly tankRepo: Repository<FuelTank>,
    @InjectRepository(Equipment)
    private readonly equipmentRepo: Repository<Equipment>,
  ) {}

  // --- Aircraft CRUD ---

  async findAll(query?: string, limit = 50, offset = 0) {
    const where = query
      ? [
          { tail_number: ILike(`%${query}%`) },
          { aircraft_type: ILike(`%${query}%`) },
          { icao_type_code: ILike(`%${query}%`) },
        ]
      : undefined;

    const [items, total] = await this.aircraftRepo.findAndCount({
      where,
      order: { is_default: 'DESC', updated_at: 'DESC' },
      take: limit,
      skip: offset,
    });

    return { items, total };
  }

  async findOne(id: number): Promise<Aircraft> {
    const aircraft = await this.aircraftRepo.findOne({
      where: { id },
      relations: ['performance_profiles', 'fuel_tanks', 'equipment'],
    });
    if (!aircraft) throw new NotFoundException(`Aircraft #${id} not found`);
    return aircraft;
  }

  async findDefault(): Promise<Aircraft | null> {
    return this.aircraftRepo.findOne({
      where: { is_default: true },
      relations: ['performance_profiles', 'fuel_tanks', 'equipment'],
    });
  }

  async create(dto: CreateAircraftDto): Promise<Aircraft> {
    const aircraft = this.aircraftRepo.create(dto);
    return this.aircraftRepo.save(aircraft);
  }

  async update(id: number, dto: UpdateAircraftDto): Promise<Aircraft> {
    const aircraft = await this.findOne(id);
    Object.assign(aircraft, dto);
    return this.aircraftRepo.save(aircraft);
  }

  async remove(id: number): Promise<void> {
    const aircraft = await this.findOne(id);
    await this.aircraftRepo.remove(aircraft);
  }

  async setDefault(id: number): Promise<Aircraft> {
    // Clear all defaults
    await this.aircraftRepo.update({}, { is_default: false });
    // Set new default
    await this.aircraftRepo.update(id, { is_default: true });
    return this.findOne(id);
  }

  // --- Performance Profiles ---

  async findProfiles(aircraftId: number): Promise<PerformanceProfile[]> {
    return this.profileRepo.find({
      where: { aircraft_id: aircraftId },
      order: { is_default: 'DESC', name: 'ASC' },
    });
  }

  async createProfile(
    aircraftId: number,
    dto: CreatePerformanceProfileDto,
  ): Promise<PerformanceProfile> {
    await this.findOne(aircraftId); // ensure aircraft exists
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
  ): Promise<PerformanceProfile> {
    const profile = await this.profileRepo.findOne({
      where: { id: profileId, aircraft_id: aircraftId },
    });
    if (!profile)
      throw new NotFoundException(`Profile #${profileId} not found`);
    Object.assign(profile, dto);
    return this.profileRepo.save(profile);
  }

  async removeProfile(aircraftId: number, profileId: number): Promise<void> {
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
  ): Promise<PerformanceProfile> {
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
  ): Promise<PerformanceProfile> {
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

  async findTanks(aircraftId: number): Promise<FuelTank[]> {
    return this.tankRepo.find({
      where: { aircraft_id: aircraftId },
      order: { sort_order: 'ASC' },
    });
  }

  async createTank(
    aircraftId: number,
    dto: CreateFuelTankDto,
  ): Promise<FuelTank> {
    await this.findOne(aircraftId);
    const tank = this.tankRepo.create({ ...dto, aircraft_id: aircraftId });
    return this.tankRepo.save(tank);
  }

  async updateTank(
    aircraftId: number,
    tankId: number,
    dto: UpdateFuelTankDto,
  ): Promise<FuelTank> {
    const tank = await this.tankRepo.findOne({
      where: { id: tankId, aircraft_id: aircraftId },
    });
    if (!tank) throw new NotFoundException(`Fuel tank #${tankId} not found`);
    Object.assign(tank, dto);
    return this.tankRepo.save(tank);
  }

  async removeTank(aircraftId: number, tankId: number): Promise<void> {
    const tank = await this.tankRepo.findOne({
      where: { id: tankId, aircraft_id: aircraftId },
    });
    if (!tank) throw new NotFoundException(`Fuel tank #${tankId} not found`);
    await this.tankRepo.remove(tank);
  }

  // --- Equipment ---

  async findEquipment(aircraftId: number): Promise<Equipment | null> {
    return this.equipmentRepo.findOne({
      where: { aircraft_id: aircraftId },
    });
  }

  async upsertEquipment(
    aircraftId: number,
    dto: UpdateEquipmentDto,
  ): Promise<Equipment> {
    await this.findOne(aircraftId);
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
