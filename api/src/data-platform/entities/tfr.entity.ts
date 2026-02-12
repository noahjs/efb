import {
  Entity,
  PrimaryColumn,
  Column,
  Index,
  UpdateDateColumn,
} from 'typeorm';

@Entity('a_tfrs')
export class Tfr {
  @PrimaryColumn({ type: 'varchar', length: 50 })
  notam_id: string;

  @Column({ type: 'varchar', length: 50, nullable: true })
  type: string | null;

  @Column({ type: 'varchar', length: 10, nullable: true })
  @Index()
  state: string | null;

  @Column({ type: 'varchar', length: 20, nullable: true })
  facility: string | null;

  @Column({ type: 'text', nullable: true })
  description: string | null;

  @Column({ type: 'varchar', length: 100, nullable: true })
  effective_start: string | null;

  @Column({ type: 'varchar', length: 100, nullable: true })
  effective_end: string | null;

  @Column({ type: 'text', nullable: true })
  altitude: string | null;

  @Column({ type: 'text', nullable: true })
  reason: string | null;

  @Column({ type: 'text', nullable: true })
  notam_text: string | null;

  @Column({ type: 'jsonb', nullable: true })
  geometry: any;

  @Column({ type: 'jsonb', nullable: true })
  properties: any;

  @UpdateDateColumn()
  updated_at: Date;
}
