import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  Index,
  UpdateDateColumn,
} from 'typeorm';

@Entity('a_lightning_threats')
export class LightningThreat {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar', length: 20, nullable: true })
  @Index()
  severity: string | null;

  @Column({ type: 'jsonb', nullable: true })
  geometry: any;

  @Column({ type: 'jsonb', nullable: true })
  forecast_path: any;

  @Column({ type: 'jsonb', nullable: true })
  properties: any;

  @Column({ type: 'varchar', length: 50, nullable: true })
  poll_batch_id: string | null;

  @UpdateDateColumn()
  updated_at: Date;
}
