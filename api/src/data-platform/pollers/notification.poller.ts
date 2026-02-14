import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { BasePoller, PollerResult } from './base.poller';
import { NotificationDispatchService } from '../../notifications/notification-dispatch.service';
import { DataSource } from '../entities/data-source.entity';

@Injectable()
export class NotificationPoller extends BasePoller {
  constructor(
    private readonly dispatchService: NotificationDispatchService,
    @InjectRepository(DataSource)
    private readonly dataSourceRepo: Repository<DataSource>,
  ) {
    super('NotificationPoller');
  }

  async execute(): Promise<PollerResult> {
    // Use own last_completed_at as the "since" watermark
    const source = await this.dataSourceRepo.findOne({
      where: { key: 'notification_dispatch' },
    });
    const since = source?.last_completed_at ?? new Date(0);

    try {
      const sent = await this.dispatchService.dispatchNewAlerts(since);
      return { recordsUpdated: sent, errors: 0 };
    } catch (err) {
      this.logger.error(`Notification dispatch failed: ${err.message}`);
      return { recordsUpdated: 0, errors: 1, lastError: err.message };
    }
  }
}
