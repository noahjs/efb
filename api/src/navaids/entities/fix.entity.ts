import { Entity, Column, PrimaryColumn } from 'typeorm';
import { DataGroup } from '../../config/constants';

@Entity('a_fixes')
export class Fix {
  static readonly DATA_GROUP = DataGroup.AVIATION;
  @PrimaryColumn({ length: 10 })
  identifier: string;

  @Column({ type: 'float' })
  latitude: number;

  @Column({ type: 'float' })
  longitude: number;

  @Column({ type: 'varchar', nullable: true })
  state: string;

  @Column({ type: 'varchar', nullable: true })
  artcc_high: string;

  @Column({ type: 'varchar', nullable: true })
  artcc_low: string;
}
