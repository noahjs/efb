/**
 * Aircraft Seed Script
 *
 * Seeds demo aircraft with performance profiles, fuel tanks, equipment,
 * and weight & balance configurations.
 *
 * Aircraft:
 *   1. TBM 960 (N977CA) — turboprop, 6-seat W&B, CG envelope
 *   2. AS350B3 (N174AH) — helicopter, lateral CG, dual envelopes
 *
 * Usage: npm run seed:aircraft
 */

import { DataSource } from 'typeorm';
import { Aircraft } from '../aircraft/entities/aircraft.entity';
import { PerformanceProfile } from '../aircraft/entities/performance-profile.entity';
import { FuelTank } from '../aircraft/entities/fuel-tank.entity';
import { Equipment } from '../aircraft/entities/equipment.entity';
import { WBProfile } from '../weight-balance/entities/wb-profile.entity';
import { WBStation } from '../weight-balance/entities/wb-station.entity';
import { WBEnvelope } from '../weight-balance/entities/wb-envelope.entity';
import { WBScenario } from '../weight-balance/entities/wb-scenario.entity';
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
      WBProfile,
      WBStation,
      WBEnvelope,
      WBScenario,
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
  const wbProfileRepo = ds.getRepository(WBProfile);
  const wbStationRepo = ds.getRepository(WBStation);
  const wbEnvelopeRepo = ds.getRepository(WBEnvelope);

  // Clear existing demo aircraft for re-seed
  for (const tail of ['N977CA', 'N174AH']) {
    const existing = await aircraftRepo.findOne({
      where: { tail_number: tail },
    });
    if (existing) {
      console.log(`${tail} already exists, clearing for re-seed...`);
      await aircraftRepo.remove(existing);
    }
  }

  // Reset sequences past any existing rows to avoid PK conflicts on re-seed
  const seqTables = [
    'u_aircraft',
    'u_performance_profiles',
    'u_fuel_tanks',
    'u_equipment',
    'u_wb_profiles',
    'u_wb_stations',
    'u_wb_envelopes',
  ];
  for (const table of seqTables) {
    await ds.query(
      `SELECT setval('${table}_id_seq', COALESCE((SELECT MAX(id) FROM "${table}"), 0) + 1, false)`,
    );
  }

  // ─── TBM 960 ──────────────────────────────────────────────────────────

  console.log('Seeding TBM 960 (N977CA)...');
  const tbm = await aircraftRepo.save({
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
  console.log(`  Created aircraft #${tbm.id}: ${tbm.tail_number}`);

  // Performance profiles
  const tbmProfiles = await profileRepo.save([
    {
      aircraft_id: tbm.id,
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
      aircraft_id: tbm.id,
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
      aircraft_id: tbm.id,
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
  console.log(`  Created ${tbmProfiles.length} performance profiles.`);

  // Fuel tanks
  const tbmTanks = await tankRepo.save([
    {
      aircraft_id: tbm.id,
      name: 'Left Wing',
      capacity_gallons: 145.5,
      tab_fuel_gallons: 73,
      sort_order: 0,
    },
    {
      aircraft_id: tbm.id,
      name: 'Right Wing',
      capacity_gallons: 145.5,
      tab_fuel_gallons: 73,
      sort_order: 1,
    },
  ] as Partial<FuelTank>[]);
  console.log(`  Created ${tbmTanks.length} fuel tanks.`);

  // Equipment
  await equipmentRepo.save({
    aircraft_id: tbm.id,
    gps_type: 'WAAS GPS',
    transponder_type: 'Mode S',
    adsb_compliance: 'ADS-B Out',
    equipment_codes: 'G/S',
    installed_avionics: 'Garmin G3000',
  } as Partial<Equipment>);
  console.log('  Created equipment record.');

  // W&B profile
  const TBM_BEW = 4784;
  const TBM_BEW_ARM = 186.4;

  const tbmWB = await wbProfileRepo.save({
    aircraft_id: tbm.id,
    name: '6-Seat Standard',
    is_default: true,
    datum_description: 'Forward face of firewall',
    lateral_cg_enabled: false,
    empty_weight: TBM_BEW,
    empty_weight_arm: TBM_BEW_ARM,
    empty_weight_moment: TBM_BEW * TBM_BEW_ARM,
    fuel_arm: 189.8,
    max_ramp_weight: 7650,
    max_takeoff_weight: 7615,
    max_landing_weight: 7110,
    max_zero_fuel_weight: 6252,
    taxi_fuel_gallons: 5.0,
    notes: 'TBM 960 6-seat configuration. BEW from sample weighing report.',
  } as Partial<WBProfile>);
  console.log(`  Created W&B profile: ${tbmWB.name}`);

  // Stations: 6 seats, 2 baggage, 2 fuel (linked to tanks)
  const tbmStations = await wbStationRepo.save([
    {
      wb_profile_id: tbmWB.id,
      name: 'Pilot',
      category: 'seat',
      arm: 178.5,
      default_weight: 170,
      sort_order: 0,
      group_name: 'Flight Deck',
    },
    {
      wb_profile_id: tbmWB.id,
      name: 'Copilot',
      category: 'seat',
      arm: 178.5,
      sort_order: 1,
      group_name: 'Flight Deck',
    },
    {
      wb_profile_id: tbmWB.id,
      name: 'Left Seat',
      category: 'seat',
      arm: 224.8,
      sort_order: 2,
      group_name: 'Intermediate Row',
    },
    {
      wb_profile_id: tbmWB.id,
      name: 'Right Seat',
      category: 'seat',
      arm: 224.8,
      sort_order: 3,
      group_name: 'Intermediate Row',
    },
    {
      wb_profile_id: tbmWB.id,
      name: 'Back Left Seat',
      category: 'seat',
      arm: 267.1,
      sort_order: 4,
      group_name: 'Aft Row',
    },
    {
      wb_profile_id: tbmWB.id,
      name: 'Back Right Seat',
      category: 'seat',
      arm: 267.1,
      sort_order: 5,
      group_name: 'Aft Row',
    },
    {
      wb_profile_id: tbmWB.id,
      name: 'Forward Baggage',
      category: 'baggage',
      arm: 128,
      max_weight: 55,
      sort_order: 6,
      group_name: 'Baggage',
    },
    {
      wb_profile_id: tbmWB.id,
      name: 'Aft Baggage',
      category: 'baggage',
      arm: 303,
      max_weight: 220,
      sort_order: 7,
      group_name: 'Baggage',
    },
    {
      wb_profile_id: tbmWB.id,
      name: 'Left Wing Fuel',
      category: 'fuel',
      arm: 189.8,
      fuel_tank_id: tbmTanks[0].id,
      sort_order: 8,
      group_name: 'Fuel',
    },
    {
      wb_profile_id: tbmWB.id,
      name: 'Right Wing Fuel',
      category: 'fuel',
      arm: 189.8,
      fuel_tank_id: tbmTanks[1].id,
      sort_order: 9,
      group_name: 'Fuel',
    },
  ] as Partial<WBStation>[]);
  console.log(`  Created ${tbmStations.length} W&B stations.`);

  // CG envelope — normal category, longitudinal
  // Forward limit tightens (moves aft) as weight increases; aft limit ~194 in
  await wbEnvelopeRepo.save({
    wb_profile_id: tbmWB.id,
    envelope_type: 'normal',
    axis: 'longitudinal',
    points: [
      { weight: 3748, cg: 181.3 },
      { weight: 4409, cg: 181.3 },
      { weight: 6250, cg: 183.6 },
      { weight: 6579, cg: 185.3 },
      { weight: 7024, cg: 187.1 },
      { weight: 7394, cg: 187.1 },
      { weight: 7430, cg: 187.1 },
      { weight: 7615, cg: 193.6 },
      { weight: 7394, cg: 193.7 },
      { weight: 6986, cg: 194.0 },
      { weight: 3748, cg: 194.0 },
    ],
  } as Partial<WBEnvelope>);
  console.log('  Created CG envelope (normal/longitudinal).');
  console.log('');

  // ─── AS350B3 Helicopter ───────────────────────────────────────────────

  console.log('Seeding AS350B3 (N174AH)...');
  const as350 = await aircraftRepo.save({
    user_id: DEMO_USER_ID,
    tail_number: 'N174AH',
    aircraft_type: 'AIRBUS HELICOPTERS INC AS350B3',
    serial_number: '9121',
    category: 'helicopter',
    fuel_type: 'jet_a',
    is_default: false,
    airspeed_units: 'knots',
    length_units: 'inches',
  } as Partial<Aircraft>);
  console.log(`  Created aircraft #${as350.id}: ${as350.tail_number}`);

  // W&B profile (with lateral CG)
  const AS350_BEW = 3201;
  const AS350_BEW_ARM = 137.2;
  const AS350_BEW_LAT_ARM = 1.3;

  const as350WB = await wbProfileRepo.save({
    aircraft_id: as350.id,
    name: 'Standard',
    is_default: true,
    lateral_cg_enabled: true,
    empty_weight: AS350_BEW,
    empty_weight_arm: AS350_BEW_ARM,
    empty_weight_moment: AS350_BEW * AS350_BEW_ARM,
    empty_weight_lateral_arm: AS350_BEW_LAT_ARM,
    empty_weight_lateral_moment: AS350_BEW * AS350_BEW_LAT_ARM,
    fuel_arm: 136.8,
    fuel_lateral_arm: 0,
    max_ramp_weight: 5225,
    max_takeoff_weight: 5225,
    max_landing_weight: 5225,
    max_zero_fuel_weight: 5225,
    taxi_fuel_gallons: 1.0,
  } as Partial<WBProfile>);
  console.log(`  Created W&B profile: ${as350WB.name}`);

  // Stations: 6 seats (with lateral arms), 3 cargo
  const as350Stations = await wbStationRepo.save([
    {
      wb_profile_id: as350WB.id,
      name: 'Pilot (R)',
      category: 'seat',
      arm: 61,
      lateral_arm: 14.2,
      sort_order: 0,
    },
    {
      wb_profile_id: as350WB.id,
      name: 'Copilot (R)',
      category: 'seat',
      arm: 61,
      lateral_arm: -14.2,
      sort_order: 1,
    },
    {
      wb_profile_id: as350WB.id,
      name: 'OL Rear',
      category: 'seat',
      arm: 100,
      lateral_arm: -24.4,
      sort_order: 2,
    },
    {
      wb_profile_id: as350WB.id,
      name: 'ML',
      category: 'seat',
      arm: 100,
      lateral_arm: -8.2,
      sort_order: 3,
    },
    {
      wb_profile_id: as350WB.id,
      name: 'MR',
      category: 'seat',
      arm: 100,
      lateral_arm: 8.2,
      sort_order: 4,
    },
    {
      wb_profile_id: as350WB.id,
      name: 'OR Rear',
      category: 'seat',
      arm: 100,
      lateral_arm: 24.4,
      sort_order: 5,
    },
    {
      wb_profile_id: as350WB.id,
      name: 'Pilot Cargo',
      category: 'baggage',
      arm: 126,
      lateral_arm: 21.9,
      sort_order: 6,
    },
    {
      wb_profile_id: as350WB.id,
      name: 'Copilot Cargo',
      category: 'seat',
      arm: 126,
      lateral_arm: -21.9,
      sort_order: 7,
    },
    {
      wb_profile_id: as350WB.id,
      name: 'Tail Cargo',
      category: 'baggage',
      arm: 181.1,
      lateral_arm: 0,
      sort_order: 8,
    },
  ] as Partial<WBStation>[]);
  console.log(`  Created ${as350Stations.length} W&B stations.`);

  // CG envelopes — longitudinal + lateral
  await wbEnvelopeRepo.save([
    {
      wb_profile_id: as350WB.id,
      envelope_type: 'normal',
      axis: 'longitudinal',
      points: [
        { weight: 2888, cg: 124.8 },
        { weight: 4409, cg: 124.8 },
        { weight: 5225, cg: 127.2 },
        { weight: 5225, cg: 134.1 },
        { weight: 3858, cg: 137.4 },
        { weight: 2888, cg: 137.7 },
      ],
    },
    {
      wb_profile_id: as350WB.id,
      envelope_type: 'normal',
      axis: 'lateral',
      points: [
        { weight: 2888, cg: 5.5 },
        { weight: 2888, cg: -7.1 },
        { weight: 5225, cg: -7.1 },
        { weight: 5225, cg: 5.5 },
      ],
    },
  ] as Partial<WBEnvelope>[]);
  console.log('  Created CG envelopes (longitudinal + lateral).');
  console.log('');

  // ─── Summary ──────────────────────────────────────────────────────────

  console.log('=== Seed Complete ===');
  console.log(
    `  ${tbm.tail_number} (${tbm.aircraft_type}): ${tbmProfiles.length} perf profiles, ${tbmTanks.length} tanks, ${tbmStations.length} W&B stations`,
  );
  console.log(
    `  ${as350.tail_number} (${as350.aircraft_type}): ${as350Stations.length} W&B stations (lateral CG)`,
  );

  await ds.destroy();
}

main().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
