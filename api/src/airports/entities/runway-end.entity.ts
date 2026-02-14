import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { Runway } from './runway.entity';
import { DataGroup } from '../../config/constants';
import { DataCycle } from '../../data-cycle/entities/data-cycle.entity';

@Entity('a_runway_ends')
export class RunwayEnd {
  static readonly DATA_GROUP = DataGroup.AVIATION;
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'integer' })
  runway_id: number;

  @ManyToOne(() => Runway, (runway) => runway.ends)
  @JoinColumn({ name: 'runway_id' })
  runway: Runway;

  @Column({ type: 'uuid', nullable: true })
  @Index()
  cycle_id: string;

  @ManyToOne(() => DataCycle, { nullable: true, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'cycle_id' })
  cycle: DataCycle;

  @Column({ type: 'varchar', nullable: true })
  identifier: string;

  @Column({ type: 'float', nullable: true })
  heading: number;

  @Column({ type: 'float', nullable: true })
  elevation: number;

  @Column({ type: 'integer', nullable: true })
  tora: number;

  @Column({ type: 'integer', nullable: true })
  toda: number;

  @Column({ type: 'integer', nullable: true })
  asda: number;

  @Column({ type: 'integer', nullable: true })
  lda: number;

  @Column({ type: 'varchar', nullable: true })
  glideslope: string;

  @Column({ type: 'varchar', nullable: true })
  lighting_approach: string;

  @Column({ type: 'varchar', nullable: true })
  lighting_edge: string;

  @Column({ type: 'varchar', nullable: true })
  traffic_pattern: string;

  @Column({ type: 'float', nullable: true })
  latitude: number;

  @Column({ type: 'float', nullable: true })
  longitude: number;

  @Column({ type: 'integer', nullable: true })
  displaced_threshold: number;
}
