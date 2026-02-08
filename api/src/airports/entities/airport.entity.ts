import {
  Entity,
  Column,
  PrimaryColumn,
  OneToMany,
  Index,
} from 'typeorm';
import { Runway } from './runway.entity';
import { Frequency } from './frequency.entity';

@Entity('airports')
export class Airport {
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

  @OneToMany(() => Runway, (runway) => runway.airport, { cascade: true })
  runways: Runway[];

  @OneToMany(() => Frequency, (freq) => freq.airport, { cascade: true })
  frequencies: Frequency[];
}
