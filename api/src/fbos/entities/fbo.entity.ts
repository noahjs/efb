import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  OneToMany,
  Index,
  Unique,
} from 'typeorm';
import { FuelPrice } from './fuel-price.entity';

@Entity('a_fbos')
@Unique(['airport_identifier', 'airnav_id'])
export class Fbo {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar' })
  @Index()
  airport_identifier: string;

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
