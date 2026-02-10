import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Unique,
} from 'typeorm';
import { User } from './user.entity';
import { DataGroup } from '../../config/constants';

@Entity('u_starred_airports')
@Unique(['user_id', 'airport_identifier'])
export class StarredAirport {
  static readonly DATA_GROUP = DataGroup.USER;

  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'uuid' })
  user_id: string;

  @Column({ type: 'varchar' })
  airport_identifier: string;

  @CreateDateColumn()
  created_at: Date;

  @ManyToOne(() => User, (user) => user.starred_airports)
  @JoinColumn({ name: 'user_id' })
  user: User;
}
