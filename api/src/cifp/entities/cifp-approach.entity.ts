import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  ManyToOne,
  JoinColumn,
  Index,
  OneToMany,
} from 'typeorm';
import { CifpLeg } from './cifp-leg.entity';
import { DataGroup } from '../../config/constants';
import { DataCycle } from '../../data-cycle/entities/data-cycle.entity';

@Entity('a_cifp_approaches')
export class CifpApproach {
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

  @Column({ type: 'varchar', length: 6 })
  @Index()
  procedure_identifier: string;

  @Column({ type: 'varchar', length: 1 })
  route_type: string;

  @Column({ type: 'varchar', nullable: true })
  transition_identifier?: string;

  @Column({ type: 'varchar', nullable: true })
  procedure_name?: string;

  @Column({ type: 'varchar', length: 5, nullable: true })
  runway_identifier?: string;

  @Column({ type: 'varchar', length: 4 })
  cycle: string;

  @OneToMany(() => CifpLeg, (leg) => leg.approach, { cascade: true })
  legs: CifpLeg[];
}
