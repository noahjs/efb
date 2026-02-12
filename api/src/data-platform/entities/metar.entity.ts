import {
  Entity,
  PrimaryColumn,
  Column,
  Index,
  UpdateDateColumn,
} from 'typeorm';

@Entity('a_metars')
export class Metar {
  @PrimaryColumn({ type: 'varchar', length: 10 })
  icao_id: string;

  @Column({ type: 'float', nullable: true })
  @Index()
  latitude: number | null;

  @Column({ type: 'float', nullable: true })
  @Index()
  longitude: number | null;

  @Column({ type: 'text', nullable: true })
  raw_ob: string | null;

  @Column({ type: 'varchar', length: 10, nullable: true })
  flight_category: string | null;

  @Column({ type: 'float', nullable: true })
  temp: number | null;

  @Column({ type: 'float', nullable: true })
  dewp: number | null;

  @Column({ type: 'int', nullable: true })
  wdir: number | null;

  @Column({ type: 'int', nullable: true })
  wspd: number | null;

  @Column({ type: 'int', nullable: true })
  wgst: number | null;

  @Column({ type: 'float', nullable: true })
  visib: number | null;

  @Column({ type: 'float', nullable: true })
  altim: number | null;

  @Column({ type: 'jsonb', nullable: true })
  clouds: any;

  @Column({ type: 'bigint', nullable: true })
  obs_time: number | null;

  @Column({ type: 'varchar', length: 50, nullable: true })
  report_time: string | null;

  @Column({ type: 'jsonb', nullable: true })
  raw_data: any;

  @UpdateDateColumn()
  updated_at: Date;
}
