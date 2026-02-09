import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { FaaRegistryAircraft } from './entities/faa-registry-aircraft.entity';

@Injectable()
export class RegistryService {
  constructor(
    @InjectRepository(FaaRegistryAircraft)
    private readonly repo: Repository<FaaRegistryAircraft>,
  ) {}

  async lookup(nNumber: string) {
    // Normalize: strip "N" prefix, uppercase, trim
    let normalized = nNumber.trim().toUpperCase();
    if (normalized.startsWith('N')) {
      normalized = normalized.substring(1);
    }

    const record = await this.repo.findOne({
      where: { n_number: normalized },
    });

    if (!record) {
      throw new NotFoundException(`N-number ${nNumber} not found in registry`);
    }

    // Derive friendly aircraft_type from manufacturer + model
    const manufacturer = (record.manufacturer || '').trim();
    const model = (record.model || '').trim();
    const aircraftType = [manufacturer, model].filter(Boolean).join(' ');

    // Derive category from type_aircraft code
    // 1=Glider, 2=Balloon, 3=Blimp, 4=Fixed wing single, 5=Fixed wing multi,
    // 6=Rotorcraft, 7=Weight-shift, 8=Powered parachute, 9=Gyroplane
    const category = this.deriveCategory(record.type_aircraft);

    // Derive fuel_type from type_engine code
    // 0=None, 1=Reciprocating, 2=Turbo-prop, 3=Turbo-shaft, 4=Turbo-jet,
    // 5=Turbo-fan, 6=Ramjet, 7=2 Cycle, 8=4 Cycle, 9=Unknown, 10=Electric, 11=Rotary
    const fuelType = this.deriveFuelType(record.type_engine);

    return {
      n_number: record.n_number,
      aircraft_type: aircraftType || undefined,
      manufacturer: manufacturer || undefined,
      model: model || undefined,
      serial_number: record.serial_number || undefined,
      year_mfr: record.year_mfr || undefined,
      category,
      fuel_type: fuelType,
      num_engines: record.num_engines || undefined,
      num_seats: record.num_seats || undefined,
      cruising_speed_mph: record.cruising_speed_mph || undefined,
      engine_manufacturer: record.engine_manufacturer || undefined,
      engine_model: record.engine_model || undefined,
      horsepower: record.horsepower || undefined,
      thrust: record.thrust || undefined,
      type_aircraft: record.type_aircraft || undefined,
      type_engine: record.type_engine || undefined,
      mode_s_code_hex: record.mode_s_code_hex || undefined,
    };
  }

  private deriveCategory(typeAircraft: string | null): string {
    switch (typeAircraft) {
      case '4':
      case '5':
        return 'landplane';
      case '6':
        return 'helicopter';
      case '1':
        return 'glider';
      case '2':
        return 'balloon';
      case '9':
        return 'gyroplane';
      default:
        return 'landplane';
    }
  }

  private deriveFuelType(typeEngine: string | null): string {
    switch (typeEngine) {
      case '1':
      case '7':
      case '8':
      case '11':
        return '100ll';
      case '2':
      case '3':
      case '4':
      case '5':
      case '6':
        return 'jet_a';
      case '10':
        return 'electric';
      default:
        return '100ll';
    }
  }
}
