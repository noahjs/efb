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
import { DataGroup } from '../../config/constants';

@Entity('u_logbook_entries')
export class LogbookEntry {
  static readonly DATA_GROUP = DataGroup.USER;
  @PrimaryGeneratedColumn()
  id: number;

  // Date of flight
  @Column({ type: 'varchar', nullable: true })
  date: string;

  // Aircraft
  @Column({ type: 'integer', nullable: true })
  aircraft_id: number;

  @ManyToOne(() => Aircraft, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'aircraft_id' })
  aircraft: Aircraft;

  @Column({ type: 'varchar', nullable: true })
  aircraft_identifier: string;

  @Column({ type: 'varchar', nullable: true })
  aircraft_type: string;

  @Column({ type: 'varchar', nullable: true })
  aircraft_category: string;

  // Route
  @Column({ type: 'varchar', nullable: true })
  from_airport: string;

  @Column({ type: 'varchar', nullable: true })
  to_airport: string;

  @Column({ type: 'text', nullable: true })
  route: string;

  // Start & End
  @Column({ type: 'float', nullable: true })
  hobbs_start: number;

  @Column({ type: 'float', nullable: true })
  hobbs_end: number;

  @Column({ type: 'float', nullable: true })
  tach_start: number;

  @Column({ type: 'float', nullable: true })
  tach_end: number;

  @Column({ type: 'varchar', nullable: true })
  time_out: string;

  @Column({ type: 'varchar', nullable: true })
  time_off: string;

  @Column({ type: 'varchar', nullable: true })
  time_on: string;

  @Column({ type: 'varchar', nullable: true })
  time_in: string;

  // Times (decimal hours)
  @Column({ type: 'float', default: 0 })
  total_time: number;

  @Column({ type: 'float', default: 0 })
  pic: number;

  @Column({ type: 'float', default: 0 })
  sic: number;

  @Column({ type: 'float', default: 0 })
  night: number;

  @Column({ type: 'float', default: 0 })
  solo: number;

  @Column({ type: 'float', default: 0 })
  cross_country: number;

  @Column({ type: 'float', nullable: true })
  distance: number;

  @Column({ type: 'float', default: 0 })
  actual_instrument: number;

  @Column({ type: 'float', default: 0 })
  simulated_instrument: number;

  // Takeoffs & Landings
  @Column({ type: 'integer', default: 0 })
  day_takeoffs: number;

  @Column({ type: 'integer', default: 0 })
  night_takeoffs: number;

  @Column({ type: 'integer', default: 0 })
  day_landings_full_stop: number;

  @Column({ type: 'integer', default: 0 })
  night_landings_full_stop: number;

  @Column({ type: 'integer', default: 0 })
  all_landings: number;

  // Autorotations (helicopter)
  @Column({ type: 'integer', default: 0 })
  autorotations: number;

  @Column({ type: 'integer', default: 0 })
  full_down_autorotations: number;

  @Column({ type: 'integer', default: 0 })
  hovering_autorotations: number;

  // Instrument
  @Column({ type: 'integer', default: 0 })
  holds: number;

  @Column({ type: 'text', nullable: true })
  approaches: string;

  // Training
  @Column({ type: 'float', default: 0 })
  dual_given: number;

  @Column({ type: 'float', default: 0 })
  dual_received: number;

  @Column({ type: 'float', default: 0 })
  simulated_flight: number;

  @Column({ type: 'float', default: 0 })
  ground_training: number;

  // People & Remarks
  @Column({ type: 'varchar', nullable: true })
  instructor_name: string;

  @Column({ type: 'text', nullable: true })
  instructor_comments: string;

  @Column({ type: 'varchar', nullable: true })
  person1: string;

  @Column({ type: 'varchar', nullable: true })
  person2: string;

  @Column({ type: 'varchar', nullable: true })
  person3: string;

  @Column({ type: 'varchar', nullable: true })
  person4: string;

  @Column({ type: 'varchar', nullable: true })
  person5: string;

  @Column({ type: 'varchar', nullable: true })
  person6: string;

  @Column({ type: 'boolean', default: false })
  flight_review: boolean;

  @Column({ type: 'boolean', default: false })
  checkride: boolean;

  @Column({ type: 'boolean', default: false })
  ipc: boolean;

  @Column({ type: 'text', nullable: true })
  comments: string;

  // Metadata
  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;
}
