import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  Index,
  Unique,
} from 'typeorm';

@Entity('a_hrrr_pressure')
@Unique(['init_time', 'forecast_hour', 'lat', 'lng', 'pressure_level'])
export class HrrrPressure {
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

  @Column({ type: 'smallint' })
  @Index()
  pressure_level: number;

  @Column({ type: 'int' })
  altitude_ft: number;

  // Relative humidity at this level (0–100%); RH > 80% indicates cloud presence
  @Column({ type: 'smallint', nullable: true })
  relative_humidity: number;

  // Wind at this level
  @Column({ type: 'smallint', nullable: true })
  wind_dir: number;

  @Column({ type: 'smallint', nullable: true })
  wind_speed_kt: number;

  // Temperature at this level
  @Column({ type: 'float', nullable: true })
  temperature_c: number;
}
