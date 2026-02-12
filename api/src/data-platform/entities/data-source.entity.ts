import { Entity, PrimaryColumn, Column } from 'typeorm';

@Entity('s_data_sources')
export class DataSource {
  @PrimaryColumn({ type: 'varchar', length: 50 })
  key: string;

  @Column({ type: 'varchar', length: 100 })
  name: string;

  @Column({ type: 'int' })
  interval_seconds: number;

  @Column({ type: 'varchar', length: 20, default: 'idle' })
  status: string;

  @Column({ type: 'timestamp', nullable: true })
  last_requested_at: Date | null;

  @Column({ type: 'timestamp', nullable: true })
  last_completed_at: Date | null;

  @Column({ type: 'text', nullable: true })
  last_error: string | null;

  @Column({ type: 'int', nullable: true })
  last_duration_ms: number | null;

  @Column({ type: 'int', nullable: true })
  records_updated: number | null;

  @Column({ type: 'boolean', default: true })
  enabled: boolean;
}
