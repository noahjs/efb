import { Entity, Column, PrimaryGeneratedColumn, Index } from 'typeorm';

@Entity('artcc_boundaries')
export class ArtccBoundary {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar', length: 10 })
  @Index()
  artcc_id: string;

  @Column({ type: 'varchar', nullable: true })
  name: string;

  @Column({ type: 'varchar', length: 10 })
  altitude: string;

  @Column({ type: 'text' })
  geometry_json: string;

  @Column({ type: 'float' })
  min_lat: number;

  @Column({ type: 'float' })
  max_lat: number;

  @Column({ type: 'float' })
  min_lng: number;

  @Column({ type: 'float' })
  max_lng: number;
}
