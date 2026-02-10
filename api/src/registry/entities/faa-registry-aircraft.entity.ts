import { Entity, Column, PrimaryColumn } from 'typeorm';
import { DataGroup } from '../../config/constants';

@Entity('a_faa_registry')
export class FaaRegistryAircraft {
  static readonly DATA_GROUP = DataGroup.AVIATION;
  @PrimaryColumn({ type: 'varchar', length: 5 })
  n_number: string;

  // From MASTER
  @Column({ type: 'varchar', nullable: true })
  serial_number: string;

  @Column({ type: 'varchar', nullable: true })
  year_mfr: string;

  @Column({ type: 'varchar', nullable: true })
  type_aircraft: string;

  @Column({ type: 'varchar', nullable: true })
  type_engine: string;

  @Column({ type: 'varchar', nullable: true })
  status_code: string;

  @Column({ type: 'varchar', nullable: true })
  mode_s_code_hex: string;

  // From ACFTREF (joined at seed time)
  @Column({ type: 'varchar', nullable: true })
  manufacturer: string;

  @Column({ type: 'varchar', nullable: true })
  model: string;

  @Column({ type: 'varchar', nullable: true })
  num_engines: string;

  @Column({ type: 'varchar', nullable: true })
  num_seats: string;

  @Column({ type: 'varchar', nullable: true })
  cruising_speed_mph: string;

  // From ENGINE (joined at seed time)
  @Column({ type: 'varchar', nullable: true })
  engine_manufacturer: string;

  @Column({ type: 'varchar', nullable: true })
  engine_model: string;

  @Column({ type: 'varchar', nullable: true })
  horsepower: string;

  @Column({ type: 'varchar', nullable: true })
  thrust: string;
}
