import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('endorsements')
export class Endorsement {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar', nullable: true })
  date: string;

  @Column({ type: 'varchar', nullable: true })
  endorsement_type: string;

  @Column({ type: 'varchar', nullable: true })
  far_reference: string;

  @Column({ type: 'text', nullable: true })
  endorsement_text: string;

  @Column({ type: 'varchar', nullable: true })
  cfi_name: string;

  @Column({ type: 'varchar', nullable: true })
  cfi_certificate_number: string;

  @Column({ type: 'varchar', nullable: true })
  cfi_expiration_date: string;

  @Column({ type: 'varchar', nullable: true })
  expiration_date: string;

  @Column({ type: 'text', nullable: true })
  comments: string;

  @CreateDateColumn()
  created_at: Date;

  @UpdateDateColumn()
  updated_at: Date;
}
