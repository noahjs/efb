import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { WBProfile } from './wb-profile.entity';
import { DataGroup } from '../../config/constants';

@Entity('u_wb_stations')
export class WBStation {
  static readonly DATA_GROUP = DataGroup.USER;
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'integer' })
  wb_profile_id: number;

  @ManyToOne(() => WBProfile, (p) => p.stations, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'wb_profile_id' })
  profile: WBProfile;

  @Column({ type: 'varchar' })
  name: string;

  @Column({ type: 'varchar' })
  category: string;

  @Column({ type: 'float' })
  arm: number;

  @Column({ type: 'float', nullable: true })
  lateral_arm: number;

  @Column({ type: 'float', nullable: true })
  max_weight: number;

  @Column({ type: 'float', nullable: true })
  default_weight: number;

  @Column({ type: 'integer', nullable: true })
  fuel_tank_id: number;

  @Column({ type: 'integer', default: 0 })
  sort_order: number;

  @Column({ type: 'varchar', nullable: true })
  group_name: string;
}
