/**
 * Master W&B Profile Seed Script
 *
 * Seeds system-level master profiles keyed by ICAO type code.
 * When a user creates an aircraft with a known type, the system
 * auto-clones fuel tanks, performance profiles, and W&B data.
 *
 * Profiles:
 *   1. TBM9 — TBM 960 turboprop
 *   2. AS50 — AS350B3 helicopter (lateral CG)
 *
 * Usage: npm run seed:master-profiles
 */

import { DataSource } from 'typeorm';
import { MasterWBProfile } from '../aircraft/entities/master-wb-profile.entity';
import { dbConfig } from '../db.config';
import {
  TBM960_TAKEOFF_DATA,
  TBM960_LANDING_DATA,
} from '../aircraft/seed/tbm960-performance';

const TBM_BEW = 4784;
const TBM_BEW_ARM = 186.4;

const AS350_BEW = 3201;
const AS350_BEW_ARM = 137.2;
const AS350_BEW_LAT_ARM = 1.3;

const MASTER_PROFILES: Partial<MasterWBProfile>[] = [
  {
    icao_type_code: 'TBM9',
    display_name: 'TBM 960',
    aircraft_defaults: {
      category: 'landplane',
      engine_type: 'turboprop',
      num_engines: 1,
      pressurized: true,
      fuel_type: 'jet_a',
      total_usable_fuel: 291,
      fuel_weight_per_gallon: 6.7,
      best_glide_speed: 120,
      glide_ratio: 13.8,
    },
    fuel_tanks: [
      {
        name: 'Left Wing',
        capacity_gallons: 145.5,
        tab_fuel_gallons: 73,
        sort_order: 0,
      },
      {
        name: 'Right Wing',
        capacity_gallons: 145.5,
        tab_fuel_gallons: 73,
        sort_order: 1,
      },
    ],
    performance_profiles: [
      {
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
    ],
    wb_profiles: [
      {
        name: '6-Seat Standard',
        is_default: true,
        datum_description: 'Forward face of firewall',
        lateral_cg_enabled: false,
        empty_weight: TBM_BEW,
        empty_weight_arm: TBM_BEW_ARM,
        empty_weight_moment: TBM_BEW * TBM_BEW_ARM,
        max_ramp_weight: 7650,
        max_takeoff_weight: 7615,
        max_landing_weight: 7110,
        max_zero_fuel_weight: 6252,
        fuel_arm: 189.8,
        taxi_fuel_gallons: 5.0,
        notes:
          'TBM 960 6-seat configuration. BEW from sample weighing report.',
        stations: [
          {
            name: 'Pilot',
            category: 'seat',
            arm: 178.5,
            default_weight: 170,
            sort_order: 0,
            group_name: 'Flight Deck',
          },
          {
            name: 'Copilot',
            category: 'seat',
            arm: 178.5,
            sort_order: 1,
            group_name: 'Flight Deck',
          },
          {
            name: 'Left Seat',
            category: 'seat',
            arm: 224.8,
            sort_order: 2,
            group_name: 'Intermediate Row',
          },
          {
            name: 'Right Seat',
            category: 'seat',
            arm: 224.8,
            sort_order: 3,
            group_name: 'Intermediate Row',
          },
          {
            name: 'Back Left Seat',
            category: 'seat',
            arm: 267.1,
            sort_order: 4,
            group_name: 'Aft Row',
          },
          {
            name: 'Back Right Seat',
            category: 'seat',
            arm: 267.1,
            sort_order: 5,
            group_name: 'Aft Row',
          },
          {
            name: 'Forward Baggage',
            category: 'baggage',
            arm: 128,
            max_weight: 55,
            sort_order: 6,
            group_name: 'Baggage',
          },
          {
            name: 'Aft Baggage',
            category: 'baggage',
            arm: 303,
            max_weight: 220,
            sort_order: 7,
            group_name: 'Baggage',
          },
          {
            name: 'Left Wing Fuel',
            category: 'fuel',
            arm: 189.8,
            fuel_tank_index: 0,
            sort_order: 8,
            group_name: 'Fuel',
          },
          {
            name: 'Right Wing Fuel',
            category: 'fuel',
            arm: 189.8,
            fuel_tank_index: 1,
            sort_order: 9,
            group_name: 'Fuel',
          },
        ],
        envelopes: [
          {
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
          },
        ],
      },
    ],
  },
  {
    icao_type_code: 'AS50',
    display_name: 'AS350B3 (H125)',
    aircraft_defaults: {
      category: 'helicopter',
      engine_type: 'turboshaft',
      num_engines: 1,
      fuel_type: 'jet_a',
    },
    fuel_tanks: [],
    performance_profiles: [],
    wb_profiles: [
      {
        name: 'Standard',
        is_default: true,
        lateral_cg_enabled: true,
        empty_weight: AS350_BEW,
        empty_weight_arm: AS350_BEW_ARM,
        empty_weight_moment: AS350_BEW * AS350_BEW_ARM,
        empty_weight_lateral_arm: AS350_BEW_LAT_ARM,
        empty_weight_lateral_moment: AS350_BEW * AS350_BEW_LAT_ARM,
        max_ramp_weight: 5225,
        max_takeoff_weight: 5225,
        max_landing_weight: 5225,
        max_zero_fuel_weight: 5225,
        fuel_arm: 136.8,
        fuel_lateral_arm: 0,
        taxi_fuel_gallons: 1.0,
        stations: [
          {
            name: 'Pilot (R)',
            category: 'seat',
            arm: 61,
            lateral_arm: 14.2,
            sort_order: 0,
          },
          {
            name: 'Copilot (R)',
            category: 'seat',
            arm: 61,
            lateral_arm: -14.2,
            sort_order: 1,
          },
          {
            name: 'OL Rear',
            category: 'seat',
            arm: 100,
            lateral_arm: -24.4,
            sort_order: 2,
          },
          {
            name: 'ML',
            category: 'seat',
            arm: 100,
            lateral_arm: -8.2,
            sort_order: 3,
          },
          {
            name: 'MR',
            category: 'seat',
            arm: 100,
            lateral_arm: 8.2,
            sort_order: 4,
          },
          {
            name: 'OR Rear',
            category: 'seat',
            arm: 100,
            lateral_arm: 24.4,
            sort_order: 5,
          },
          {
            name: 'Pilot Cargo',
            category: 'baggage',
            arm: 126,
            lateral_arm: 21.9,
            sort_order: 6,
          },
          {
            name: 'Copilot Cargo',
            category: 'seat',
            arm: 126,
            lateral_arm: -21.9,
            sort_order: 7,
          },
          {
            name: 'Tail Cargo',
            category: 'baggage',
            arm: 181.1,
            lateral_arm: 0,
            sort_order: 8,
          },
        ],
        envelopes: [
          {
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
            envelope_type: 'normal',
            axis: 'lateral',
            points: [
              { weight: 2888, cg: 5.5 },
              { weight: 2888, cg: -7.1 },
              { weight: 5225, cg: -7.1 },
              { weight: 5225, cg: 5.5 },
            ],
          },
        ],
      },
    ],
  },
];

async function main() {
  console.log('=== EFB Master W&B Profile Seed ===\n');

  const ds = new DataSource({
    ...dbConfig,
    entities: [MasterWBProfile],
  });

  await ds.initialize();
  console.log('Database initialized.\n');

  const repo = ds.getRepository(MasterWBProfile);

  for (const profile of MASTER_PROFILES) {
    const existing = await repo.findOne({
      where: { icao_type_code: profile.icao_type_code },
    });

    if (existing) {
      console.log(
        `Updating existing master profile: ${profile.icao_type_code} (${profile.display_name})`,
      );
      Object.assign(existing, profile);
      await repo.save(existing);
    } else {
      console.log(
        `Creating master profile: ${profile.icao_type_code} (${profile.display_name})`,
      );
      await repo.save(repo.create(profile));
    }
  }

  console.log(`\n=== Seed Complete: ${MASTER_PROFILES.length} master profiles ===`);
  await ds.destroy();
}

main().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
