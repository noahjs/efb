import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  Index,
  UpdateDateColumn,
  Unique,
} from 'typeorm';

@Entity('a_wind_grid')
@Unique(['lat', 'lng', 'model'])
export class WindGrid {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'float' })
  @Index()
  lat: number;

  @Column({ type: 'float' })
  @Index()
  lng: number;

  @Column({ type: 'varchar', length: 30, default: 'gfs_seamless' })
  model: string;

  @Column({ type: 'jsonb', nullable: true })
  levels: any;

  @UpdateDateColumn()
  updated_at: Date;
}
