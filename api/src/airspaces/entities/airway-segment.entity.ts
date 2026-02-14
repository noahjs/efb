import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { DataGroup } from '../../config/constants';
import { DataCycle } from '../../data-cycle/entities/data-cycle.entity';

@Entity('a_airway_segments')
export class AirwaySegment {
  static readonly DATA_GROUP = DataGroup.AVIATION;
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'uuid', nullable: true })
  @Index()
  cycle_id: string;

  @ManyToOne(() => DataCycle, { nullable: true, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'cycle_id' })
  cycle: DataCycle;

  @Column({ type: 'varchar', length: 10 })
  @Index()
  airway_id: string;

  @Column({ type: 'int' })
  sequence: number;

  @Column({ type: 'varchar', length: 10, nullable: true })
  from_fix: string;

  @Column({ type: 'varchar', length: 10, nullable: true })
  to_fix: string;

  @Column({ type: 'float' })
  from_lat: number;

  @Column({ type: 'float' })
  from_lng: number;

  @Column({ type: 'float' })
  to_lat: number;

  @Column({ type: 'float' })
  to_lng: number;

  @Column({ type: 'int', nullable: true })
  min_enroute_alt: number;

  @Column({ type: 'int', nullable: true })
  moca: number;

  @Column({ type: 'float', nullable: true })
  distance_nm: number;

  @Column({ type: 'varchar', length: 5 })
  @Index()
  airway_type: string;
}
