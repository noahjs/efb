import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  OneToMany,
  JoinColumn,
} from 'typeorm';
import { Aircraft } from '../../aircraft/entities/aircraft.entity';
import { WBStation } from './wb-station.entity';
import { WBEnvelope } from './wb-envelope.entity';
import { WBScenario } from './wb-scenario.entity';

@Entity('wb_profiles')
export class WBProfile {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'integer' })
  aircraft_id: number;

  @ManyToOne(() => Aircraft, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'aircraft_id' })
  aircraft: Aircraft;

  @Column({ type: 'varchar' })
  name: string;

  @Column({ type: 'boolean', default: false })
  is_default: boolean;

  @Column({ type: 'varchar', nullable: true })
  datum_description: string;

  @Column({ type: 'boolean', default: false })
  lateral_cg_enabled: boolean;

  @Column({ type: 'float' })
  empty_weight: number;

  @Column({ type: 'float' })
  empty_weight_arm: number;

  @Column({ type: 'float' })
  empty_weight_moment: number;

  @Column({ type: 'float', nullable: true })
  empty_weight_lateral_arm: number;

  @Column({ type: 'float', nullable: true })
  empty_weight_lateral_moment: number;

  @Column({ type: 'float', nullable: true })
  max_ramp_weight: number;

  @Column({ type: 'float' })
  max_takeoff_weight: number;

  @Column({ type: 'float' })
  max_landing_weight: number;

  @Column({ type: 'float', nullable: true })
  max_zero_fuel_weight: number;

  @Column({ type: 'float', nullable: true })
  fuel_arm: number;

  @Column({ type: 'float', nullable: true })
  fuel_lateral_arm: number;

  @Column({ type: 'float', default: 1.0 })
  taxi_fuel_gallons: number;

  @Column({ type: 'text', nullable: true })
  notes: string;

  @OneToMany(() => WBStation, (s) => s.profile, { cascade: true })
  stations: WBStation[];

  @OneToMany(() => WBEnvelope, (e) => e.profile, { cascade: true })
  envelopes: WBEnvelope[];

  @OneToMany(() => WBScenario, (s) => s.profile, { cascade: true })
  scenarios: WBScenario[];

  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;
}
