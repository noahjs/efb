import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Flight } from './entities/flight.entity';
import { CreateFlightDto } from './dto/create-flight.dto';
import { UpdateFlightDto } from './dto/update-flight.dto';
import { CalculateService } from '../calculate/calculate.service';

@Injectable()
export class FlightsService {
  constructor(
    @InjectRepository(Flight)
    private flightRepo: Repository<Flight>,
    private calculateService: CalculateService,
  ) {}

  async findAll(userId: string, query?: string, limit = 50, offset = 0) {
    const qb = this.flightRepo.createQueryBuilder('flight');

    qb.where('(flight.user_id = :userId OR flight.user_id IS NULL)', {
      userId,
    });

    if (query) {
      const q = `%${query}%`;
      qb.andWhere(
        '(flight.departure_identifier LIKE :q OR flight.destination_identifier LIKE :q OR flight.aircraft_identifier LIKE :q OR flight.route_string LIKE :q)',
        { q },
      );
    }

    qb.orderBy('flight.etd', 'DESC')
      .addOrderBy('flight.created_at', 'DESC')
      .skip(offset)
      .take(limit);

    const [items, total] = await qb.getManyAndCount();
    return { items, total, limit, offset };
  }

  async findById(id: number, userId?: string) {
    const where: any = { id };
    if (userId) {
      where.user_id = userId;
    }
    const flight = await this.flightRepo.findOne({ where });
    if (!flight) {
      throw new NotFoundException(`Flight ${id} not found`);
    }
    return flight;
  }

  async create(dto: CreateFlightDto, userId?: string) {
    const flight = this.flightRepo.create({ ...dto, user_id: userId });
    await this.calculate(flight);
    return this.flightRepo.save(flight);
  }

  async update(id: number, dto: UpdateFlightDto, userId?: string) {
    const flight = await this.findById(id, userId);
    Object.assign(flight, dto);
    await this.calculate(flight);
    return this.flightRepo.save(flight);
  }

  /**
   * Compute distance_nm, ete_minutes, eta, and flight_fuel_gallons from
   * the flight's route_string, true_airspeed, etd, and fuel_burn_rate.
   */
  private async calculate(flight: Flight) {
    const result = await this.calculateService.calculate({
      departure_identifier: flight.departure_identifier,
      destination_identifier: flight.destination_identifier,
      route_string: flight.route_string,
      cruise_altitude: flight.cruise_altitude,
      true_airspeed: flight.true_airspeed,
      fuel_burn_rate: flight.fuel_burn_rate,
      etd: flight.etd,
      performance_profile_id: flight.performance_profile_id,
    });

    (flight as any).distance_nm = result.distance_nm;
    (flight as any).ete_minutes = result.ete_minutes;
    (flight as any).flight_fuel_gallons = result.flight_fuel_gallons;
    (flight as any).eta = result.eta;
    flight.calculated_at = result.calculated_at;
  }

  /**
   * Return a step-by-step breakdown of the calculation for debugging.
   */
  async calculateDebug(id: number, userId?: string) {
    const flight = await this.findById(id, userId);
    return this.calculateService.calculateDebug({
      departure_identifier: flight.departure_identifier,
      destination_identifier: flight.destination_identifier,
      route_string: flight.route_string,
      cruise_altitude: flight.cruise_altitude,
      true_airspeed: flight.true_airspeed,
      fuel_burn_rate: flight.fuel_burn_rate,
      etd: flight.etd,
      performance_profile_id: flight.performance_profile_id,
    });
  }

  async remove(id: number, userId?: string) {
    const flight = await this.findById(id, userId);
    return this.flightRepo.remove(flight);
  }

  async copy(id: number, userId?: string) {
    const source = await this.findById(id, userId);
    const copy = this.flightRepo.create({
      user_id: userId,
      departure_identifier: source.departure_identifier,
      destination_identifier: source.destination_identifier,
      alternate_identifier: source.alternate_identifier,
      etd: source.etd,
      aircraft_identifier: source.aircraft_identifier,
      aircraft_type: source.aircraft_type,
      performance_profile: source.performance_profile,
      true_airspeed: source.true_airspeed,
      flight_rules: source.flight_rules,
      route_string: source.route_string,
      cruise_altitude: source.cruise_altitude,
      people_count: source.people_count,
      avg_person_weight: source.avg_person_weight,
      cargo_weight: source.cargo_weight,
      fuel_policy: source.fuel_policy,
      start_fuel_gallons: source.start_fuel_gallons,
      reserve_fuel_gallons: source.reserve_fuel_gallons,
      fuel_burn_rate: source.fuel_burn_rate,
      filing_status: 'not_filed',
      performance_profile_id: source.performance_profile_id,
    });
    await this.calculate(copy);
    return this.flightRepo.save(copy);
  }
}
