import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { DataSource as TypeOrmDataSource } from 'typeorm';
import { spawn } from 'child_process';
import * as path from 'path';
import { DataSchedulerService } from '../data-platform/data-scheduler.service';
import { isWorkerRuntimeEnabled, serviceRole } from '../config/runtime-role';

type AdminJobPayload = {
  script: string;
  args: string[];
  command?: string; // default 'node'; use 'bash' for shell scripts
  scriptDir?: string; // default 'dist/seed'; use 'scripts' for shell scripts
};
type AdminJobData = { jobId: string; type: string; payload: AdminJobPayload };

@Injectable()
export class AdminJobWorkerService implements OnModuleInit {
  private readonly logger = new Logger(AdminJobWorkerService.name);
  private readonly workerRuntimeEnabled = isWorkerRuntimeEnabled();
  private readonly role = serviceRole();

  constructor(
    private readonly scheduler: DataSchedulerService,
    private readonly orm: TypeOrmDataSource,
  ) {}

  async onModuleInit() {
    await this.start();
  }

  async start() {
    if (!this.workerRuntimeEnabled) {
      this.logger.log({
        event: 'admin_job_worker_disabled',
        role: this.role,
        nodeEnv: process.env.NODE_ENV || 'development',
      });
      return;
    }

    await this.ensureAdminJobsTable();
    await this.scheduler.whenReady();

    await this.scheduler.boss.work(
      'admin-jobs',
      { localConcurrency: 1 },
      async (jobs) => {
        for (const job of jobs) {
          await this.processJob(job.data as AdminJobData);
        }
      },
    );

    this.logger.log({
      event: 'admin_job_worker_started',
      queue: 'admin-jobs',
      localConcurrency: 1,
    });
  }

  private async ensureAdminJobsTable() {
    await this.orm.query(`
      CREATE TABLE IF NOT EXISTS s_admin_jobs (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        label TEXT NOT NULL,
        status TEXT NOT NULL,
        started_at TIMESTAMPTZ,
        completed_at TIMESTAMPTZ,
        log_text TEXT NOT NULL DEFAULT '',
        progress TEXT
      );
    `);
    await this.orm.query(
      `CREATE INDEX IF NOT EXISTS idx_s_admin_jobs_started_at ON s_admin_jobs (started_at DESC);`,
    );
  }

  private async updateStatus(
    id: string,
    status: string,
    fields?: { progress?: string | null; completedAt?: Date | null },
  ) {
    const progress = fields?.progress ?? null;
    const completedAt = fields?.completedAt ?? null;

    await this.orm.query(
      `UPDATE s_admin_jobs
       SET status = $2,
           progress = COALESCE($3, progress),
           completed_at = COALESCE($4, completed_at)
       WHERE id = $1`,
      [id, status, progress, completedAt],
    );
  }

  private async appendLog(id: string, chunk: string, progress?: string) {
    await this.orm.query(
      `UPDATE s_admin_jobs
       SET log_text = right(log_text || $2, 50000),
           progress = COALESCE($3, progress)
       WHERE id = $1`,
      [id, chunk, progress ?? null],
    );
  }

  private async processJob(data: AdminJobData) {
    const { jobId, type, payload } = data;

    const command = payload.command || 'node';
    const scriptDir = payload.scriptDir || path.join('dist', 'seed');
    const scriptPath = path.join(process.cwd(), scriptDir, payload.script);
    const args = [scriptPath, ...(payload.args || [])];

    this.logger.log({
      event: 'admin_job_started',
      jobId,
      type,
      command,
      script: payload.script,
      args: payload.args || [],
    });

    await this.updateStatus(jobId, 'running', { progress: 'starting' });
    await this.appendLog(
      jobId,
      `Worker starting job.\nRunning: ${command} ${path.relative(
        process.cwd(),
        scriptPath,
      )} ${(payload.args || []).join(' ')}\n`,
    );

    const proc = spawn(command, args, {
      cwd: process.cwd(),
      env: { ...process.env },
    });

    let buf = '';
    let lastProgress: string | undefined;
    let flushing = Promise.resolve();
    const flush = async (force = false) => {
      if (!buf && !force) return;
      const chunk = buf;
      buf = '';
      if (chunk) {
        await this.appendLog(jobId, chunk, lastProgress);
      } else if (force && lastProgress) {
        // No new log content, but we may have a progress update.
        await this.updateStatus(jobId, 'running', { progress: lastProgress });
      }
    };
    const queueFlush = (force = false) => {
      flushing = flushing
        .then(() => flush(force))
        .catch((err) =>
          this.logger.error({ event: 'admin_job_flush_failed', jobId, err }),
        );
    };

    const onData = (dataBuf: Buffer, prefix?: string) => {
      const text = dataBuf.toString();
      const lines = text.split('\n').filter(Boolean);
      if (lines.length > 0) {
        lastProgress = lines[lines.length - 1];
      }
      const normalized =
        prefix && prefix.length > 0
          ? lines.map((l) => `${prefix}${l}`).join('\n') + '\n'
          : text;
      buf += normalized.endsWith('\n') ? normalized : normalized + '\n';
      // Throttle DB writes a bit; pg-boss will retry the whole job if we crash.
      queueFlush(false);
    };

    proc.stdout.on('data', (d: Buffer) => onData(d));
    proc.stderr.on('data', (d: Buffer) => onData(d, '[stderr] '));

    await new Promise<void>((resolve, reject) => {
      proc.on('error', reject);
      proc.on('close', (code: number | null) => {
        if (code === 0) resolve();
        else reject(new Error(`Exit code ${code}`));
      });
    })
      .then(async () => {
        queueFlush(true);
        await flushing;
        await this.appendLog(
          jobId,
          'Job completed successfully.\n',
          lastProgress,
        );
        await this.updateStatus(jobId, 'completed', {
          progress: lastProgress || 'completed',
          completedAt: new Date(),
        });
        this.logger.log({ event: 'admin_job_completed', jobId, type });
      })
      .catch(async (err) => {
        queueFlush(true);
        await flushing;
        const msg = err?.message || String(err);
        await this.appendLog(jobId, `Job failed: ${msg}\n`, lastProgress);
        await this.updateStatus(jobId, 'failed', {
          progress: lastProgress || 'failed',
          completedAt: new Date(),
        });
        this.logger.error({
          event: 'admin_job_failed',
          jobId,
          type,
          error: msg,
        });
        throw err;
      });
  }
}
