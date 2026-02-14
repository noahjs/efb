import { Entity, PrimaryColumn, Column } from 'typeorm';

@Entity('n_metar_category_cache')
export class MetarCategoryCache {
  @PrimaryColumn({ type: 'varchar', length: 10 })
  icao_id: string;

  @Column({ type: 'varchar', length: 10 })
  flight_category: string;

  @Column({ type: 'timestamp', default: () => 'NOW()' })
  checked_at: Date;
}
