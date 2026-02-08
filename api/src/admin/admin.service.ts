import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Airport } from '../airports/entities/airport.entity';
import { Runway } from '../airports/entities/runway.entity';
import { Frequency } from '../airports/entities/frequency.entity';
import { spawn } from 'child_process';
import * as path from 'path';
import * as fs from 'fs';

// All FAA VFR Sectional chart names
export const VFR_SECTIONAL_CHARTS = [
  'Albuquerque',
  'Anchorage',
  'Atlanta',
  'Bethel',
  'Billings',
  'Brownsville',
  'Cape_Lisburne',
  'Charlotte',
  'Cheyenne',
  'Chicago',
  'Cincinnati',
  'Cold_Bay',
  'Dallas-Ft_Worth',
  'Dawson',
  'Denver',
  'Detroit',
  'Dutch_Harbor',
  'El_Paso',
  'Fairbanks',
  'Great_Falls',
  'Green_Bay',
  'Halifax',
  'Hawaiian_Islands',
  'Houston',
  'Jacksonville',
  'Juneau',
  'Kansas_City',
  'Ketchikan',
  'Klamath_Falls',
  'Kodiak',
  'Lake_Huron',
  'Las_Vegas',
  'Los_Angeles',
  'McGrath',
  'Memphis',
  'Miami',
  'Montreal',
  'New_Orleans',
  'New_York',
  'Nome',
  'Omaha',
  'Phoenix',
  'Point_Barrow',
  'Salt_Lake_City',
  'San_Antonio',
  'San_Francisco',
  'Seattle',
  'Seward',
  'St_Louis',
  'Twin_Cities',
  'Washington',
  'Western_Aleutian_Islands',
  'Wichita',
];

export interface JobStatus {
  id: string;
  type: string;
  label: string;
  status: 'idle' | 'running' | 'completed' | 'failed';
  startedAt?: string;
  completedAt?: string;
  log: string[];
  progress?: string;
}

@Injectable()
export class AdminService {
  private readonly logger = new Logger(AdminService.name);
  private readonly dataDir = path.join(__dirname, '..', '..', 'data');
  private readonly scriptsDir = path.join(__dirname, '..', '..', 'scripts');
  private jobs: Map<string, JobStatus> = new Map();

  constructor(
    @InjectRepository(Airport) private airportRepo: Repository<Airport>,
    @InjectRepository(Runway) private runwayRepo: Repository<Runway>,
    @InjectRepository(Frequency) private freqRepo: Repository<Frequency>,
  ) {}

  // --- Data inventory ---

  async getOverview() {
    const airports = await this.airportRepo.count();
    const runways = await this.runwayRepo.count();
    const frequencies = await this.freqRepo.count();
    const charts = this.getInstalledCharts();
    const diskUsage = this.getDiskUsage();

    return {
      database: { airports, runways, frequencies },
      charts: {
        installed: charts,
        available: VFR_SECTIONAL_CHARTS,
        installedCount: charts.length,
        totalAvailable: VFR_SECTIONAL_CHARTS.length,
      },
      disk: diskUsage,
      jobs: Array.from(this.jobs.values()),
    };
  }

  getInstalledCharts(): string[] {
    const chartsDir = path.join(
      this.dataDir,
      'charts',
      'tiles',
      'vfr-sectional',
    );
    if (!fs.existsSync(chartsDir)) return [];
    return fs
      .readdirSync(chartsDir, { withFileTypes: true })
      .filter((d) => d.isDirectory())
      .map((d) => d.name);
  }

  getDiskUsage(): Record<string, string> {
    const result: Record<string, string> = {};

    const dbPath = path.join(this.dataDir, 'efb.sqlite');
    if (fs.existsSync(dbPath)) {
      result.database = this.formatBytes(fs.statSync(dbPath).size);
    }

    const rawDir = path.join(this.dataDir, 'charts', 'raw');
    if (fs.existsSync(rawDir)) {
      result.chartsRaw = this.formatBytes(this.dirSize(rawDir));
    }

    const tilesDir = path.join(this.dataDir, 'charts', 'tiles');
    if (fs.existsSync(tilesDir)) {
      result.chartsTiles = this.formatBytes(this.dirSize(tilesDir));
    }

    return result;
  }

  // --- Job management ---

  getJobs(): JobStatus[] {
    return Array.from(this.jobs.values());
  }

