import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  OneToOne,
  JoinColumn,
} from 'typeorm';
import { Aircraft } from './aircraft.entity';

@Entity('equipment')
export class Equipment {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'integer', unique: true })
  aircraft_id: number;

  @OneToOne(() => Aircraft, (a) => a.equipment, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'aircraft_id' })
  aircraft: Aircraft;

  @Column({ type: 'varchar', nullable: true })
  gps_type: string;

  @Column({ type: 'varchar', nullable: true })
  transponder_type: string;

  @Column({ type: 'varchar', nullable: true })
  adsb_compliance: string;

  @Column({ type: 'varchar', nullable: true })
  equipment_codes: string;

  @Column({ type: 'text', nullable: true })
  installed_avionics: string;
}
