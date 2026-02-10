import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
  OneToOne,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { PerformanceProfile } from './performance-profile.entity';
import { FuelTank } from './fuel-tank.entity';
import { Equipment } from './equipment.entity';
import { User } from '../../users/entities/user.entity';
import { DataGroup } from '../../config/constants';

@Entity('u_aircraft')
export class Aircraft {
  static readonly DATA_GROUP = DataGroup.USER;
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'uuid', nullable: true })
  user_id: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE', nullable: true })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ type: 'varchar' })
  tail_number: string;

  @Column({ type: 'varchar', nullable: true })
  call_sign: string;

  @Column({ type: 'varchar', nullable: true })
  serial_number: string;

  @Column({ type: 'varchar' })
  aircraft_type: string;

  @Column({ type: 'varchar', nullable: true })
  icao_type_code: string;

  @Column({ type: 'varchar', default: 'landplane' })
  category: string;

  @Column({ type: 'varchar', nullable: true })
  engine_type: string; // 'piston' | 'turboprop' | 'turbojet' | 'turboshaft'

  @Column({ type: 'integer', nullable: true, default: 1 })
  num_engines: number;

  @Column({ type: 'boolean', nullable: true, default: false })
  pressurized: boolean;

  @Column({ type: 'integer', nullable: true })
  service_ceiling: number; // feet MSL

  @Column({ type: 'integer', nullable: true })
  max_cabin_altitude: number; // feet

  @Column({ type: 'varchar', nullable: true })
  color: string;

  @Column({ type: 'varchar', nullable: true })
  home_airport: string;

  @Column({ type: 'varchar', default: 'knots' })
  airspeed_units: string;

  @Column({ type: 'varchar', default: 'inches' })
  length_units: string;

  @Column({ type: 'varchar', nullable: true })
  ownership_status: string;

  @Column({ type: 'varchar', default: '100ll' })
  fuel_type: string;

  @Column({ type: 'float', nullable: true })
  total_usable_fuel: number;

  @Column({ type: 'float', nullable: true })
  best_glide_speed: number;

  @Column({ type: 'float', nullable: true })
  glide_ratio: number;

  @Column({ type: 'float', nullable: true })
  empty_weight: number;

  @Column({ type: 'float', nullable: true })
  max_takeoff_weight: number;

  @Column({ type: 'float', nullable: true })
  max_landing_weight: number;

  @Column({ type: 'float', nullable: true })
  fuel_weight_per_gallon: number;

  @Column({ type: 'boolean', default: false })
  is_default: boolean;

  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;

  @OneToMany(() => PerformanceProfile, (p) => p.aircraft, { cascade: true })
  performance_profiles: PerformanceProfile[];

  @OneToMany(() => FuelTank, (t) => t.aircraft, { cascade: true })
  fuel_tanks: FuelTank[];

  @OneToOne(() => Equipment, (e) => e.aircraft, { cascade: true })
  equipment: Equipment;
}
