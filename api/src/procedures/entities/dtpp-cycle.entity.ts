import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  ManyToOne,
  JoinColumn,
  Index,
  Unique,
} from 'typeorm';
import { DataGroup } from '../../config/constants';
import { DataCycle } from '../../data-cycle/entities/data-cycle.entity';

@Entity('a_dtpp_cycles')
@Unique(['cycle', 'cycle_id'])
export class DtppCycle {
  static readonly DATA_GROUP = DataGroup.AVIATION;

  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar' })
  @Index()
  cycle: string;

  @Column({ type: 'uuid', nullable: true })
  @Index()
  cycle_id: string;

  @ManyToOne(() => DataCycle, { nullable: true, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'cycle_id' })
  data_cycle: DataCycle;

  @Column({ type: 'varchar', nullable: true })
  from_date: string;

  @Column({ type: 'varchar', nullable: true })
  to_date: string;

  @Column({ type: 'int', default: 0 })
  procedure_count: number;

  @Column({ type: 'varchar', nullable: true })
  seeded_at: string;
}
