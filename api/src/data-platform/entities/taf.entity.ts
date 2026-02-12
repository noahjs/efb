import {
  Entity,
  PrimaryColumn,
  Column,
  Index,
  UpdateDateColumn,
} from 'typeorm';

@Entity('a_tafs')
export class Taf {
  @PrimaryColumn({ type: 'varchar', length: 10 })
  icao_id: string;

  @Column({ type: 'float', nullable: true })
  @Index()
  latitude: number | null;

  @Column({ type: 'float', nullable: true })
  @Index()
  longitude: number | null;

  @Column({ type: 'text', nullable: true })
  raw_taf: string | null;

  @Column({ type: 'jsonb', nullable: true })
  fcsts: any;

  @Column({ type: 'jsonb', nullable: true })
  raw_data: any;

  @UpdateDateColumn()
  updated_at: Date;
}
