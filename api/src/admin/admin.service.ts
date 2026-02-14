import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource as TypeOrmDataSource, Repository } from 'typeorm';
import { MasterWBProfile } from '../aircraft/entities/master-wb-profile.entity';
import { GoogleAuth } from 'google-auth-library';
import axios from 'axios';
import { Airport } from '../airports/entities/airport.entity';
import { Runway } from '../airports/entities/runway.entity';
import { Frequency } from '../airports/entities/frequency.entity';
import { Navaid } from '../navaids/entities/navaid.entity';
import { Fix } from '../navaids/entities/fix.entity';
import { Procedure } from '../procedures/entities/procedure.entity';
import { DtppCycle } from '../procedures/entities/dtpp-cycle.entity';
import { FaaRegistryAircraft } from '../registry/entities/faa-registry-aircraft.entity';
import { Fbo } from '../fbos/entities/fbo.entity';
import { FuelPrice } from '../fbos/entities/fuel-price.entity';
import { Metar } from '../data-platform/entities/metar.entity';
import { Taf } from '../data-platform/entities/taf.entity';
import { DataSource as DataSourceEntity } from '../data-platform/entities/data-source.entity';
import { PollerRun } from '../data-platform/entities/poller-run.entity';
import { WeatherService } from '../weather/weather.service';
import { ImageryService } from '../imagery/imagery.service';
import { WindyService } from '../windy/windy.service';
import { ElevationService } from '../windy/elevation.service';
import { TrafficService } from '../traffic/traffic.service';
import { LeidosService } from '../filing/leidos.service';
import { DataSchedulerService } from '../data-platform/data-scheduler.service';
import { PgBoss } from 'pg-boss';
import { spawn } from 'child_process';
import * as path from 'path';
import * as fs from 'fs';
import { dbConfig } from '../db.config';
import { buildCloudLoggingFilter } from './cloud-logging.util';
import { CycleQueryHelper } from '../data-cycle/cycle-query.helper';
import { CycleDataGroup } from '../data-cycle/entities/data-cycle.entity';

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

export type AdminLogsQuery = {
  q?: string;
  context?: string;
  minLevel?: 'warning' | 'error';
  sinceMinutes?: number;
  limit?: number;
  pageToken?: string;
  serviceName?: string;
};

type AdminLogEntry = {
  timestamp?: string;
  severity?: string;
  insertId?: string;
  logName?: string;
  serviceName?: string;
  // Common fields from our JsonLogger payload (when running on Cloud Run/Cloud Logging).
  context?: string;
  event?: string;
  message?: string;
  // Raw payload, useful for drilling in.
  jsonPayload?: any;
  textPayload?: string;
};

@Injectable()
export class AdminService {
  private readonly logger = new Logger(AdminService.name);
  private readonly dataDir = path.join(__dirname, '..', '..', 'data');
  private readonly scriptsDir = path.join(__dirname, '..', '..', 'scripts');
  private readonly appRootDir = path.join(__dirname, '..', '..');
  private jobs: Map<string, JobStatus> = new Map();
  private boss?: PgBoss;
  private bossStarted = false;

  constructor(
    @InjectRepository(Airport) private airportRepo: Repository<Airport>,
    @InjectRepository(Runway) private runwayRepo: Repository<Runway>,
    @InjectRepository(Frequency) private freqRepo: Repository<Frequency>,
    @InjectRepository(Navaid) private navaidRepo: Repository<Navaid>,
    @InjectRepository(Fix) private fixRepo: Repository<Fix>,
    @InjectRepository(Procedure) private procedureRepo: Repository<Procedure>,
    @InjectRepository(DtppCycle) private cycleRepo: Repository<DtppCycle>,
    @InjectRepository(FaaRegistryAircraft)
    private registryRepo: Repository<FaaRegistryAircraft>,
    @InjectRepository(Fbo) private fboRepo: Repository<Fbo>,
    @InjectRepository(FuelPrice) private fuelPriceRepo: Repository<FuelPrice>,
    @InjectRepository(Metar) private metarRepo: Repository<Metar>,
    @InjectRepository(Taf) private tafRepo: Repository<Taf>,
    @InjectRepository(DataSourceEntity)
    private dsRepo: Repository<DataSourceEntity>,
    @InjectRepository(PollerRun)
    private pollerRunRepo: Repository<PollerRun>,
    @InjectRepository(MasterWBProfile)
    private masterProfileRepo: Repository<MasterWBProfile>,
    private readonly weatherService: WeatherService,
    private readonly imageryService: ImageryService,
    private readonly windyService: WindyService,
    private readonly elevationService: ElevationService,
    private readonly trafficService: TrafficService,
    private readonly leidosService: LeidosService,
    private readonly dataScheduler: DataSchedulerService,
    private readonly orm: TypeOrmDataSource,
    private readonly cycleHelper: CycleQueryHelper,
  ) {}

