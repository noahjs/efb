import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Fbo } from './fbo.entity';

@Entity('fuel_prices')
export class FuelPrice {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'int' })
  fbo_id: number;

  @ManyToOne(() => Fbo, (fbo) => fbo.fuel_prices, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'fbo_id' })
  fbo: Fbo;

  @Column({ type: 'varchar' })
  fuel_type: string;

  @Column({ type: 'varchar' })
  service_level: string;

  @Column({ type: 'decimal', precision: 6, scale: 2 })
  price: number;

  @Column({ type: 'boolean', default: false })
  is_guaranteed: boolean;

  @Column({ type: 'date', nullable: true })
  price_date: string;

  @Column({ type: 'timestamp', nullable: true })
  scraped_at: Date;
}
