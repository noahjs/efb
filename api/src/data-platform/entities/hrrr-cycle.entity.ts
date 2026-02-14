import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('a_hrrr_cycles')
export class HrrrCycle {
  @PrimaryColumn({ type: 'timestamptz' })
  init_time: Date;

  // --- Overall Status ---
  // discovered → downloading → processing → ingesting
  //   → generating_tiles → active → superseded
  // On failure at any stage: 'failed'
  @Column({ type: 'varchar', length: 20, default: 'discovered' })
  status: string;

  @Column({ type: 'boolean', default: false })
  is_active: boolean;

  // --- Stage 1: Download ---
  @Column({ type: 'int', default: 0 })
  download_total: number;

  @Column({ type: 'int', default: 0 })
  download_completed: number;

  @Column({ type: 'int', default: 0 })
  download_failed: number;

  @Column({ type: 'bigint', default: 0 })
  download_bytes: number;

  @Column({ type: 'timestamptz', nullable: true })
  download_started_at: Date | null;

  @Column({ type: 'timestamptz', nullable: true })
  download_completed_at: Date | null;

  // --- Stage 2: Processing (Python GRIB2 decode) ---
  @Column({ type: 'int', default: 0 })
  process_total: number;

  @Column({ type: 'int', default: 0 })
  process_completed: number;

  @Column({ type: 'int', default: 0 })
  process_failed: number;

  @Column({ type: 'timestamptz', nullable: true })
  process_started_at: Date | null;

  @Column({ type: 'timestamptz', nullable: true })
  process_completed_at: Date | null;

  // --- Stage 3: Grid Ingest ---
  @Column({ type: 'int', default: 0 })
  ingest_surface_rows: number;

  @Column({ type: 'int', default: 0 })
  ingest_pressure_rows: number;

  @Column({ type: 'timestamptz', nullable: true })
  ingest_completed_at: Date | null;

  // --- Stage 4: Tile Generation ---
  @Column({ type: 'int', default: 0 })
  tiles_total: number;

  @Column({ type: 'int', default: 0 })
  tiles_completed: number;

  @Column({ type: 'int', default: 0 })
  tiles_failed: number;

  @Column({ type: 'int', default: 0 })
  tiles_count: number;

  @Column({ type: 'timestamptz', nullable: true })
  tiles_started_at: Date | null;

  @Column({ type: 'timestamptz', nullable: true })
  tiles_completed_at: Date | null;

  // --- Stage 5: Activation ---
  @Column({ type: 'timestamptz', nullable: true })
  activated_at: Date | null;

  @Column({ type: 'timestamptz', nullable: true })
  superseded_at: Date | null;

  // --- Error Tracking ---
  @Column({ type: 'text', nullable: true })
  last_error: string | null;

  @Column({ type: 'int', default: 0 })
  total_errors: number;

  // --- Timing ---
  @Column({ type: 'int', nullable: true })
  total_duration_ms: number | null;

  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;
}
