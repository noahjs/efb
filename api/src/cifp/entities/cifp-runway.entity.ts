import { Entity, Column, PrimaryGeneratedColumn, Index } from 'typeorm';
import { DataGroup } from '../../config/constants';

@Entity('a_cifp_runways')
export class CifpRunway {
  static readonly DATA_GROUP = DataGroup.AVIATION;
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar' })
  @Index()
  airport_identifier: string;

  @Column({ type: 'varchar' })
  @Index()
  icao_identifier: string;

  @Column({ type: 'varchar', length: 5 })
  runway_identifier: string;

  @Column({ type: 'int', nullable: true })
  runway_length: number;

  @Column({ type: 'float', nullable: true })
  runway_bearing: number;

  @Column({ type: 'float', nullable: true })
  threshold_latitude: number;

  @Column({ type: 'float', nullable: true })
  threshold_longitude: number;

  @Column({ type: 'int', nullable: true })
  threshold_elevation: number;

  @Column({ type: 'int', nullable: true })
  displaced_threshold_distance: number;

  @Column({ type: 'int', nullable: true })
  threshold_crossing_height: number;

  @Column({ type: 'int', nullable: true })
  runway_width: number;

  @Column({ type: 'varchar', length: 4, nullable: true })
  localizer_identifier: string;

  @Column({ type: 'varchar', length: 4 })
  cycle: string;
}
