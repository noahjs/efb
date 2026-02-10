import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Aircraft } from './aircraft.entity';
import { DataGroup } from '../../config/constants';

@Entity('u_fuel_tanks')
export class FuelTank {
  static readonly DATA_GROUP = DataGroup.USER;
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'integer' })
  aircraft_id: number;

  @ManyToOne(() => Aircraft, (a) => a.fuel_tanks, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'aircraft_id' })
  aircraft: Aircraft;

  @Column({ type: 'varchar' })
  name: string;

  @Column({ type: 'float' })
  capacity_gallons: number;

  @Column({ type: 'float', nullable: true })
  tab_fuel_gallons: number;

  @Column({ type: 'integer', default: 0 })
  sort_order: number;
}
