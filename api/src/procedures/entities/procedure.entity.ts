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

@Entity('a_procedures')
export class Procedure {
  static readonly DATA_GROUP = DataGroup.AVIATION;
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'uuid', nullable: true })
  @Index()
  cycle_id: string;

  @ManyToOne(() => DataCycle, { nullable: true, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'cycle_id' })
  data_cycle: DataCycle;

  @Column({ type: 'varchar' })
  @Index()
  airport_identifier: string;

  @Column({ type: 'varchar' })
  @Index()
  chart_code: string;

  @Column({ type: 'varchar' })
  chart_name: string;

  @Column({ type: 'varchar' })
  pdf_name: string;

  @Column({ type: 'int', default: 0 })
  chart_seq: number;

  @Column({ type: 'varchar', nullable: true })
  user_action: string;

  @Column({ type: 'varchar', nullable: true })
  faanfd18: string;

  @Column({ type: 'varchar', nullable: true })
  copter: string;

  @Column({ type: 'varchar' })
  cycle: string;

  @Column({ type: 'varchar', nullable: true })
  state_code: string;

  @Column({ type: 'varchar', nullable: true })
  city_name: string;

  @Column({ type: 'varchar', nullable: true })
  volume: string;

  @Column({ type: 'jsonb', nullable: true })
  georef_data: object | null;
}
