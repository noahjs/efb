import { Entity, Column, PrimaryGeneratedColumn, Index } from 'typeorm';

@Entity('cifp_ils')
export class CifpIls {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar' })
  @Index()
  airport_identifier: string;

  @Column({ type: 'varchar' })
  @Index()
  icao_identifier: string;

  @Column({ type: 'varchar', length: 4 })
  @Index()
  localizer_identifier: string;

  @Column({ type: 'varchar', length: 1, nullable: true })
  ils_category: string;

  @Column({ type: 'float', nullable: true })
  frequency: number;

  @Column({ type: 'varchar', length: 5, nullable: true })
  runway_identifier: string;

  @Column({ type: 'float', nullable: true })
  localizer_latitude: number;

  @Column({ type: 'float', nullable: true })
  localizer_longitude: number;

  @Column({ type: 'float', nullable: true })
  localizer_bearing: number;

  @Column({ type: 'float', nullable: true })
  gs_latitude: number;

  @Column({ type: 'float', nullable: true })
  gs_longitude: number;

  @Column({ type: 'float', nullable: true })
  gs_angle: number;

  @Column({ type: 'int', nullable: true })
  gs_elevation: number;

  @Column({ type: 'int', nullable: true })
  threshold_crossing_height: number;

  @Column({ type: 'varchar', length: 5, nullable: true })
  station_declination: string;

  @Column({ type: 'varchar', length: 4 })
  cycle: string;
}
