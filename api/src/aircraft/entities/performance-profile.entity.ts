import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Aircraft } from './aircraft.entity';

@Entity('performance_profiles')
export class PerformanceProfile {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'integer' })
  aircraft_id: number;

  @ManyToOne(() => Aircraft, (a) => a.performance_profiles, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'aircraft_id' })
  aircraft: Aircraft;

  @Column({ type: 'varchar' })
  name: string;

  @Column({ type: 'boolean', default: false })
  is_default: boolean;

  @Column({ type: 'float', nullable: true })
  cruise_tas: number;

  @Column({ type: 'float', nullable: true })
  cruise_fuel_burn: number;

  @Column({ type: 'float', nullable: true })
  climb_rate: number;

  @Column({ type: 'float', nullable: true })
  climb_speed: number;

  @Column({ type: 'float', nullable: true })
  climb_fuel_flow: number;

  @Column({ type: 'float', nullable: true })
  descent_rate: number;

  @Column({ type: 'float', nullable: true })
  descent_speed: number;

  @Column({ type: 'float', nullable: true })
  descent_fuel_flow: number;

  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;
}
