import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Flight } from './entities/flight.entity';
import { CreateFlightDto } from './dto/create-flight.dto';
import { UpdateFlightDto } from './dto/update-flight.dto';

@Injectable()
export class FlightsService {
  constructor(
    @InjectRepository(Flight)
    private flightRepo: Repository<Flight>,
  ) {}

  async findAll(query?: string, limit = 50, offset = 0) {
    const qb = this.flightRepo.createQueryBuilder('flight');

    if (query) {
      const q = `%${query}%`;
      qb.where(
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

  async findById(id: number) {
    const flight = await this.flightRepo.findOne({ where: { id } });
    if (!flight) {
      throw new NotFoundException(`Flight ${id} not found`);
    }
    return flight;
  }

  async create(dto: CreateFlightDto) {
    const flight = this.flightRepo.create(dto);
    return this.flightRepo.save(flight);
  }

  async update(id: number, dto: UpdateFlightDto) {
    const flight = await this.findById(id);
    Object.assign(flight, dto);
    return this.flightRepo.save(flight);
  }

  async remove(id: number) {
    const flight = await this.findById(id);
    return this.flightRepo.remove(flight);
  }

  async copy(id: number) {
    const source = await this.findById(id);
    const copy = this.flightRepo.create({
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
    });
    return this.flightRepo.save(copy);
  }
}
