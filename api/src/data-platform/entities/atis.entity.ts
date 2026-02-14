import { Entity, PrimaryColumn, Column, UpdateDateColumn } from 'typeorm';

@Entity('a_atis')
export class Atis {
  @PrimaryColumn({ type: 'varchar', length: 10 })
  icao_id: string;

  @Column({ type: 'varchar', length: 20 })
  source: string;

  @Column({ type: 'varchar', length: 20, default: 'combined' })
  type: string;

  @Column({ type: 'text', nullable: true })
  datis_text: string | null;

  @Column({ type: 'varchar', length: 1, nullable: true })
  letter: string | null;

  @Column({ type: 'varchar', length: 20, default: 'current' })
  status: 'processing' | 'current' | 'error';

  @Column({ type: 'jsonb', nullable: true })
  raw_data: any;

  @Column({ type: 'timestamp', nullable: true })
  fetched_at: Date | null;

  @UpdateDateColumn()
  updated_at: Date;
}
