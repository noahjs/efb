import { Entity, PrimaryColumn, Column, UpdateDateColumn } from 'typeorm';

@Entity('a_nws_forecasts')
export class NwsForecast {
  @PrimaryColumn({ type: 'varchar', length: 10 })
  icao_id: string;

  @Column({ type: 'varchar', length: 10, nullable: true })
  grid_id: string | null;

  @Column({ type: 'int', nullable: true })
  grid_x: number | null;

  @Column({ type: 'int', nullable: true })
  grid_y: number | null;

  @Column({ type: 'jsonb', nullable: true })
  forecast_data: any;

  @UpdateDateColumn()
  updated_at: Date;
}
