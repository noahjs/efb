import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Aircraft } from '../../aircraft/entities/aircraft.entity';
import { DocumentFolder } from './document-folder.entity';
import { DataGroup } from '../../config/constants';

@Entity('u_documents')
export class Document {
  static readonly DATA_GROUP = DataGroup.USER;
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'uuid', nullable: true })
  user_id: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE', nullable: true })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ type: 'integer', nullable: true })
  aircraft_id: number | null;

  @ManyToOne(() => Aircraft, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'aircraft_id' })
  aircraft: Aircraft;

  @Column({ type: 'integer', nullable: true })
  folder_id: number | null;

  @ManyToOne(() => DocumentFolder, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'folder_id' })
  folder: DocumentFolder;

  @Column({ type: 'varchar' })
  original_name: string;

  @Column({ type: 'varchar' })
  filename: string;

  @Column({ type: 'varchar' })
  mime_type: string;

  @Column({ type: 'integer' })
  size_bytes: number;

  @Column({ type: 'varchar' })
  s3_key: string;

  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;
}
