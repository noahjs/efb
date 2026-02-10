import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Aircraft } from '../../aircraft/entities/aircraft.entity';
import { PerformanceProfile } from '../../aircraft/entities/performance-profile.entity';
import { DataGroup } from '../../config/constants';

@Entity('u_flights')
export class Flight {
  static readonly DATA_GROUP = DataGroup.USER;
  @PrimaryGeneratedColumn()
  id: number;

  // Aircraft FK links
  @Column({ type: 'integer', nullable: true })
  aircraft_id: number;

  @ManyToOne(() => Aircraft, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'aircraft_id' })
  aircraft: Aircraft;

  @Column({ type: 'integer', nullable: true })
  performance_profile_id: number;

  @ManyToOne(() => PerformanceProfile, {
    onDelete: 'SET NULL',
    nullable: true,
  })
  @JoinColumn({ name: 'performance_profile_id' })
  performance_profile_rel: PerformanceProfile;

  // Departure / Destination
  @Column({ type: 'varchar', nullable: true })
  departure_identifier: string;

  @Column({ type: 'varchar', nullable: true })
  destination_identifier: string;

  @Column({ type: 'varchar', nullable: true })
  alternate_identifier: string;

  @Column({ type: 'varchar', nullable: true })
  etd: string;

  // Aircraft
  @Column({ type: 'varchar', nullable: true })
  aircraft_identifier: string;

  @Column({ type: 'varchar', nullable: true })
  aircraft_type: string;

  @Column({ type: 'varchar', nullable: true })
  performance_profile: string;

  @Column({ type: 'integer', nullable: true })
  true_airspeed: number;

  // Route
  @Column({ type: 'varchar', default: 'IFR' })
  flight_rules: string;

  @Column({ type: 'text', nullable: true })
  route_string: string;

  @Column({ type: 'integer', nullable: true })
  cruise_altitude: number;

  // Payload
  @Column({ type: 'integer', default: 1 })
  people_count: number;

  @Column({ type: 'float', default: 170 })
  avg_person_weight: number;

  @Column({ type: 'float', default: 0 })
  cargo_weight: number;

  // Fuel
  @Column({ type: 'varchar', nullable: true })
  fuel_policy: string;

  @Column({ type: 'float', nullable: true })
  start_fuel_gallons: number;

  @Column({ type: 'float', nullable: true })
  reserve_fuel_gallons: number;

  @Column({ type: 'float', nullable: true })
  fuel_burn_rate: number;

  // Flight Log
  @Column({ type: 'float', default: 0 })
  fuel_at_shutdown_gallons: number;

  // Filing
  @Column({ type: 'varchar', default: 'not_filed' })
  filing_status: string;

  @Column({ type: 'varchar', nullable: true })
  filing_reference: string;

  @Column({ type: 'varchar', nullable: true })
  filing_version_stamp: string;

  @Column({ type: 'varchar', nullable: true })
  filed_at: string;

  @Column({ type: 'varchar', nullable: true })
  filing_format: string;

  @Column({ type: 'real', nullable: true })
  endurance_hours: number;

  @Column({ type: 'text', nullable: true })
  remarks: string;

  // Computed (populated by future milestones)
  @Column({ type: 'float', nullable: true })
  distance_nm: number;

  @Column({ type: 'integer', nullable: true })
  ete_minutes: number;

  @Column({ type: 'float', nullable: true })
  flight_fuel_gallons: number;

  @Column({ type: 'float', nullable: true })
  wind_component: number;

  @Column({ type: 'varchar', nullable: true })
  eta: string;

  @Column({ type: 'varchar', nullable: true })
  calculated_at: string;

  // Metadata
  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;
}
