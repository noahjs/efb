import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  Index,
  OneToMany,
} from 'typeorm';
import { CifpLeg } from './cifp-leg.entity';

@Entity('cifp_approaches')
export class CifpApproach {
  @PrimaryGeneratedColumn()
  id: number;

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
