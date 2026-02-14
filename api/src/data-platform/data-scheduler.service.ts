import {
  Injectable,
  Logger,
  OnModuleInit,
  OnModuleDestroy,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Cron } from '@nestjs/schedule';
import { PgBoss } from 'pg-boss';
import { DataSource } from './entities/data-source.entity';
import { DataCleanupService } from './data-cleanup.service';
import { dbConfig } from '../db.config';
import { isWorkerRuntimeEnabled, serviceRole } from '../config/runtime-role';

const INITIAL_SOURCES = [
  {
    key: 'metar_poll',
    name: 'METAR Poller (AWC by state)',
    interval_seconds: 300,
  },
  { key: 'taf_poll', name: 'TAF Poller (AWC CONUS)', interval_seconds: 7200 },
  {
    key: 'winds_aloft_poll',
    name: 'Winds Aloft Poller (AWC text)',
    interval_seconds: 3600,
  },
  {
    key: 'notam_poll',
    name: 'NOTAM Poller (top airports)',
    interval_seconds: 1800,
  },
  {
    key: 'advisory_poll',
    name: 'Advisory Poller (AIRMETs + SIGMETs + CWAs)',
    interval_seconds: 300,
  },
  {
    key: 'pirep_poll',
    name: 'PIREP Poller (AWC CONUS)',
    interval_seconds: 300,
  },
  {
    key: 'tfr_poll',
    name: 'TFR Poller (FAA WFS + metadata)',
    interval_seconds: 900,
  },
  {
    key: 'wind_grid_poll',
    name: 'Wind Grid Poller (Open-Meteo CONUS)',
    interval_seconds: 3600,
  },
  {
    key: 'fuel_price_poll',
    name: 'Fuel Price Poller (AirNav)',
    interval_seconds: 604800,
  },
  {
    key: 'fbo_poll',
    name: 'FBO Poller (AirNav)',
    interval_seconds: 2592000,
  },
  {
    key: 'storm_cell_poll',
    name: 'Storm Cell Poller (Xweather)',
    interval_seconds: 180,
  },
  {
    key: 'lightning_threat_poll',
    name: 'Lightning Threat Poller (Xweather)',
    interval_seconds: 180,
  },
  {
    key: 'weather_alert_poll',
    name: 'Weather Alert Poller (NWS)',
    interval_seconds: 300,
  },
  {
    key: 'hrrr_poll',
    name: 'HRRR Weather Pipeline (NOAA S3)',
    interval_seconds: 3600,
  },
  {
    key: 'notification_dispatch',
    name: 'Notification Dispatch',
    interval_seconds: 120,
  },
];

