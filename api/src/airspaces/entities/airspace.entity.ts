import { Entity, Column, PrimaryGeneratedColumn, Index } from 'typeorm';
import { DataGroup } from '../../config/constants';

@Entity('a_airspaces')
export class Airspace {
  static readonly DATA_GROUP = DataGroup.AVIATION;
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar', length: 20, nullable: true })
  @Index()
  identifier: string;

  @Column({ type: 'varchar', nullable: true })
  name: string;

  @Column({ type: 'varchar', length: 5 })
  @Index()
  airspace_class: string;

  @Column({ type: 'varchar', length: 20, nullable: true })
  type: string;

  @Column({ type: 'int', nullable: true })
  lower_alt: number;

  @Column({ type: 'int', nullable: true })
  upper_alt: number;

  @Column({ type: 'varchar', length: 10, nullable: true })
  lower_code: string;

  @Column({ type: 'varchar', length: 10, nullable: true })
  upper_code: string;

  @Column({ type: 'text' })
  geometry_json: string;

  @Column({ type: 'float' })
  min_lat: number;

  @Column({ type: 'float' })
  max_lat: number;

  @Column({ type: 'float' })
  min_lng: number;

  @Column({ type: 'float' })
  max_lng: number;

  @Column({ type: 'boolean', default: false })
  military: boolean;
}
