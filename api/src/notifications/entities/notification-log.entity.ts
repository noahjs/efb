import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  Index,
  Unique,
} from 'typeorm';

@Entity('u_notification_logs')
@Unique(['user_id', 'alert_type', 'alert_key'])
export class NotificationLog {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'uuid' })
  user_id: string;

  @Column({ type: 'varchar', length: 50 })
  alert_type: string;

  @Column({ type: 'varchar', length: 200 })
  alert_key: string;

  @Column({ type: 'varchar', length: 200 })
  title: string;

  @Column({ type: 'text', nullable: true })
  body: string | null;

  @Column({ type: 'timestamp', default: () => 'NOW()' })
  @Index()
  sent_at: Date;
}
