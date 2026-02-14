import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { Airport } from './airport.entity';
import { DataGroup } from '../../config/constants';
import { DataCycle } from '../../data-cycle/entities/data-cycle.entity';

@Entity('a_frequencies')
export class Frequency {
  static readonly DATA_GROUP = DataGroup.AVIATION;
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'int', nullable: true })
  airport_id: number;

  @Column({ type: 'varchar' })
  @Index()
  airport_identifier: string;

  @ManyToOne(() => Airport, (airport) => airport.frequencies, {
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
  type: string;

  @Column({ type: 'varchar', nullable: true })
  name: string;

  @Column({ type: 'varchar', nullable: true })
  frequency: string;

  @Column({ type: 'varchar', nullable: true })
  phone: string;
}