  getJob(id: string): JobStatus | undefined {
    return this.jobs.get(id);
  }

  // --- Seed airports ---

  async runSeedAirports(): Promise<JobStatus> {
    const jobId = `seed-airports-${Date.now()}`;
    const job: JobStatus = {
      id: jobId,
      type: 'seed-airports',
      label: 'Seed Airport Database (FAA NASR)',
      status: 'running',
      startedAt: new Date().toISOString(),
      log: ['Starting airport data seed...'],
    };
    this.jobs.set(jobId, job);

    const seedScript = path.join(this.scriptsDir, '..', 'src', 'seed', 'seed.ts');
    this.runScript(
      'npx',
      ['ts-node', '-r', 'tsconfig-paths/register', seedScript],
      job,
    );

    return job;
  }

  // --- Process VFR charts ---

  async runProcessChart(chartName: string): Promise<JobStatus> {
    const jobId = `chart-${chartName}-${Date.now()}`;
    const job: JobStatus = {
      id: jobId,
      type: 'process-chart',
      label: `Process VFR Sectional: ${chartName}`,
      status: 'running',
      startedAt: new Date().toISOString(),
      log: [`Starting chart processing for ${chartName}...`],
    };
    this.jobs.set(jobId, job);

    const script = path.join(this.scriptsDir, 'process-vfr-charts.sh');
    this.runScript('bash', [script, chartName], job);

    return job;
  }

  // --- Delete chart tiles ---

  async deleteChart(chartName: string): Promise<{ deleted: boolean }> {
    const tilesDir = path.join(
      this.dataDir,
      'charts',
      'tiles',
      'vfr-sectional',
      chartName,
    );
    const rawFiles = [
      path.join(this.dataDir, 'charts', 'raw', `${chartName}.zip`),
      path.join(this.dataDir, 'charts', 'raw', `${chartName}_rgba.tif`),
      path.join(this.dataDir, 'charts', 'raw', `${chartName}_3857.tif`),
    ];

    let deleted = false;

    if (fs.existsSync(tilesDir)) {
      fs.rmSync(tilesDir, { recursive: true, force: true });
      deleted = true;
    }

    for (const f of rawFiles) {
      if (fs.existsSync(f)) {
        fs.unlinkSync(f);
        deleted = true;
      }
    }

    // Also remove extracted directory
    const extractedDir = path.join(this.dataDir, 'charts', 'raw', chartName);
    if (fs.existsSync(extractedDir)) {
      fs.rmSync(extractedDir, { recursive: true, force: true });
    }

    return { deleted };
  }

  // --- Helpers ---

  private runScript(command: string, args: string[], job: JobStatus) {
    const cwd = path.join(__dirname, '..', '..');
    const proc = spawn(command, args, {
      cwd,
      env: { ...process.env },
      shell: true,
    });

    proc.stdout.on('data', (data: Buffer) => {
      const lines = data.toString().split('\n').filter(Boolean);
      job.log.push(...lines);
      // Keep last line as progress
      if (lines.length > 0) {
        job.progress = lines[lines.length - 1];
      }
    });

    proc.stderr.on('data', (data: Buffer) => {
      const lines = data
        .toString()
        .split('\n')
        .filter(Boolean)
        .map((l) => `[stderr] ${l}`);
      job.log.push(...lines);
    });

    proc.on('close', (code: number | null) => {
      job.status = code === 0 ? 'completed' : 'failed';
      job.completedAt = new Date().toISOString();
      job.log.push(
        code === 0
          ? 'Job completed successfully.'
          : `Job failed with exit code ${code}.`,
      );
      this.logger.log(`Job ${job.id} finished: ${job.status}`);
    });

    proc.on('error', (err: Error) => {
      job.status = 'failed';
      job.completedAt = new Date().toISOString();
      job.log.push(`Error: ${err.message}`);
    });
  }

  private dirSize(dir: string): number {
    let total = 0;
    try {
      const entries = fs.readdirSync(dir, { withFileTypes: true });
      for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);
        if (entry.isFile()) {
          total += fs.statSync(fullPath).size;
        } else if (entry.isDirectory()) {
          total += this.dirSize(fullPath);
        }
      }
    } catch {
      // ignore
    }
    return total;
  }

  private formatBytes(bytes: number): string {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return `${(bytes / Math.pow(k, i)).toFixed(1)} ${sizes[i]}`;
  }
}
