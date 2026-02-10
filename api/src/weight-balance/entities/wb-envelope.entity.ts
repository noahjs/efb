import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  ManyToOne,
  JoinColumn,
  Unique,
} from 'typeorm';
import { WBProfile } from './wb-profile.entity';

@Entity('wb_envelopes')
@Unique(['wb_profile_id', 'envelope_type', 'axis'])
export class WBEnvelope {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'integer' })
  wb_profile_id: number;

  @ManyToOne(() => WBProfile, (p) => p.envelopes, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'wb_profile_id' })
  profile: WBProfile;

  @Column({ type: 'varchar' })
  envelope_type: string;

  @Column({ type: 'varchar', default: 'longitudinal' })
  axis: string;

  @Column({ type: 'jsonb' })
  points: { weight: number; cg: number }[];
}
