import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';
import { DataGroup } from '../../config/constants';

@Entity('a_master_wb_profiles')
export class MasterWBProfile {
  static readonly DATA_GROUP = DataGroup.AVIATION;

  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar', unique: true })
  icao_type_code: string;

  @Column({ type: 'varchar' })
  display_name: string;

  @Column({ type: 'jsonb', nullable: true })
  aircraft_defaults: {
    category?: string;
    engine_type?: string;
    num_engines?: number;
    pressurized?: boolean;
    service_ceiling?: number;
    fuel_type?: string;
    total_usable_fuel?: number;
    fuel_weight_per_gallon?: number;
    best_glide_speed?: number;
    glide_ratio?: number;
    empty_weight?: number;
    max_takeoff_weight?: number;
    max_landing_weight?: number;
  };

  @Column({ type: 'jsonb', default: '[]' })
  fuel_tanks: {
    name: string;
    capacity_gallons: number;
    tab_fuel_gallons?: number;
    sort_order: number;
  }[];

  @Column({ type: 'jsonb', default: '[]' })
  performance_profiles: {
    name: string;
    is_default?: boolean;
    cruise_tas?: number;
    cruise_fuel_burn?: number;
    climb_rate?: number;
    climb_speed?: number;
    climb_fuel_flow?: number;
    descent_rate?: number;
    descent_speed?: number;
    descent_fuel_flow?: number;
    takeoff_data?: string;
    landing_data?: string;
  }[];

  @Column({ type: 'jsonb', default: '[]' })
  wb_profiles: {
    name: string;
    is_default?: boolean;
    datum_description?: string;
    lateral_cg_enabled?: boolean;
    empty_weight: number;
    empty_weight_arm: number;
    empty_weight_moment?: number;
    empty_weight_lateral_arm?: number;
    empty_weight_lateral_moment?: number;
    max_ramp_weight?: number;
    max_takeoff_weight: number;
    max_landing_weight: number;
    max_zero_fuel_weight?: number;
    fuel_arm?: number;
    fuel_lateral_arm?: number;
    taxi_fuel_gallons?: number;
    notes?: string;
    stations: {
      name: string;
      category: string;
      arm: number;
      lateral_arm?: number;
      max_weight?: number;
      default_weight?: number;
      fuel_tank_index?: number;
      sort_order: number;
      group_name?: string;
    }[];
    envelopes: {
      envelope_type: string;
      axis: string;
      points: { weight: number; cg: number }[];
    }[];
  }[];

  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;
}
