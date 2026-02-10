import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  ManyToOne,
  OneToMany,
  JoinColumn,
} from 'typeorm';
import { Airport } from './airport.entity';
import { RunwayEnd } from './runway-end.entity';
import { DataGroup } from '../../config/constants';

@Entity('a_runways')
export class Runway {
  static readonly DATA_GROUP = DataGroup.AVIATION;
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar' })
  airport_identifier: string;

  @ManyToOne(() => Airport, (airport) => airport.runways)
  @JoinColumn({ name: 'airport_identifier' })
  airport: Airport;

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
