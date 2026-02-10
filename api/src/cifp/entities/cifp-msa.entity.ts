import { Entity, Column, PrimaryGeneratedColumn, Index } from 'typeorm';

@Entity('cifp_msa')
export class CifpMsa {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar' })
  @Index()
  airport_identifier: string;

  @Column({ type: 'varchar' })
  @Index()
  icao_identifier: string;

  @Column({ type: 'varchar', length: 5 })
  msa_center: string;

  @Column({ type: 'varchar', length: 2, nullable: true })
  msa_center_icao: string;

  @Column({ type: 'varchar', length: 1, nullable: true })
  multiple_code: string;

  @Column({ type: 'jsonb' })
  sectors: {
    bearing_from: number;
    bearing_to: number;
    altitude: number;
    radius: number;
  }[];

  @Column({ type: 'varchar', length: 1, nullable: true })
  magnetic_true_indicator: string;

  @Column({ type: 'varchar', length: 4 })
  cycle: string;
}
