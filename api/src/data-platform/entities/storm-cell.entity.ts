import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  Index,
  UpdateDateColumn,
} from 'typeorm';

@Entity('a_storm_cells')
export class StormCell {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar', length: 50 })
  @Index()
  cell_id: string;

  @Column({ type: 'varchar', length: 20 })
  trait: string;

  @Column({ type: 'float' })
  latitude: number;

  @Column({ type: 'float' })
  longitude: number;

  @Column({ type: 'jsonb', nullable: true })
  geometry: any;

  @Column({ type: 'jsonb', nullable: true })
  forecast_track: any;

  @Column({ type: 'jsonb', nullable: true })
  forecast_cone: any;

  @Column({ type: 'jsonb', nullable: true })
  properties: any;

  @Column({ type: 'varchar', length: 50, nullable: true })
  poll_batch_id: string | null;

  @UpdateDateColumn()
  updated_at: Date;
}
