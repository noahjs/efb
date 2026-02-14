import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { CifpApproach } from './cifp-approach.entity';
import { DataGroup } from '../../config/constants';
import { DataCycle } from '../../data-cycle/entities/data-cycle.entity';

@Entity('a_cifp_legs')
export class CifpLeg {
  static readonly DATA_GROUP = DataGroup.AVIATION;
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'uuid', nullable: true })
  @Index()
  cycle_id: string;

  @ManyToOne(() => DataCycle, { nullable: true, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'cycle_id' })
  cycle: DataCycle;

  @Column({ type: 'int' })
  approach_id: number;

  @Column({ type: 'int' })
  sequence_number: number;

  @Column({ type: 'varchar', length: 5, nullable: true })
  fix_identifier?: string;

  @Column({ type: 'varchar', length: 2, nullable: true })
  fix_section_code?: string;

  @Column({ type: 'varchar', length: 4, nullable: true })
  waypoint_description_code?: string;

  @Column({ type: 'varchar', length: 1, nullable: true })
  turn_direction?: string;

  @Column({ type: 'varchar', length: 2 })
  path_termination: string;

  @Column({ type: 'varchar', length: 4, nullable: true })
  recomm_navaid?: string;

  @Column({ type: 'float', nullable: true })
  theta?: number;

  @Column({ type: 'float', nullable: true })
  rho?: number;

  @Column({ type: 'float', nullable: true })
  arc_radius?: number;

  @Column({ type: 'float', nullable: true })
  magnetic_course?: number;

  @Column({ type: 'varchar', length: 4, nullable: true })
  route_distance_or_time?: string;

  @Column({ type: 'varchar', length: 1, nullable: true })
  altitude_description?: string;

  @Column({ type: 'int', nullable: true })
  altitude1?: number;

  @Column({ type: 'int', nullable: true })
  altitude2?: number;

  @Column({ type: 'int', nullable: true })
  transition_altitude?: number;

  @Column({ type: 'int', nullable: true })
  speed_limit?: number;

  @Column({ type: 'float', nullable: true })
  vertical_angle?: number;

  @Column({ type: 'varchar', length: 5, nullable: true })
  center_fix?: string;

  @Column({ type: 'float', nullable: true })
  fix_latitude?: number;

  @Column({ type: 'float', nullable: true })
  fix_longitude?: number;

  @Column({ type: 'boolean', default: false })
  is_iaf: boolean;

  @Column({ type: 'boolean', default: false })
  is_if: boolean;

  @Column({ type: 'boolean', default: false })
  is_faf: boolean;

  @Column({ type: 'boolean', default: false })
  is_map: boolean;

  @Column({ type: 'boolean', default: false })
  is_missed_approach: boolean;

  @ManyToOne(() => CifpApproach, (approach) => approach.legs)
  @JoinColumn({ name: 'approach_id' })
  approach: CifpApproach;
}
