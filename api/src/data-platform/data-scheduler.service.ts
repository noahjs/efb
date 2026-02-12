import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Cron } from '@nestjs/schedule';
import { PgBoss } from 'pg-boss';
import { DataSource } from './entities/data-source.entity';
import { dbConfig } from '../db.config';

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
    key: 'nws_grid_poll',
    name: 'NWS Grid Mapping (permanent cache)',
    interval_seconds: 86400,
  },
];

@Injectable()
export class DataSchedulerService implements OnModuleInit {
  private readonly logger = new Logger(DataSchedulerService.name);
  boss: PgBoss;

  constructor(
    @InjectRepository(DataSource)
    private readonly dataSourceRepo: Repository<DataSource>,
  ) {
    this.boss = new PgBoss({
      host: dbConfig.host,
      port: dbConfig.port,
      user: dbConfig.username,
      password: dbConfig.password,
      database: dbConfig.database,
    });
  }

  async onModuleInit() {
    await this.boss.start();
    this.logger.log('pg-boss started');
    await this.seedDataSources();
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
        this.logger.log(`Seeded data source: ${src.key}`);
      }
    }
  }

  @Cron('*/60 * * * * *') // Every 60 seconds
  async checkAndEnqueue() {
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

        if (result.affected === 1) {
          await this.boss.send(
            'data-poll',
            { key: source.key },
            {
              singletonKey: source.key,
              expireInSeconds: source.interval_seconds * 2,
            },
          );
          this.logger.log(`Enqueued job: ${source.key}`);
        }
      }
    }
  }

  async getDataSources(): Promise<DataSource[]> {
    return this.dataSourceRepo.find({ order: { key: 'ASC' } });
  }
}
