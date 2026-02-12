import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  OneToMany,
} from 'typeorm';
import { StarredAirport } from './starred-airport.entity';
import { DataGroup } from '../../config/constants';

@Entity('s_users')
export class User {
  static readonly DATA_GROUP = DataGroup.SYSTEM;
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar' })
  name: string;

  @Column({ type: 'varchar', unique: true })
  email: string;

  @Column({ type: 'varchar', nullable: true, select: false })
  password_hash: string;

  @Column({ type: 'varchar', default: 'email' })
  auth_provider: string;

  @Column({ type: 'varchar', nullable: true, unique: true })
  provider_id: string;

  @Column({ type: 'boolean', default: false })
  email_verified: boolean;

  @Column({ type: 'varchar', default: 'user' })
  role: string;

  @Column({ type: 'varchar', nullable: true, select: false })
  refresh_token_hash: string;

  @Column({ type: 'varchar', nullable: true })
  pilot_name: string;

  @Column({ type: 'varchar', nullable: true })
  phone_number: string;

  @Column({ type: 'varchar', nullable: true })
  pilot_certificate_number: string;

  @Column({ type: 'varchar', nullable: true })
  pilot_certificate_type: string;

  @Column({ type: 'varchar', nullable: true })
  home_base: string;

  @Column({ type: 'varchar', nullable: true })
  leidos_username: string;

  @Column({ type: 'simple-array', nullable: true })
  fuel_programs: string[];

  @CreateDateColumn()
  created_at: Date;

  @OneToMany(() => StarredAirport, (sa) => sa.user)
  starred_airports: StarredAirport[];
}
