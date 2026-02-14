import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  ManyToOne,
  OneToMany,
  JoinColumn,
  Index,
} from 'typeorm';
import { Airport } from './airport.entity';
import { RunwayEnd } from './runway-end.entity';
import { DataGroup } from '../../config/constants';
import { DataCycle } from '../../data-cycle/entities/data-cycle.entity';

@Entity('a_runways')
export class Runway {
  static readonly DATA_GROUP = DataGroup.AVIATION;
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'int', nullable: true })
  airport_id: number;

  @Column({ type: 'varchar' })
  @Index()
  airport_identifier: string;

  @ManyToOne(() => Airport, (airport) => airport.runways, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'airport_id' })
  airport: Airport;

  @Column({ type: 'uuid', nullable: true })
  @Index()
  cycle_id: string;

  @ManyToOne(() => DataCycle, { nullable: true, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'cycle_id' })
  cycle: DataCycle;

  @Column({ type: 'varchar', nullable: true })
  identifiers: string;

  @Column({ type: 'integer', nullable: true })
  length: number;

  @Column({ type: 'integer', nullable: true })
  width: number;

  @Column({ type: 'varchar', nullable: true })
  surface: string;

  @Column({ type: 'varchar', nullable: true })
  condition: string;

  @Column({ type: 'float', nullable: true })
  slope: number;

  @OneToMany(() => RunwayEnd, (end) => end.runway, { cascade: true })
  ends: RunwayEnd[];
}
