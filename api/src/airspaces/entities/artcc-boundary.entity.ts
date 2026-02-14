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

@Entity('a_artcc_boundaries')
export class ArtccBoundary {
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
  artcc_id: string;

  @Column({ type: 'varchar', nullable: true })
  name: string;

  @Column({ type: 'varchar', length: 10 })
  altitude: string;

  @Column({ type: 'text' })
  geometry_json: string;

  @Column({ type: 'float' })
  min_lat: number;

  @Column({ type: 'float' })
  max_lat: number;

  @Column({ type: 'float' })
  min_lng: number;

  @Column({ type: 'float' })
  max_lng: number;
}
