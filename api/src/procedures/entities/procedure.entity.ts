import { Entity, Column, PrimaryGeneratedColumn, Index } from 'typeorm';

@Entity('procedures')
export class Procedure {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar' })
  @Index()
  airport_identifier: string;

  @Column({ type: 'varchar' })
  @Index()
  chart_code: string;

  @Column({ type: 'varchar' })
  chart_name: string;

  @Column({ type: 'varchar' })
  pdf_name: string;

  @Column({ type: 'int', default: 0 })
  chart_seq: number;

  @Column({ type: 'varchar', nullable: true })
  user_action: string;

  @Column({ type: 'varchar', nullable: true })
  faanfd18: string;

  @Column({ type: 'varchar', nullable: true })
  copter: string;

  @Column({ type: 'varchar' })
  cycle: string;

  @Column({ type: 'varchar', nullable: true })
  state_code: string;

  @Column({ type: 'varchar', nullable: true })
  city_name: string;

  @Column({ type: 'varchar', nullable: true })
  volume: string;
}
