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

  @CreateDateColumn()
  created_at: Date;

  @OneToMany(() => StarredAirport, (sa) => sa.user)
  starred_airports: StarredAirport[];
}
