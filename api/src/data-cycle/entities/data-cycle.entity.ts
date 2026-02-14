import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  Index,
  Unique,
} from 'typeorm';

export enum CycleDataGroup {
  NASR = 'NASR',
  CIFP = 'CIFP',
  DTPP = 'DTPP',
  CHARTS = 'CHARTS',
}

export enum CycleStatus {
  SEEDING = 'SEEDING',
  STAGED = 'STAGED',
  PENDING_ACTIVATION = 'PENDING_ACTIVATION',
  ACTIVE = 'ACTIVE',
  ARCHIVED = 'ARCHIVED',
}

@Entity('s_data_cycles')
@Unique(['data_group', 'cycle_code'])
export class DataCycle {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'enum', enum: CycleDataGroup })
  @Index()
  data_group: CycleDataGroup;

  @Column({ type: 'varchar' })
  cycle_code: string;

  @Column({ type: 'date' })
  effective_date: string;

  @Column({ type: 'date' })
  expiration_date: string;

  @Column({ type: 'enum', enum: CycleStatus, default: CycleStatus.SEEDING })
  @Index()
  status: CycleStatus;

  @Column({ type: 'varchar', nullable: true })
  source_url: string;

  @Column({ type: 'jsonb', nullable: true })
  record_counts: Record<string, number>;

  @CreateDateColumn({ type: 'timestamptz' })
  seeded_at: Date;

  @Column({ type: 'timestamptz', nullable: true })
  activated_at: Date;
}