  // --- Environment / Infrastructure ---

  async getEnvironment() {
    const runtime = this.getRuntimeInfo();
    const database = await this.getDatabaseInfo();
    const gcp = await this.getGcpInfo();
    return { runtime, database, gcp };
  }

  private getRuntimeInfo() {
    const mem = process.memoryUsage();
    return {
      gitSha: process.env.GIT_SHA || 'unknown',
      buildTimestamp: process.env.BUILD_TIMESTAMP || 'unknown',
      nodeVersion: process.version,
      nodeEnv: process.env.NODE_ENV || 'development',
      serviceRole: process.env.SERVICE_ROLE || 'unknown',
      cloudRunService: process.env.K_SERVICE || null,
      cloudRunRevision: process.env.K_REVISION || null,
      cloudRunConfiguration: process.env.K_CONFIGURATION || null,
      uptimeSeconds: Math.floor(process.uptime()),
      memory: {
        rss: mem.rss,
        heapUsed: mem.heapUsed,
        heapTotal: mem.heapTotal,
        external: mem.external,
      },
    };
  }

  private async getDatabaseInfo() {
    try {
      const versionResult = await this.orm.query('SELECT version()');
      const pgVersion = versionResult?.[0]?.version || 'unknown';

      // Get pool stats from the underlying pg driver
      let pool: {
        totalCount?: number;
        idleCount?: number;
        waitingCount?: number;
      } = {};
      try {
        const driver = this.orm.driver as any;
        const pgPool = driver.master;
        if (pgPool) {
          pool = {
            totalCount: pgPool.totalCount,
            idleCount: pgPool.idleCount,
            waitingCount: pgPool.waitingCount,
          };
        }
      } catch {
        // pool stats unavailable
      }

      return {
        available: true,
        version: pgVersion,
        host: dbConfig.host,
        port: dbConfig.port,
        database: dbConfig.database,
        pool,
      };
    } catch (err: any) {
      return {
        available: false,
        error: err?.message || 'Database unreachable',
      };
    }
  }

  private async getGcpInfo() {
    try {
      const auth = new GoogleAuth();
      const projectId = await auth.getProjectId();
      if (!projectId) {
        return { available: false, reason: 'Not running in GCP' };
      }

      // Get region from metadata server
      let region: string | null = null;
      try {
        const regionResp = await axios.get(
          'http://metadata.google.internal/computeMetadata/v1/instance/region',
          { headers: { 'Metadata-Flavor': 'Google' }, timeout: 2000 },
        );
        // Response is "projects/NUMBER/regions/REGION"
        region = String(regionResp.data).split('/').pop() || null;
      } catch {
        // not on GCP or metadata server unavailable
      }

      // Fetch Cloud Run service details
      const services: any[] = [];
      const currentService = process.env.K_SERVICE;
      // Determine both services (api + worker) from naming convention
      const serviceNames = ['efb-api', 'efb-worker'];

      if (region) {
        const client = await auth.getClient();
        const { token } = await client.getAccessToken();
        if (token) {
          for (const svcName of serviceNames) {
            try {
              const url = `https://run.googleapis.com/v2/projects/${projectId}/locations/${region}/services/${svcName}`;
              const resp = await axios.get(url, {
                headers: { Authorization: `Bearer ${token}` },
                timeout: 5000,
              });
              const d = resp.data;
              const trafficSplits = (d.traffic || []).map((t: any) => ({
                revision: t.revision,
                percent: t.percent,
                type: t.type,
              }));
              services.push({
                name: svcName,
                isCurrent: svcName === currentService,
                uri: d.uri,
                latestRevision: d.latestReadyRevision?.split('/').pop() || null,
                lastModified: d.updateTime,
                traffic: trafficSplits,
              });
            } catch {
              services.push({
                name: svcName,
                isCurrent: svcName === currentService,
                error: 'Failed to fetch service details',
              });
            }
          }
        }
      }

      return {
        available: true,
        projectId,
        region,
        services,
      };
    } catch (err: any) {
      return {
        available: false,
        reason: err?.message || 'GCP info unavailable',
      };
    }
  }

