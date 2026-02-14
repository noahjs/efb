import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  Index,
  Unique,
} from 'typeorm';

@Entity('a_hrrr_surface')
@Unique(['init_time', 'forecast_hour', 'lat', 'lng'])
export class HrrrSurface {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'timestamptz' })
  @Index()
  init_time: Date;

  @Column({ type: 'int' })
  forecast_hour: number;

  @Column({ type: 'timestamptz' })
  @Index()
  valid_time: Date;

  @Column({ type: 'float' })
  @Index()
  lat: number;

  @Column({ type: 'float' })
  @Index()
  lng: number;

  // Cloud composites (0–100%)
  @Column({ type: 'smallint', nullable: true })
  cloud_total: number;

  @Column({ type: 'smallint', nullable: true })
  cloud_low: number;

  @Column({ type: 'smallint', nullable: true })
  cloud_mid: number;

  @Column({ type: 'smallint', nullable: true })
  cloud_high: number;

  // Cloud geometry (feet MSL)
  @Column({ type: 'int', nullable: true })
  ceiling_ft: number;

  @Column({ type: 'int', nullable: true })
  cloud_base_ft: number;

  @Column({ type: 'int', nullable: true })
  cloud_top_ft: number;

  // Flight category (derived from ceiling + visibility)
  @Column({ type: 'varchar', length: 4, nullable: true })
  flight_category: string;

  // Visibility
  @Column({ type: 'float', nullable: true })
  visibility_sm: number;

  // Surface wind
  @Column({ type: 'smallint', nullable: true })
  wind_dir: number;

  @Column({ type: 'smallint', nullable: true })
  wind_speed_kt: number;

  @Column({ type: 'smallint', nullable: true })
  wind_gust_kt: number;

  // Surface temperature
  @Column({ type: 'float', nullable: true })
  temperature_c: number;
}
