import { Entity, Column, PrimaryColumn } from 'typeorm';

@Entity('dtpp_cycles')
export class DtppCycle {
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
