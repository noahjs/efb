import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { WBProfile } from './wb-profile.entity';

@Entity('wb_scenarios')
export class WBScenario {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'integer' })
  wb_profile_id: number;

  @ManyToOne(() => WBProfile, (p) => p.scenarios, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'wb_profile_id' })
  profile: WBProfile;

  @Column({ type: 'integer', nullable: true })
  flight_id: number;

  @Column({ type: 'varchar' })
  name: string;

  @Column({ type: 'jsonb' })
  station_loads: {
    station_id: number;
    weight: number;
    occupant_name?: string;
    is_person?: boolean;
  }[];

  @Column({ type: 'float', nullable: true })
  starting_fuel_gallons: number;

  @Column({ type: 'float', nullable: true })
  ending_fuel_gallons: number;

  @Column({ type: 'float' })
  computed_zfw: number;

  @Column({ type: 'float' })
  computed_zfw_cg: number;

  @Column({ type: 'float', nullable: true })
  computed_zfw_lateral_cg: number;

  @Column({ type: 'float' })
  computed_ramp_weight: number;

  @Column({ type: 'float' })
  computed_ramp_cg: number;

  @Column({ type: 'float', nullable: true })
  computed_ramp_lateral_cg: number;

  @Column({ type: 'float' })
  computed_tow: number;

  @Column({ type: 'float' })
  computed_tow_cg: number;

  @Column({ type: 'float', nullable: true })
  computed_tow_lateral_cg: number;

  @Column({ type: 'float' })
  computed_ldw: number;

  @Column({ type: 'float' })
  computed_ldw_cg: number;

  @Column({ type: 'float', nullable: true })
  computed_ldw_lateral_cg: number;

  @Column({ type: 'boolean' })
  is_within_envelope: boolean;

  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;
}
