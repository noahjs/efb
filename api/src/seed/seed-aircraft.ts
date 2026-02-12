/**
 * Aircraft Seed Script
 *
 * Seeds a TBM 960 with performance profiles, fuel tanks, and equipment.
 *
 * Usage: npm run seed:aircraft
 */

import { DataSource } from 'typeorm';
import { Aircraft } from '../aircraft/entities/aircraft.entity';
import { PerformanceProfile } from '../aircraft/entities/performance-profile.entity';
import { FuelTank } from '../aircraft/entities/fuel-tank.entity';
import { Equipment } from '../aircraft/entities/equipment.entity';
import { User } from '../users/entities/user.entity';
import { StarredAirport } from '../users/entities/starred-airport.entity';
import { dbConfig } from '../db.config';
import {
  TBM960_TAKEOFF_DATA,
  TBM960_LANDING_DATA,
} from '../aircraft/seed/tbm960-performance';

const DEMO_USER_ID = '00000000-0000-0000-0000-000000000001';

async function main() {
  console.log('=== EFB Aircraft Seed ===\n');

  const ds = new DataSource({
    ...dbConfig,
    entities: [
      Aircraft,
      PerformanceProfile,
      FuelTank,
      Equipment,
      User,
      StarredAirport,
    ],
  });

  await ds.initialize();
  console.log('Database initialized.\n');

  const aircraftRepo = ds.getRepository(Aircraft);
  const profileRepo = ds.getRepository(PerformanceProfile);
  const tankRepo = ds.getRepository(FuelTank);
  const equipmentRepo = ds.getRepository(Equipment);

  // Check if already seeded
  const existing = await aircraftRepo.findOne({
    where: { tail_number: 'N977CA' },
  });
  if (existing) {
    console.log('TBM 960 (N977CA) already exists, clearing for re-seed...');
    await aircraftRepo.remove(existing);
  }

  // Create aircraft
  console.log('Seeding TBM 960...');
  const aircraft = await aircraftRepo.save({
    user_id: DEMO_USER_ID,
    tail_number: 'N977CA',
    aircraft_type: 'TBM 960',
    icao_type_code: 'TBM9',
    category: 'landplane',
    fuel_type: 'jet_a',
    total_usable_fuel: 291,
    best_glide_speed: 120,
    glide_ratio: 13.8,
    is_default: true,
    home_airport: 'BJC',
    airspeed_units: 'knots',
    length_units: 'inches',
  } as Partial<Aircraft>);
  console.log(`  Created aircraft #${aircraft.id}: ${aircraft.tail_number}\n`);

  // Performance profiles
  console.log('Seeding performance profiles...');
  const profiles = await profileRepo.save([
    {
      aircraft_id: aircraft.id,
      name: 'Maximum Cruise',
      is_default: true,
      cruise_tas: 330,
      cruise_fuel_burn: 60,
      climb_rate: 1500,
      climb_speed: 124,
      climb_fuel_flow: 75,
      descent_rate: 1500,
      descent_speed: 200,
      descent_fuel_flow: 20,
      takeoff_data: JSON.stringify(TBM960_TAKEOFF_DATA),
      landing_data: JSON.stringify(TBM960_LANDING_DATA),
    },
    {
      aircraft_id: aircraft.id,
      name: 'Economy Cruise',
      is_default: false,
      cruise_tas: 280,
      cruise_fuel_burn: 45,
      climb_rate: 1200,
      climb_speed: 124,
      climb_fuel_flow: 70,
      descent_rate: 1500,
      descent_speed: 180,
      descent_fuel_flow: 18,
    },
    {
      aircraft_id: aircraft.id,
      name: 'Long Range Cruise',
      is_default: false,
      cruise_tas: 252,
      cruise_fuel_burn: 38,
      climb_rate: 1000,
      climb_speed: 120,
      climb_fuel_flow: 65,
      descent_rate: 1500,
      descent_speed: 170,
      descent_fuel_flow: 16,
    },
  ] as Partial<PerformanceProfile>[]);
  console.log(`  Created ${profiles.length} profiles.\n`);

  // Fuel tanks
  console.log('Seeding fuel tanks...');
  const tanks = await tankRepo.save([
    {
      aircraft_id: aircraft.id,
      name: 'Left Wing',
      capacity_gallons: 145.5,
      tab_fuel_gallons: 73,
      sort_order: 0,
    },
    {
      aircraft_id: aircraft.id,
      name: 'Right Wing',
      capacity_gallons: 145.5,
      tab_fuel_gallons: 73,
      sort_order: 1,
    },
  ] as Partial<FuelTank>[]);
  console.log(`  Created ${tanks.length} fuel tanks.\n`);

  // Equipment
  console.log('Seeding equipment...');
  await equipmentRepo.save({
    aircraft_id: aircraft.id,
    gps_type: 'WAAS GPS',
    transponder_type: 'Mode S',
    adsb_compliance: 'ADS-B Out',
    equipment_codes: 'G/S',
    installed_avionics: 'Garmin G3000',
  } as Partial<Equipment>);
  console.log('  Created equipment record.\n');

  // Summary
  console.log('=== Seed Complete ===');
  console.log(
    `  Aircraft:    ${aircraft.tail_number} (${aircraft.aircraft_type})`,
  );
  console.log(`  Profiles:    ${profiles.length}`);
  console.log(`  Fuel Tanks:  ${tanks.length}`);
  console.log('  Equipment:   1');

  await ds.destroy();
}

main().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
