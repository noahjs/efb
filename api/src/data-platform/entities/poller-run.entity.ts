import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  Index,
  CreateDateColumn,
} from 'typeorm';

@Entity('s_poller_runs')
export class PollerRun {
  @PrimaryGeneratedColumn()
  id: number;

  @Index()
  @Column({ type: 'varchar', length: 50 })
  data_source_key: string;

  @Column({ type: 'varchar', length: 20 })
  status: 'success' | 'partial' | 'failed';

  @Column({ type: 'timestamp' })
  started_at: Date;

  @Column({ type: 'timestamp' })
  completed_at: Date;

  @Column({ type: 'int' })
  duration_ms: number;

  @Column({ type: 'int', default: 0 })
  records_updated: number;

  @Column({ type: 'int', default: 0 })
  error_count: number;

  @Column({ type: 'text', nullable: true })
  error_message: string | null;
}