  // --- API Status ---

  getApiStatus() {
    return [
      this.weatherService.getStats(),
      this.imageryService.getStats(),
      this.windyService.getStats(),
      this.elevationService.getStats(),
      this.trafficService.getStats(),
      this.leidosService.getStats(),
    ];
  }

  // --- Data inventory ---

  async getOverview() {
    const nasrWhere = await this.cycleHelper.getCycleWhere(CycleDataGroup.NASR);
    const dtppWhere = await this.cycleHelper.getCycleWhere(CycleDataGroup.DTPP);

    const airports = await this.airportRepo.count({ where: { ...nasrWhere } });
    const runways = await this.runwayRepo.count({ where: { ...nasrWhere } });
    const frequencies = await this.freqRepo.count({ where: { ...nasrWhere } });
    const navaids = await this.navaidRepo.count({ where: { ...nasrWhere } });
    const fixes = await this.fixRepo.count({ where: { ...nasrWhere } });
    const procedures = await this.procedureRepo.count({ where: { ...dtppWhere } });
    const registryAircraft = await this.registryRepo.count();
    const fbos = await this.fboRepo.count();
    const fuelPrices = await this.fuelPriceRepo.count();
    const charts = this.getInstalledCharts();
    const diskUsage = this.getDiskUsage();

    // Get current d-TPP cycle
    const cycles = await this.cycleRepo.find({
      where: { ...dtppWhere },
      order: { seeded_at: 'DESC' },
      take: 1,
    });
    const dtppCycle = cycles[0] || null;

    return {
      database: {
        airports,
        runways,
        frequencies,
        navaids,
        fixes,
        procedures,
        registryAircraft,
        fbos,
        fuelPrices,
      },
      dtppCycle,
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

    const rawDir = path.join(this.dataDir, 'charts', 'raw');
    if (fs.existsSync(rawDir)) {
      result.chartsRaw = this.formatBytes(this.dirSize(rawDir));
    }

    const tilesDir = path.join(this.dataDir, 'charts', 'tiles');
    if (fs.existsSync(tilesDir)) {
      result.chartsTiles = this.formatBytes(this.dirSize(tilesDir));
    }

    const pdfCacheDir = path.join(this.dataDir, 'procedures', 'pdfs');
    if (fs.existsSync(pdfCacheDir)) {
      result.procedurePdfs = this.formatBytes(this.dirSize(pdfCacheDir));
    }

    return result;
  }

  // --- Job management ---

  async getJobs(): Promise<JobStatus[]> {
    const dbJobs = await this.listDbJobs();
    return [...dbJobs, ...Array.from(this.jobs.values())];
  }

  async getJob(id: string): Promise<JobStatus | undefined> {
    const mem = this.jobs.get(id);
    if (mem) return mem;
    return await this.getDbJob(id);
  }

  // --- Logs (Cloud Logging) ---

  async getLogs(query: AdminLogsQuery): Promise<{
    enabled: boolean;
    reason?: string;
    projectId?: string;
    serviceName?: string;
    filter?: string;
    entries: AdminLogEntry[];
    nextPageToken?: string;
    error?: string;
  }> {
    // If no serviceName filter was provided, show logs from ALL Cloud Run services.
    const serviceName = query.serviceName || undefined;

    try {
      const auth = new GoogleAuth({
        scopes: ['https://www.googleapis.com/auth/logging.read'],
      });

      // GoogleAuth resolves project ID from env vars, metadata server, or
      // service-account key — no custom env var needed.
      const projectId = await auth.getProjectId();
      if (!projectId) {
        return {
          enabled: false,
          reason: 'Could not detect GCP project ID (not running in GCP?)',
          entries: [],
        };
      }

      const client = await auth.getClient();

      // Clamp inputs to keep queries cheap.
      const sinceMinutesRaw = Number(query.sinceMinutes ?? 60);
      const sinceMinutes = Number.isFinite(sinceMinutesRaw)
        ? Math.min(Math.max(Math.floor(sinceMinutesRaw), 1), 7 * 24 * 60)
        : 60;
      const limitRaw = Number(query.limit ?? 50);
      const limit = Number.isFinite(limitRaw)
        ? Math.min(Math.max(Math.floor(limitRaw), 1), 200)
        : 50;

      const sinceIso = new Date(
        Date.now() - sinceMinutes * 60 * 1000,
      ).toISOString();
      const filter = buildCloudLoggingFilter({
        q: query.q,
        context: query.context,
        minLevel: query.minLevel,
        sinceMinutes,
        serviceName,
        sinceIso,
      });

      // Use the google-auth client for auth; axios for predictable response parsing.
      const { token } = await client.getAccessToken();
      if (!token) {
        return {
          enabled: true,
          reason: 'Failed to acquire GCP access token for Cloud Logging',
          projectId,
          serviceName,
          filter,
          entries: [],
        };
      }

      const url = 'https://logging.googleapis.com/v2/entries:list';
      const body = {
        resourceNames: [`projects/${projectId}`],
        filter,
        orderBy: 'timestamp desc',
        pageSize: limit,
        pageToken: query.pageToken || undefined,
      };

      const resp = await axios.post(url, body, {
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        timeout: 15_000,
      });

      const rawEntries: any[] = resp.data?.entries || [];
      const entries: AdminLogEntry[] = rawEntries.map((e: any) => {
        const jsonPayload = e.jsonPayload ?? undefined;
        return {
          timestamp: e.timestamp,
          severity: e.severity,
          insertId: e.insertId,
          logName: e.logName,
          serviceName: e.resource?.labels?.service_name,
          context: jsonPayload?.context,
          event: jsonPayload?.event,
          message:
            jsonPayload?.message ??
            (typeof e.textPayload === 'string' ? e.textPayload : undefined),
          jsonPayload,
          textPayload:
            typeof e.textPayload === 'string' ? e.textPayload : undefined,
        };
      });

      return {
        enabled: true,
        projectId,
        serviceName: serviceName || 'all',
        filter,
        entries,
        nextPageToken: resp.data?.nextPageToken,
      };
    } catch (err: any) {
      const msg =
        err?.response?.data?.error?.message ||
        err?.message ||
        'Unknown Cloud Logging error';
      this.logger.warn({ event: 'admin_logs_error', message: msg });
      return {
        enabled: false,
        reason: msg,
        entries: [],
      };
    }
  }

  // --- Seed airports ---

  async runSeedAirports(): Promise<JobStatus> {
    return await this.enqueueDbJob(
      'seed-airports',
      'Seed Airport Database (FAA NASR)',
      {
        script: 'seed.js',
        args: [],
      },
    );
  }

  // --- Seed navaids ---

  async runSeedNavaids(): Promise<JobStatus> {
    return await this.enqueueDbJob(
      'seed-navaids',
      'Seed Navigation Database (FAA NASR)',
      {
        script: 'seed-navaids.js',
        args: [],
      },
    );
  }

  // --- Seed procedures ---

  async runSeedProcedures(): Promise<JobStatus> {
    return await this.enqueueDbJob(
      'seed-procedures',
      'Seed Procedures (FAA d-TPP)',
      {
        script: 'seed-procedures.js',
        args: [],
      },
    );
  }

  // --- Seed registry ---

  async runSeedRegistry(): Promise<JobStatus> {
    return await this.enqueueDbJob(
      'seed-registry',
      'Seed Aircraft Registry (FAA)',
      {
        script: 'seed-registry.js',
        args: [],
      },
    );
  }

  // --- Scrape FBOs ---

  async runScrapeFbos(): Promise<JobStatus> {
    return await this.enqueueDbJob('scrape-fbos', 'Scrape FBOs (AirNav)', {
      script: 'seed-fbos.js',
      args: [],
    });
  }

  // --- Update fuel prices ---

  async runUpdateFuelPrices(): Promise<JobStatus> {
    return await this.enqueueDbJob(
      'update-fuel-prices',
      'Update Fuel Prices (AirNav)',
      {
        script: 'seed-fbos.js',
        args: ['--update-prices'],
      },
    );
  }

  // --- Seed airspaces ---

  async runSeedAirspaces(): Promise<JobStatus> {
    return await this.enqueueDbJob(
      'seed-airspaces',
      'Seed Airspaces & Airways (FAA NASR)',
      {
        script: 'seed-airspaces.js',
        args: [],
      },
    );
  }

  // --- Seed routes ---

  async runSeedRoutes(): Promise<JobStatus> {
    return await this.enqueueDbJob(
      'seed-routes',
      'Seed Preferred Routes (FAA NASR)',
      {
        script: 'seed-routes.js',
        args: [],
      },
    );
  }

  // --- Seed CIFP ---

  async runSeedCifp(): Promise<JobStatus> {
    return await this.enqueueDbJob(
      'seed-cifp',
      'Seed CIFP Procedures (FAA ARINC 424)',
      {
        script: 'seed-cifp.js',
        args: [],
      },
    );
  }

  // --- Seed weather stations ---

  async runSeedWeatherStations(): Promise<JobStatus> {
    return await this.enqueueDbJob(
      'seed-weather-stations',
      'Seed Weather Stations (AWC)',
      {
        script: 'seed-weather-stations.js',
        args: [],
      },
    );
  }

  // --- Seed weather flags ---

  async runSeedWeatherFlags(): Promise<JobStatus> {
    return await this.enqueueDbJob(
      'seed-weather-flags',
      'Seed Weather Flags (D-ATIS)',
      {
        script: 'seed-weather-flags.js',
        args: [],
      },
    );
  }

  // --- Clear PDF cache ---

  async clearPdfCache(): Promise<{ deleted: boolean; size?: string }> {
    const cacheDir = path.join(this.dataDir, 'procedures', 'pdfs');
    if (!fs.existsSync(cacheDir)) {
      return { deleted: false };
    }
    const size = this.formatBytes(this.dirSize(cacheDir));
    fs.rmSync(cacheDir, { recursive: true, force: true });
    return { deleted: true, size };
  }

  // --- Process VFR charts ---

  async runProcessChart(chartName: string): Promise<JobStatus> {
    if (!VFR_SECTIONAL_CHARTS.includes(chartName)) {
      throw new NotFoundException(`Invalid chart name: ${chartName}`);
    }
    return await this.enqueueDbJob(
      `chart-${chartName}`,
      `Process VFR Sectional: ${chartName}`,
      {
        script: 'process-vfr-charts.sh',
        args: ['sectional', chartName],
        command: 'bash',
        scriptDir: 'scripts',
      },
    );
  }

  // --- Delete chart tiles ---

  async deleteChart(chartName: string): Promise<{ deleted: boolean }> {
    if (!VFR_SECTIONAL_CHARTS.includes(chartName)) {
      throw new NotFoundException(`Invalid chart name: ${chartName}`);
    }
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

  // --- Data Platform ---

  async getDataSources() {
    return this.dataScheduler.getDataSources();
  }

  async restartDataSource(key: string) {
    await this.dataScheduler.restartPoller(key);
    return { restarted: true, key };
  }

  async getDataSourceHistory(key: string) {
    return this.pollerRunRepo.find({
      where: { data_source_key: key },
      order: { completed_at: 'DESC' },
      take: 50,
    });
  }

  async getDataSourcesSummary() {
    const sources = await this.dsRepo.find();
    const now = Date.now();
    let healthy = 0,
      degraded = 0,
      failed = 0,
      overdue = 0;

    for (const ds of sources) {
      if (!ds.enabled) continue;

      const isOverdue =
        ds.last_completed_at &&
        now - new Date(ds.last_completed_at).getTime() >
          ds.interval_seconds * 1000 * 3;

      if (isOverdue) {
        overdue++;
      }

      if (ds.consecutive_failures >= 3 || ds.status === 'failed') {
        failed++;
      } else if (ds.consecutive_failures > 0) {
        degraded++;
      } else {
        healthy++;
      }
    }

    return { total: sources.length, healthy, degraded, failed, overdue };
  }

  async toggleDataSource(key: string) {
    const ds = await this.dsRepo.findOneBy({ key });
    if (!ds) throw new NotFoundException(`Data source not found: ${key}`);
    ds.enabled = !ds.enabled;
    await this.dsRepo.save(ds);
    return { key, enabled: ds.enabled };
  }

  // --- Weather Coverage ---

  async getWeatherCoverage() {
    // 1. Query airports with any weather flag
    const qb = this.airportRepo
      .createQueryBuilder('a')
      .select([
        'a.identifier',
        'a.icao_identifier',
        'a.name',
        'a.city',
        'a.state',
        'a.has_metar',
        'a.has_taf',
        'a.has_datis',
        'a.has_liveatc',
        'a.has_awos',
      ])
      .where(
        'a.has_metar = true OR a.has_taf = true OR a.has_datis = true OR a.has_liveatc = true OR a.has_awos = true',
      );

    await this.cycleHelper.applyCycleFilter(qb, 'a', CycleDataGroup.NASR);

    const airports = await qb.orderBy('a.identifier', 'ASC').getMany();

    // 2. Get all ICAO IDs that have polled METAR/TAF data (with timestamps)
    const metarRows: { icao_id: string; obs_time: string | null }[] =
      await this.metarRepo
        .createQueryBuilder('m')
        .select('m.icao_id', 'icao_id')
        .addSelect('m.obs_time', 'obs_time')
        .getRawMany();
    const metarMap = new Map(
      metarRows.map((r) => {
        const t = Number(r.obs_time);
        // obs_time from AWC is in seconds; convert to ms
        return [r.icao_id, t ? t * 1000 : null];
      }),
    );

    const tafRows: { icao_id: string; updated_at: string | null }[] =
      await this.tafRepo
        .createQueryBuilder('t')
        .select('t.icao_id', 'icao_id')
        .addSelect('t.updated_at', 'updated_at')
        .getRawMany();
    const tafMap = new Map(
      tafRows.map((r) => [
        r.icao_id,
        r.updated_at ? new Date(r.updated_at).getTime() : null,
      ]),
    );

    // 3. Build response
    let metarFlagged = 0,
      metarHasData = 0;
    let tafFlagged = 0,
      tafHasData = 0;
    let datisCount = 0,
      liveatcCount = 0,
      awosCount = 0;

    const airportList = airports.map((a) => {
      const metarObsTime = a.icao_identifier
        ? (metarMap.get(a.icao_identifier) ?? null)
        : null;
      const tafUpdatedAt = a.icao_identifier
        ? (tafMap.get(a.icao_identifier) ?? null)
        : null;
      const hasMetarData = metarObsTime !== null;
      const hasTafData = tafUpdatedAt !== null;

      if (a.has_metar) {
        metarFlagged++;
        if (hasMetarData) metarHasData++;
      }
      if (a.has_taf) {
        tafFlagged++;
        if (hasTafData) tafHasData++;
      }
      if (a.has_datis) datisCount++;
      if (a.has_liveatc) liveatcCount++;
      if (a.has_awos) awosCount++;

      return {
        identifier: a.identifier,
        icao_identifier: a.icao_identifier,
        name: a.name,
        city: a.city,
        state: a.state,
        has_metar: a.has_metar,
        has_taf: a.has_taf,
        has_datis: a.has_datis,
        has_liveatc: a.has_liveatc,
        has_awos: a.has_awos,
        hasMetarData,
        hasTafData,
        metarObsTime,
        tafUpdatedAt,
      };
    });

    return {
      summary: {
        metar: {
          flagged: metarFlagged,
          hasData: metarHasData,
          missing: metarFlagged - metarHasData,
        },
        taf: {
          flagged: tafFlagged,
          hasData: tafHasData,
          missing: tafFlagged - tafHasData,
        },
        datis: datisCount,
        liveatc: liveatcCount,
        awos: awosCount,
      },
      airports: airportList,
    };
  }

  // --- Master W&B Profiles ---

  async getMasterProfiles(): Promise<MasterWBProfile[]> {
    return this.masterProfileRepo.find({
      order: { icao_type_code: 'ASC' },
    });
  }

  async getMasterProfile(id: number): Promise<MasterWBProfile> {
    const profile = await this.masterProfileRepo.findOne({ where: { id } });
    if (!profile)
      throw new NotFoundException(`Master profile #${id} not found`);
    return profile;
  }

  async createMasterProfile(
    data: Partial<MasterWBProfile>,
  ): Promise<MasterWBProfile> {
    const profile = this.masterProfileRepo.create(data);
    return this.masterProfileRepo.save(profile);
  }

  async updateMasterProfile(
    id: number,
    data: Partial<MasterWBProfile>,
  ): Promise<MasterWBProfile> {
    const profile = await this.getMasterProfile(id);
    Object.assign(profile, data);
    return this.masterProfileRepo.save(profile);
  }

  async deleteMasterProfile(id: number): Promise<void> {
    const profile = await this.getMasterProfile(id);
    await this.masterProfileRepo.remove(profile);
  }

  // --- Queue Status (pg-boss internals) ---

  async getQueueStatus() {
    // 1. Per-queue counts by state
    const queueRows: { name: string; state: string; count: string }[] =
      await this.orm.query(`
        SELECT name, state, COUNT(*)::text AS count
        FROM pgboss.job
        GROUP BY name, state
        ORDER BY name, state
      `);

    const queueMap = new Map<string, Record<string, number>>();
    for (const r of queueRows) {
      if (!queueMap.has(r.name)) queueMap.set(r.name, {});
      queueMap.get(r.name)![r.state] = Number(r.count);
    }
    const queues = Array.from(queueMap.entries()).map(([name, counts]) => ({
      name,
      counts,
    }));

    // 2. Recent jobs: non-completed + recently completed (last hour), limit 50
    const recentJobs: any[] = await this.orm.query(`
      SELECT
        id, name AS queue, singleton_key, state,
        data, output,
        created_on, started_on, completed_on,
        retry_count, retry_limit,
        expire_seconds
      FROM pgboss.job
      WHERE state != 'completed'
         OR completed_on > NOW() - INTERVAL '1 hour'
      ORDER BY
        CASE state
          WHEN 'active' THEN 1
          WHEN 'created' THEN 2
          WHEN 'retry' THEN 3
          WHEN 'failed' THEN 4
          WHEN 'completed' THEN 5
          ELSE 6
        END,
        created_on DESC
      LIMIT 50
    `);

    // 3. Stuck jobs: active longer than their expire_seconds
    const stuckJobs: any[] = await this.orm.query(`
      SELECT
        id, name AS queue, singleton_key, state,
        data, started_on,
        expire_seconds,
        EXTRACT(EPOCH FROM (NOW() - started_on))::int AS seconds_running
      FROM pgboss.job
      WHERE state = 'active'
        AND started_on IS NOT NULL
        AND EXTRACT(EPOCH FROM (NOW() - started_on)) > expire_seconds
      ORDER BY started_on ASC
    `);

    return {
      queues,
      recentJobs: recentJobs.map((r) => ({
        id: r.id,
        queue: r.queue,
        singletonKey: r.singleton_key,
        state: r.state,
        data: r.data,
        output: r.output,
        createdOn: r.created_on,
        startedOn: r.started_on,
        completedOn: r.completed_on,
        retryCount: r.retry_count,
        retryLimit: r.retry_limit,
        expireSeconds: r.expire_seconds,
      })),
      stuckJobs: stuckJobs.map((r) => ({
        id: r.id,
        queue: r.queue,
        singletonKey: r.singleton_key,
        state: r.state,
        data: r.data,
        startedOn: r.started_on,
        expireSeconds: r.expire_seconds,
        secondsRunning: r.seconds_running,
        secondsOverdue: r.seconds_running - r.expire_seconds,
      })),
    };
  }

  // --- Helpers ---

  private async ensureBoss(): Promise<PgBoss> {
    if (!this.boss) {
      this.boss = new PgBoss({
        host: dbConfig.host,
        port: dbConfig.port,
        user: dbConfig.username,
        password: dbConfig.password,
        database: dbConfig.database,
        max: 2,
      });
    }
    if (!this.bossStarted) {
      await this.boss.start();
      await this.boss.createQueue('admin-jobs');
      this.bossStarted = true;
    }
    return this.boss;
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

  private parseLogText(logText: string): string[] {
    if (!logText) return [];
    const lines = logText.split('\n').filter(Boolean);
    return lines.length > 500 ? lines.slice(-500) : lines;
  }

  private async listDbJobs(): Promise<JobStatus[]> {
    await this.ensureAdminJobsTable();
    const rows = await this.orm.query(
      `SELECT id, type, label, status, started_at, completed_at, log_text, progress
       FROM s_admin_jobs
       ORDER BY started_at DESC NULLS LAST
       LIMIT 50`,
    );
    return rows.map((r: any) => ({
      id: r.id,
      type: r.type,
      label: r.label,
      status: r.status,
      startedAt: r.started_at
        ? new Date(r.started_at).toISOString()
        : undefined,
      completedAt: r.completed_at
        ? new Date(r.completed_at).toISOString()
        : undefined,
      log: this.parseLogText(r.log_text || ''),
      progress: r.progress || undefined,
    }));
  }

  private async getDbJob(id: string): Promise<JobStatus | undefined> {
    await this.ensureAdminJobsTable();
    const rows = await this.orm.query(
      `SELECT id, type, label, status, started_at, completed_at, log_text, progress
       FROM s_admin_jobs
       WHERE id = $1
       LIMIT 1`,
      [id],
    );
    const r = rows[0];
    if (!r) return undefined;
    return {
      id: r.id,
      type: r.type,
      label: r.label,
      status: r.status,
      startedAt: r.started_at
        ? new Date(r.started_at).toISOString()
        : undefined,
      completedAt: r.completed_at
        ? new Date(r.completed_at).toISOString()
        : undefined,
      log: this.parseLogText(r.log_text || ''),
      progress: r.progress || undefined,
    };
  }

  private async enqueueDbJob(
    type: string,
    label: string,
    payload: {
      script: string;
      args: string[];
      command?: string;
      scriptDir?: string;
    },
  ): Promise<JobStatus> {
    await this.ensureAdminJobsTable();
    const id = `${type}-${Date.now()}`;
    const startedAt = new Date().toISOString();
    const initialLog = `Starting job...\nEnqueued for worker.\n`;

    await this.orm.query(
      `INSERT INTO s_admin_jobs (id, type, label, status, started_at, log_text)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [id, type, label, 'queued', startedAt, initialLog],
    );

    const boss = await this.ensureBoss();
    await boss.send(
      'admin-jobs',
      { jobId: id, type, payload },
      // pg-boss asserts expiration must be < 24h (not <=).
      { singletonKey: id, expireInSeconds: 86399 },
    );

    return (await this.getDbJob(id))!;
  }

  private runSeedScript(
    job: JobStatus,
    tsFilename: string,
    jsFilename: string,
    args: string[] = [],
  ) {
    // In production Cloud Run we ship compiled JS in /app/dist and omit dev deps
    // (so ts-node isn't available). In dev we run directly from TS sources.
    if (process.env.NODE_ENV === 'production') {
      const script = path.join(this.appRootDir, 'dist', 'seed', jsFilename);
      job.log.push(
        `Running: node ${path.relative(this.appRootDir, script)} ${args.join(' ')}`.trim(),
      );
      this.runScript('node', [script, ...args], job);
      return;
    }

    const script = path.join(this.appRootDir, 'src', 'seed', tsFilename);
    job.log.push(
      `Running: npx ts-node -r tsconfig-paths/register ${path.relative(
        this.appRootDir,
        script,
      )} ${args.join(' ')}`.trim(),
    );
    this.runScript(
      'npx',
      ['ts-node', '-r', 'tsconfig-paths/register', script, ...args],
      job,
    );
  }

  private runScript(command: string, args: string[], job: JobStatus) {
    const cwd = this.appRootDir;
    const proc = spawn(command, args, {
      cwd,
      env: { ...process.env },
    });

    proc.stdout.on('data', (data: Buffer) => {
      const lines = data.toString().split('\n').filter(Boolean);
      job.log.push(...lines);
      for (const line of lines) this.logger.log(`[job ${job.id}] ${line}`);
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
      for (const line of lines) this.logger.error(`[job ${job.id}] ${line}`);
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
