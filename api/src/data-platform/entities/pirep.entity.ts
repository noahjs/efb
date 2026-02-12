import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  Index,
  UpdateDateColumn,
} from 'typeorm';

@Entity('a_pireps')
export class Pirep {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'text', nullable: true })
  raw_ob: string | null;

  @Column({ type: 'varchar', length: 10, nullable: true })
  icao_id: string | null;

  @Column({ type: 'float', nullable: true })
  @Index()
  latitude: number | null;

  @Column({ type: 'float', nullable: true })
  @Index()
  longitude: number | null;

  @Column({ type: 'int', nullable: true })
  flight_level: number | null;

  @Column({ type: 'varchar', length: 20, nullable: true })
  aircraft_type: string | null;

  @Column({ type: 'varchar', length: 10, nullable: true })
  report_type: string | null;

  @Column({ type: 'timestamp', nullable: true })
  obs_time: Date | null;

  @Column({ type: 'jsonb', nullable: true })
  properties: any;

  @Column({ type: 'jsonb', nullable: true })
  geometry: any;

  @UpdateDateColumn()
  updated_at: Date;
}
