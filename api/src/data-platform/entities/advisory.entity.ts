import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  Index,
  UpdateDateColumn,
} from 'typeorm';

@Entity('a_advisories')
export class Advisory {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar', length: 20 })
  @Index()
  type: string;

  @Column({ type: 'varchar', length: 50, nullable: true })
  hazard: string | null;

  @Column({ type: 'varchar', length: 50, nullable: true })
  severity: string | null;

  @Column({ type: 'text', nullable: true })
  raw_text: string | null;

  @Column({ type: 'timestamp', nullable: true })
  valid_time_from: Date | null;

  @Column({ type: 'timestamp', nullable: true })
  valid_time_to: Date | null;

  @Column({ type: 'jsonb', nullable: true })
  geometry: any;

  @Column({ type: 'jsonb', nullable: true })
  properties: any;

  @Column({ type: 'varchar', length: 50, nullable: true })
  poll_batch_id: string | null;

  @UpdateDateColumn()
  updated_at: Date;
}
