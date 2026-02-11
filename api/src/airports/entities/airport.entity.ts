import { Entity, Column, PrimaryColumn, OneToMany, Index } from 'typeorm';
import { Runway } from './runway.entity';
import { Frequency } from './frequency.entity';
import { Fbo } from '../../fbos/entities/fbo.entity';
import { DataGroup } from '../../config/constants';

@Entity('a_airports')
export class Airport {
  static readonly DATA_GROUP = DataGroup.AVIATION;
  @PrimaryColumn({ length: 10 })
  identifier: string;

  @Column({ type: 'varchar', nullable: true })
  @Index()
  icao_identifier: string;

  @Column({ type: 'varchar' })
  @Index()
  name: string;

  @Column({ type: 'varchar', nullable: true })
  @Index()
  city: string;

  @Column({ type: 'varchar', nullable: true })
  state: string;

  @Column({ type: 'float', nullable: true })
  latitude: number;

  @Column({ type: 'float', nullable: true })
  longitude: number;

  @Column({ type: 'float', nullable: true })
  elevation: number;

  @Column({ type: 'varchar', nullable: true })
  magnetic_variation: string;

  @Column({ type: 'varchar', nullable: true })
  timezone: string;

  @Column({ type: 'varchar', nullable: true })
  ownership_type: string;

  @Column({ type: 'varchar', nullable: true })
  facility_type: string;

  @Column({ type: 'varchar', nullable: true })
  status: string;

  @Column({ type: 'integer', nullable: true })
  tpa: number;

  @Column({ type: 'varchar', nullable: true })
  fuel_types: string;

  @Column({ type: 'varchar', nullable: true })
  facility_use: string;

  @Column({ type: 'varchar', nullable: true })
  artcc_id: string;

  @Column({ type: 'varchar', nullable: true })
  artcc_name: string;

  @Column({ type: 'varchar', nullable: true })
  fss_id: string;

  @Column({ type: 'varchar', nullable: true })
  fss_name: string;

  @Column({ type: 'varchar', nullable: true })
  notam_id: string;

  @Column({ type: 'varchar', nullable: true })
  sectional_chart: string;

  @Column({ type: 'varchar', nullable: true })
  customs_flag: string;

  @Column({ type: 'varchar', nullable: true })
  landing_rights_flag: string;

  @Column({ type: 'varchar', nullable: true })
  lighting_schedule: string;

  @Column({ type: 'varchar', nullable: true })
  beacon_schedule: string;

  @Column({ type: 'varchar', nullable: true })
  nasr_effective_date: string;

  @Column({ type: 'varchar', nullable: true })
  manager_name: string;

  @Column({ type: 'varchar', nullable: true })
  manager_phone: string;

  @Column({ type: 'varchar', nullable: true })
  manager_address: string;

  @Column({ type: 'varchar', nullable: true })
  owner_name: string;

  @Column({ type: 'varchar', nullable: true })
  owner_phone: string;

  @Column({ type: 'varchar', nullable: true })
  owner_address: string;

  @Column({ type: 'varchar', nullable: true })
  tower_hours: string;

  @Column({ type: 'boolean', default: false })
  has_datis: boolean;

  @Column({ type: 'boolean', default: false })
  has_cpdlc: boolean;

  @OneToMany(() => Runway, (runway) => runway.airport, { cascade: true })
  runways: Runway[];

  @OneToMany(() => Frequency, (freq) => freq.airport, { cascade: true })
  frequencies: Frequency[];

  @Column({ type: 'timestamp', nullable: true })
  fbo_scraped_at: Date;

  @OneToMany(() => Fbo, (fbo) => fbo.airport, { cascade: true })
  fbos: Fbo[];
}
