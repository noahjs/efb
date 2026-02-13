import {
  Entity,
  PrimaryColumn,
  Column,
  Index,
  UpdateDateColumn,
} from 'typeorm';

@Entity('a_weather_alerts')
export class WeatherAlert {
  @PrimaryColumn({ type: 'varchar', length: 200 })
  alert_id: string;

  @Column({ type: 'varchar', length: 100, nullable: true })
  event: string | null;

  @Column({ type: 'varchar', length: 20, nullable: true })
  @Index()
  severity: string | null;

  @Column({ type: 'varchar', length: 20, nullable: true })
  urgency: string | null;

  @Column({ type: 'varchar', length: 20, nullable: true })
  certainty: string | null;

  @Column({ type: 'text', nullable: true })
  headline: string | null;

  @Column({ type: 'text', nullable: true })
  description: string | null;

  @Column({ type: 'timestamp', nullable: true })
  effective: Date | null;

  @Column({ type: 'timestamp', nullable: true })
  expires: Date | null;

  @Column({ type: 'jsonb', nullable: true })
  geometry: any;

  @Column({ type: 'jsonb', nullable: true })
  properties: any;

  @UpdateDateColumn()
  updated_at: Date;
}
