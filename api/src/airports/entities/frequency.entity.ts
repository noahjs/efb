import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Airport } from './airport.entity';
import { DataGroup } from '../../config/constants';

@Entity('a_frequencies')
export class Frequency {
  static readonly DATA_GROUP = DataGroup.AVIATION;
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar' })
  airport_identifier: string;

  @ManyToOne(() => Airport, (airport) => airport.frequencies)
  @JoinColumn({ name: 'airport_identifier' })
  airport: Airport;

  @Column({ type: 'varchar', nullable: true })
  type: string;

  @Column({ type: 'varchar', nullable: true })
  name: string;

  @Column({ type: 'varchar', nullable: true })
  frequency: string;

  @Column({ type: 'varchar', nullable: true })
  phone: string;
}
