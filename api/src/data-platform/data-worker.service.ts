import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DataSource } from './entities/data-source.entity';
import { DataSchedulerService } from './data-scheduler.service';
import { BasePoller, PollerResult } from './pollers/base.poller';

@Injectable()
export class DataWorkerService {
  private readonly logger = new Logger(DataWorkerService.name);
  private pollers = new Map<string, BasePoller>();

  constructor(
    @InjectRepository(DataSource)
    private readonly dataSourceRepo: Repository<DataSource>,
    private readonly scheduler: DataSchedulerService,
  ) {}

  registerPoller(key: string, poller: BasePoller) {
    this.pollers.set(key, poller);
  }

  /** Call after all pollers are registered to start processing jobs. */
  async start() {
    await this.scheduler.whenReady();
    await this.scheduler.boss.work(
      'data-poll',
      { localConcurrency: 3 },
      async (jobs) => {
        for (const job of jobs) {
          const { key } = job.data as { key: string };
          await this.processJob(key);
        }
      },
    );
    this.logger.log(
      `Worker listening on data-poll queue (${this.pollers.size} pollers registered)`,
    );
  }

  private async processJob(key: string) {
    const poller = this.pollers.get(key);
    if (!poller) {
      this.logger.warn(`No poller registered for key: ${key}`);
      await this.dataSourceRepo.update(key, {
        status: 'failed',
        last_error: `No poller registered for key: ${key}`,
      });
      return;
    }

    // Set status to running
    await this.dataSourceRepo.update(key, {
      status: 'running',
      last_error: null,
    });

    const startTime = Date.now();

    try {
      const result: PollerResult = await poller.execute();
      const durationMs = Date.now() - startTime;

      await this.dataSourceRepo.update(key, {
        status: 'idle',
        last_completed_at: new Date(),
        last_duration_ms: durationMs,
        records_updated: result.recordsUpdated,
        last_error_count: result.errors,
        last_error: result.errors > 0 ? result.lastError : null,
      });

      if (result.errors > 0) {
        this.logger.warn(
          `${key}: ${result.recordsUpdated} records, ${result.errors} errors in ${durationMs}ms — ${result.lastError}`,
        );
      } else {
        this.logger.log(
          `${key}: ${result.recordsUpdated} records in ${durationMs}ms`,
        );
      }
    } catch (error) {
      const durationMs = Date.now() - startTime;
      const errorMessage = error?.message || String(error);

      await this.dataSourceRepo.update(key, {
        status: 'failed',
        last_error: errorMessage,
        last_duration_ms: durationMs,
      });

      this.logger.error(`${key} failed: ${errorMessage}`);
      throw error; // Let pg-boss handle retry
    }
  }
}
