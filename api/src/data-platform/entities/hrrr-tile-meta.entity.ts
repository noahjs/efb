import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  Index,
  Unique,
  CreateDateColumn,
} from 'typeorm';

@Entity('a_hrrr_tile_meta')
@Unique(['init_time', 'forecast_hour', 'product', 'level'])
export class HrrrTileMeta {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'timestamptz' })
  @Index()
  init_time: Date;

  @Column({ type: 'int' })
  forecast_hour: number;

  @Column({ type: 'varchar', length: 30 })
  product: string;

  @Column({ type: 'varchar', length: 30, nullable: true })
  level: string;

  @Column({ type: 'timestamptz' })
  valid_time: Date;

  @Column({ type: 'varchar', length: 255 })
  tile_path: string;

  @Column({ type: 'int', default: 0 })
  tile_count: number;

  @CreateDateColumn()
  created_at: Date;
}
