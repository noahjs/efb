import { Entity, Column, PrimaryColumn } from 'typeorm';

@Entity('fixes')
export class Fix {
  @PrimaryColumn({ length: 10 })
  identifier: string;

  @Column({ type: 'float' })
  latitude: number;

  @Column({ type: 'float' })
  longitude: number;

  @Column({ type: 'varchar', nullable: true })
  state: string;

  @Column({ type: 'varchar', nullable: true })
  artcc_high: string;

  @Column({ type: 'varchar', nullable: true })
  artcc_low: string;
}
