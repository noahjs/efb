import { Entity, Column, PrimaryColumn, Index } from 'typeorm';
import { DataGroup } from '../../config/constants';

@Entity('a_weather_stations')
export class WeatherStation {
  static readonly DATA_GROUP = DataGroup.AVIATION;

  @PrimaryColumn({ type: 'varchar', length: 10 })
  icao_id: string;

  @Column({ type: 'varchar' })
  @Index()
  name: string;

  @Column({ type: 'float' })
  latitude: number;

  @Column({ type: 'float' })
  longitude: number;

  @Column({ type: 'float', nullable: true })
  elevation: number;

  @Column({ type: 'varchar', nullable: true })
  state: string;

  @Column({ type: 'varchar', nullable: true })
  country: string;

  @Column({ type: 'int', default: 0 })
  priority: number;

  @Column({ type: 'boolean', default: true })
  has_metar: boolean;

  @Column({ type: 'boolean', default: false })
  has_taf: boolean;
}
