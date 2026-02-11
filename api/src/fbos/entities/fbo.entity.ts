import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  ManyToOne,
  OneToMany,
  JoinColumn,
  Unique,
} from 'typeorm';
import { Airport } from '../../airports/entities/airport.entity';
import { FuelPrice } from './fuel-price.entity';

@Entity('fbos')
@Unique(['airport_identifier', 'airnav_id'])
export class Fbo {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar' })
  airport_identifier: string;

  @ManyToOne(() => Airport, (airport) => airport.fbos)
  @JoinColumn({ name: 'airport_identifier' })
  airport: Airport;

  @Column({ type: 'varchar' })
  airnav_id: string;

  @Column({ type: 'varchar' })
  name: string;

  @Column({ type: 'varchar', nullable: true })
  phone: string;

  @Column({ type: 'varchar', nullable: true })
  toll_free_phone: string;

  @Column({ type: 'varchar', nullable: true })
  asri_frequency: string;

  @Column({ type: 'varchar', nullable: true })
  website: string;

  @Column({ type: 'varchar', nullable: true })
  email: string;

  @Column({ type: 'text', nullable: true })
  description: string;

  @Column({ type: 'simple-array', nullable: true })
  badges: string[];

  @Column({ type: 'varchar', nullable: true })
  fuel_brand: string;

  @Column({ type: 'float', nullable: true })
  rating: number;

  @Column({ type: 'timestamp', nullable: true })
  scraped_at: Date;

  @OneToMany(() => FuelPrice, (fp) => fp.fbo, { cascade: true })
  fuel_prices: FuelPrice[];
}
