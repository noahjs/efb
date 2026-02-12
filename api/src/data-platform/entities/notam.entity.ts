import {
  Entity,
  PrimaryColumn,
  Column,
  Index,
  UpdateDateColumn,
} from 'typeorm';

@Entity('a_notams')
export class Notam {
  @PrimaryColumn({ type: 'varchar', length: 50 })
  notam_number: string;

  @Column({ type: 'varchar', length: 20, nullable: true })
  @Index()
  airport_id: string | null;

  @Column({ type: 'text', nullable: true })
  text: string | null;

  @Column({ type: 'text', nullable: true })
  full_text: string | null;

  @Column({ type: 'varchar', length: 30, nullable: true })
  keyword: string | null;

  @Column({ type: 'varchar', length: 50, nullable: true })
  classification: string | null;

  @Column({ type: 'varchar', length: 50, nullable: true })
  effective_start: string | null;

  @Column({ type: 'varchar', length: 50, nullable: true })
  effective_end: string | null;

  @Column({ type: 'jsonb', nullable: true })
  raw_data: any;

  @UpdateDateColumn()
  updated_at: Date;
}