@Injectable()
export class DataSchedulerService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DataSchedulerService.name);
  boss: PgBoss;
  private readonly workerRuntimeEnabled = isWorkerRuntimeEnabled();
  private readonly role = serviceRole();
  private readyPromise: Promise<void>;
  private resolveReady: () => void;

  constructor(
    @InjectRepository(DataSource)
    private readonly dataSourceRepo: Repository<DataSource>,
    private readonly cleanupService: DataCleanupService,
  ) {
    this.boss = new PgBoss({
      host: dbConfig.host,
      port: dbConfig.port,
      user: dbConfig.username,
      password: dbConfig.password,
      database: dbConfig.database,
      max: 5,
    });
    this.readyPromise = new Promise((resolve) => {
      this.resolveReady = resolve;
    });
  }

  /** Resolves once pg-boss has started and is ready for work(). */
  async whenReady(): Promise<void> {
    return this.readyPromise;
  }

  async onModuleInit() {
    if (!this.workerRuntimeEnabled) {
      this.resolveReady();
      this.logger.log({
        event: 'pgboss_disabled',
        role: this.role,
        nodeEnv: process.env.NODE_ENV || 'development',
      });
      return;
    }

    await this.boss.start();
    await this.boss.createQueue('data-poll');
    this.resolveReady();
    this.logger.log({ event: 'pgboss_started', queue: 'data-poll' });
    await this.seedDataSources();

    // Crash recovery: reset any jobs stuck in 'running' from a prior crash
    const stuck = await this.dataSourceRepo.update(
      { status: 'running' },
      { status: 'idle', last_error: 'Reset after server restart' },
    );
    if ((stuck.affected ?? 0) > 0) {
      this.logger.warn({
        event: 'poller_stuck_jobs_reset',
        resetCount: stuck.affected,
      });
    }
  }

  async onModuleDestroy() {
    if (!this.workerRuntimeEnabled) {
      return;
    }
    await this.boss.stop({ graceful: true, timeout: 10000 });
    this.logger.log({ event: 'pgboss_stopped', queue: 'data-poll' });
  }

  private async seedDataSources() {
    for (const src of INITIAL_SOURCES) {
      const existing = await this.dataSourceRepo.findOne({
        where: { key: src.key },
      });
      if (!existing) {
        await this.dataSourceRepo.save({
          key: src.key,
          name: src.name,
          interval_seconds: src.interval_seconds,
          status: 'idle',
          enabled: true,
        });
        this.logger.log({
          event: 'poller_source_seeded',
          key: src.key,
          intervalSeconds: src.interval_seconds,
        });
      }
    }

    // Remove deprecated data sources that no longer have pollers
    const removed = await this.dataSourceRepo.delete({ key: 'nws_grid_poll' });
    if ((removed.affected ?? 0) > 0) {
      this.logger.log({
        event: 'poller_source_removed',
        key: 'nws_grid_poll',
      });
    }
  }

  @Cron('*/60 * * * * *') // Every 60 seconds
  async checkAndEnqueue() {
    if (!this.workerRuntimeEnabled) {
      return;
    }

    const sources = await this.dataSourceRepo.find({
      where: { enabled: true, status: In(['idle', 'failed']) },
    });

    const now = Date.now();

    for (const source of sources) {
      const lastRequested = source.last_requested_at
        ? source.last_requested_at.getTime()
        : 0;
      const intervalMs = source.interval_seconds * 1000;
      const elapsed = now - lastRequested;

      if (elapsed >= intervalMs) {
        // Atomically set status to 'queued' to prevent re-enqueue
        const result = await this.dataSourceRepo
          .createQueryBuilder()
          .update(DataSource)
          .set({
            status: 'queued',
            last_requested_at: new Date(),
          })
          .where('key = :key AND status IN (:...statuses)', {
            key: source.key,
            statuses: ['idle', 'failed'],
          })
          .execute();

        if ((result.affected ?? 0) === 1) {
          await this.boss.send(
            'data-poll',
            { key: source.key },
            {
              singletonKey: source.key,
              expireInSeconds: Math.min(source.interval_seconds * 2, 86400),
            },
          );
          this.logger.log({
            event: 'poller_job_enqueued',
            key: source.key,
            intervalSeconds: source.interval_seconds,
          });
        }
      }
    }
  }

  @Cron('0 */15 * * * *') // Every 15 minutes
  async cleanupStaleData() {
    if (!this.workerRuntimeEnabled) {
      return;
    }
    await this.cleanupService.cleanup();
  }

  async getDataSources(): Promise<DataSource[]> {
    return this.dataSourceRepo.find({ order: { key: 'ASC' } });
  }

  async restartPoller(key: string) {
    if (!this.workerRuntimeEnabled) {
      throw new Error(
        `Poller restart unavailable when SERVICE_ROLE='${this.role}' in production`,
      );
    }

    const source = await this.dataSourceRepo.findOne({ where: { key } });
    if (!source) {
      throw new Error(`Data source not found: ${key}`);
    }

    // Cancel any existing pg-boss jobs for this key
    const activeJobs: { id: string }[] = await this.dataSourceRepo.query(
      `SELECT id FROM pgboss.job WHERE name = 'data-poll' AND singleton_key = $1 AND state IN ('created', 'active', 'retry')`,
      [key],
    );
    if (activeJobs.length > 0) {
      const ids = activeJobs.map((j) => j.id);
      await this.boss.cancel('data-poll', ids);
      this.logger.log({
        event: 'poller_jobs_cancelled',
        key,
        cancelledCount: ids.length,
      });
    }

    // Reset data source and enqueue a fresh job
    await this.dataSourceRepo.update(key, {
      status: 'queued',
      last_requested_at: new Date(),
      last_error: null,
    });

    await this.boss.send(
      'data-poll',
      { key },
      {
        singletonKey: key,
        expireInSeconds: Math.min(source.interval_seconds * 2, 86400),
      },
    );

    this.logger.log({ event: 'poller_restarted', key });
  }
}
