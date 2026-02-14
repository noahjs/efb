import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  ManyToOne,
  JoinColumn,
  Index,
  OneToMany,
} from 'typeorm';
import { PreferredRouteSegment } from './preferred-route-segment.entity';
import { DataGroup } from '../../config/constants';
import { DataCycle } from '../../data-cycle/entities/data-cycle.entity';

@Entity('a_preferred_routes')
@Index(['origin_id', 'destination_id'])
export class PreferredRoute {
  static readonly DATA_GROUP = DataGroup.AVIATION;

  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'uuid', nullable: true })
  @Index()
  cycle_id: string;

  @ManyToOne(() => DataCycle, { nullable: true, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'cycle_id' })
  cycle: DataCycle;

  @Column({ type: 'varchar' })
  @Index()
  origin_id: string;

  @Column({ type: 'varchar' })
  @Index()
  destination_id: string;

  @Column({ type: 'varchar' })
  @Index()
  route_type: string;

  @Column({ type: 'int' })
  route_number: number;

  @Column({ type: 'varchar' })
  route_string: string;

  @Column({ type: 'varchar', nullable: true })
  altitude: string;

  @Column({ type: 'varchar', nullable: true })
  aircraft: string;

  @Column({ type: 'varchar', nullable: true })
  direction: string;

  @Column({ type: 'varchar', nullable: true })
  hours: string;

  @Column({ type: 'varchar', nullable: true })
  area_description: string;

  @Column({ type: 'varchar', nullable: true })
  origin_city: string;

  @Column({ type: 'varchar', nullable: true })
  destination_city: string;

  @OneToMany(() => PreferredRouteSegment, (seg) => seg.route, {
    cascade: true,
  })
  segments: PreferredRouteSegment[];
}
