import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  Index,
} from 'typeorm';
import { DataGroup } from '../../config/constants';

@Entity('a_atis_recordings')
export class AtisRecording {
  static readonly DATA_GROUP = DataGroup.AVIATION;

  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar', length: 10 })
  @Index()
  icao: string;

  @Column({ type: 'varchar' })
  gcs_key: string;

  @Column({ type: 'timestamp' })
  recorded_at: Date;

  @Column({ type: 'int' })
  size_bytes: number;

  @CreateDateColumn()
  created_at: Date;
}
