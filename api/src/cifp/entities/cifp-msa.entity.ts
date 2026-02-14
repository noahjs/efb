import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { DataGroup } from '../../config/constants';
import { DataCycle } from '../../data-cycle/entities/data-cycle.entity';

@Entity('a_cifp_msa')
export class CifpMsa {
  static readonly DATA_GROUP = DataGroup.AVIATION;
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'uuid', nullable: true })
  @Index()
  cycle_id: string;

  @ManyToOne(() => DataCycle, { nullable: true, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'cycle_id' })
  data_cycle: DataCycle;

  @Column({ type: 'varchar' })
  @Index()
  airport_identifier: string;

  @Column({ type: 'varchar' })
  @Index()
  icao_identifier: string;

  @Column({ type: 'varchar', length: 5 })
  msa_center: string;

  @Column({ type: 'varchar', length: 2, nullable: true })
  msa_center_icao: string;

  @Column({ type: 'varchar', length: 1, nullable: true })
  multiple_code: string;

  @Column({ type: 'jsonb' })
  sectors: {
    bearing_from: number;
    bearing_to: number;
    altitude: number;
    radius: number;
  }[];

  @Column({ type: 'varchar', length: 1, nullable: true })
  magnetic_true_indicator: string;

  @Column({ type: 'varchar', length: 4 })
  cycle: string;
}
