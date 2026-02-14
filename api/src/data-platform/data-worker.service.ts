import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DataSource } from './entities/data-source.entity';
import { PollerRun } from './entities/poller-run.entity';
import { DataSchedulerService } from './data-scheduler.service';
import { BasePoller, PollerResult } from './pollers/base.poller';
import { isWorkerRuntimeEnabled, serviceRole } from '../config/runtime-role';

@Injectable()
export class DataWorkerService {
  private readonly logger = new Logger(DataWorkerService.name);
  private readonly workerRuntimeEnabled = isWorkerRuntimeEnabled();
  private readonly role = serviceRole();
  private pollers = new Map<string, BasePoller>();

  constructor(
    @InjectRepository(DataSource)
    private readonly dataSourceRepo: Repository<DataSource>,
    @InjectRepository(PollerRun)
    private readonly pollerRunRepo: Repository<PollerRun>,
    private readonly scheduler: DataSchedulerService,
  ) {}

  registerPoller(key: string, poller: BasePoller) {
    this.pollers.set(key, poller);
  }

  /** Call after all pollers are registered to start processing jobs. */
  async start() {
    if (!this.workerRuntimeEnabled) {
      this.logger.log({
        event: 'poller_worker_disabled',
        role: this.role,
        nodeEnv: process.env.NODE_ENV || 'development',
      });
      return;
    }

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
    this.logger.log({
      event: 'poller_worker_started',
      queue: 'data-poll',
      registeredPollers: this.pollers.size,
      localConcurrency: 3,
    });
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

    const startedAt = new Date();
    const startTime = Date.now();

    try {
      const result: PollerResult = await poller.execute();
      const durationMs = Date.now() - startTime;
      const completedAt = new Date();
      const hasErrors = result.errors > 0;
      const runStatus = hasErrors ? 'partial' : 'success';

      // Record the run
      await this.pollerRunRepo.save({
        data_source_key: key,
        status: runStatus,
        started_at: startedAt,
        completed_at: completedAt,
        duration_ms: durationMs,
        records_updated: result.recordsUpdated,
        error_count: result.errors,
        error_message: hasErrors ? result.lastError : null,
      });

      // Update DataSource with atomic aggregate increments
      await this.dataSourceRepo
        .createQueryBuilder()
        .update(DataSource)
        .set({
          status: 'idle',
          last_completed_at: completedAt,
          last_duration_ms: durationMs,
          records_updated: result.recordsUpdated,
          last_error_count: result.errors,
          last_error: hasErrors ? result.lastError : null,
          consecutive_failures: hasErrors
            ? () => 'consecutive_failures + 1'
            : 0,
          total_runs: () => 'total_runs + 1',
          total_successes: hasErrors
            ? () => 'total_successes'
            : () => 'total_successes + 1',
        } as any)
        .where('key = :key', { key })
        .execute();

      if (hasErrors) {
        this.logger.warn({
          event: 'poller_run_partial',
          pollerKey: key,
          durationMs,
          recordsUpdated: result.recordsUpdated,
          errors: result.errors,
          lastError: result.lastError || null,
        });
      } else {
        this.logger.log({
          event: 'poller_run_success',
          pollerKey: key,
          durationMs,
          recordsUpdated: result.recordsUpdated,
          errors: 0,
        });
      }
    } catch (error) {
      const durationMs = Date.now() - startTime;
      const completedAt = new Date();
      const errorMessage = error?.message || String(error);

      // Record the failed run
      await this.pollerRunRepo.save({
        data_source_key: key,
        status: 'failed' as const,
        started_at: startedAt,
        completed_at: completedAt,
        duration_ms: durationMs,
        records_updated: 0,
        error_count: 1,
        error_message: errorMessage,
      });

      // Update DataSource with atomic aggregate increments
      await this.dataSourceRepo
        .createQueryBuilder()
        .update(DataSource)
        .set({
          status: 'failed',
          last_error: errorMessage,
          last_duration_ms: durationMs,
          consecutive_failures: () => 'consecutive_failures + 1',
          total_runs: () => 'total_runs + 1',
        } as any)
        .where('key = :key', { key })
        .execute();

      this.logger.error({
        event: 'poller_run_failed',
        pollerKey: key,
        durationMs,
        error: errorMessage,
      });
      throw error; // Let pg-boss handle retry
    }
  }
}
