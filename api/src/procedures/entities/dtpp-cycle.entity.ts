import { Entity, Column, PrimaryColumn } from 'typeorm';
import { DataGroup } from '../../config/constants';

@Entity('a_dtpp_cycles')
export class DtppCycle {
  static readonly DATA_GROUP = DataGroup.AVIATION;
  @PrimaryColumn({ type: 'varchar' })
  cycle: string;

  @Column({ type: 'varchar', nullable: true })
  from_date: string;

  @Column({ type: 'varchar', nullable: true })
  to_date: string;

  @Column({ type: 'int', default: 0 })
  procedure_count: number;

  @Column({ type: 'varchar', nullable: true })
  seeded_at: string;
}
