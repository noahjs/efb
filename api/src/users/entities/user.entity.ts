import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  OneToMany,
} from 'typeorm';
import { StarredAirport } from './starred-airport.entity';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar' })
  name: string;

  @Column({ type: 'varchar' })
  email: string;

  @CreateDateColumn()
  created_at: Date;

  @OneToMany(() => StarredAirport, (sa) => sa.user)
  starred_airports: StarredAirport[];
}
