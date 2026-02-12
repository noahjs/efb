import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  UpdateDateColumn,
  Unique,
} from 'typeorm';

@Entity('a_winds_aloft')
@Unique(['station_code', 'forecast_period'])
export class WindsAloft {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar', length: 10 })
  station_code: string;

  @Column({ type: 'varchar', length: 5 })
  forecast_period: string;

  @Column({ type: 'jsonb', nullable: true })
  altitudes: any;

  @UpdateDateColumn()
  updated_at: Date;
}
