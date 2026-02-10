import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';
import { DataGroup } from '../../config/constants';

@Entity('u_certificates')
export class Certificate {
  static readonly DATA_GROUP = DataGroup.USER;
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar', nullable: true })
  certificate_type: string;

  @Column({ type: 'varchar', nullable: true })
  certificate_class: string;

  @Column({ type: 'varchar', nullable: true })
  certificate_number: string;

  @Column({ type: 'varchar', nullable: true })
  issue_date: string;

  @Column({ type: 'varchar', nullable: true })
  expiration_date: string;

  @Column({ type: 'text', nullable: true })
  ratings: string;

  @Column({ type: 'text', nullable: true })
  limitations: string;

  @Column({ type: 'text', nullable: true })
  comments: string;

  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;
}
