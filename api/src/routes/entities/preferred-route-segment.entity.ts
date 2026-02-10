import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { PreferredRoute } from './preferred-route.entity';
import { DataGroup } from '../../config/constants';

@Entity('a_preferred_route_segments')
export class PreferredRouteSegment {
  static readonly DATA_GROUP = DataGroup.AVIATION;
  @PrimaryGeneratedColumn()
  id: number;

  @ManyToOne(() => PreferredRoute, (route) => route.segments, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'route_id' })
  route: PreferredRoute;

  @Column({ type: 'int' })
  sequence: number;

  @Column({ type: 'varchar' })
  value: string;

  @Column({ type: 'varchar' })
  type: string;

  @Column({ type: 'varchar', nullable: true })
  navaid_type: string;
}
