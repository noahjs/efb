import { Injectable } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { firstValueFrom } from 'rxjs';
import { execFile } from 'child_process';
import { promisify } from 'util';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { BasePoller, PollerResult } from './base.poller';
import { HrrrCycle } from '../entities/hrrr-cycle.entity';
import { HrrrSurface } from '../entities/hrrr-surface.entity';
import { HrrrPressure } from '../entities/hrrr-pressure.entity';
import { HRRR, WINDS, DATA_PLATFORM } from '../../config/constants';

const execFileAsync = promisify(execFile);

/** S3 .idx file entry parsed from a line like: 112:79645435:d=2026021312:TCDC:... */
interface IdxEntry {
  messageNum: number;
  startByte: number;
  date: string;
  variable: string;
  level: string;
  forecast: string;
}

@Injectable()
export class HrrrPoller extends BasePoller {
  constructor(
    private readonly http: HttpService,
    @InjectRepository(HrrrCycle)
    private readonly cycleRepo: Repository<HrrrCycle>,
    @InjectRepository(HrrrSurface)
    private readonly surfaceRepo: Repository<HrrrSurface>,
    @InjectRepository(HrrrPressure)
    private readonly pressureRepo: Repository<HrrrPressure>,
  ) {
    super('HrrrPoller');
  }

  async execute(): Promise<PollerResult> {
    let totalRecords = 0;
    let totalErrors = 0;
    let lastError: string | undefined;

    // Stage 1: Discover the latest available HRRR cycle
    const initTime = await this.discoverLatestCycle();
    if (!initTime) {
      return {
        recordsUpdated: 0,
        errors: 1,
        lastError: 'No HRRR cycle available on S3',
      };
    }

    // Check if we already have this cycle processed and active
    const existing = await this.cycleRepo.findOne({
      where: { init_time: initTime },
    });
    if (existing && ['active', 'generating_tiles'].includes(existing.status)) {
      this.logger.log(
        `Cycle ${initTime.toISOString()} already processed, skipping`,
      );
      return { recordsUpdated: 0, errors: 0 };
    }

    // Create or reset cycle record
    let cycle: HrrrCycle;
    if (existing) {
      cycle = existing;
      cycle.status = 'discovered';
      cycle.total_errors = 0;
      cycle.last_error = null;
    } else {
      cycle = this.cycleRepo.create({
        init_time: initTime,
        status: 'discovered',
      });
    }
    await this.cycleRepo.save(cycle);

    const forecastHours = HRRR.FORECAST_HOURS;
    const pipelineStart = Date.now();

    try {
      // Stage 2: Download
      await this.updateCycle(cycle, {
        status: 'downloading',
        download_started_at: new Date(),
        download_total: forecastHours.length,
      });

      const downloadedFiles: Array<{
        forecastHour: number;
        surfacePath: string | null;
        pressurePath: string | null;
      }> = [];

      for (const fh of forecastHours) {
        try {
          const files = await this.downloadForecastHour(initTime, fh);
          downloadedFiles.push({ forecastHour: fh, ...files });
          cycle.download_completed++;
          cycle.download_bytes =
            Number(cycle.download_bytes) +
            (files.surfaceBytes || 0) +
            (files.pressureBytes || 0);
          await this.cycleRepo.save(cycle);
        } catch (err) {
          cycle.download_failed++;
          cycle.total_errors++;
          cycle.last_error = err.message;
          await this.cycleRepo.save(cycle);
          totalErrors++;
          lastError = err.message;
          this.logger.error(`Download failed F${fh}: ${err.message}`);
        }
      }

      await this.updateCycle(cycle, { download_completed_at: new Date() });

      if (downloadedFiles.length === 0) {
        await this.updateCycle(cycle, {
          status: 'failed',
          last_error: 'All downloads failed',
        });
        return {
          recordsUpdated: 0,
          errors: totalErrors,
          lastError: 'All downloads failed',
        };
      }

      // Stage 3: Processing
      await this.updateCycle(cycle, {
        status: 'processing',
        process_started_at: new Date(),
        process_total: downloadedFiles.length,
      });

      const processedResults: Array<{
        forecastHour: number;
        surface: any[];
        pressure: any[];
      }> = [];

      for (const dl of downloadedFiles) {
        try {
          const result = await this.processGrib2(
            dl.surfacePath,
            dl.pressurePath,
          );
          processedResults.push({
            forecastHour: dl.forecastHour,
            surface: result.surface || [],
            pressure: result.pressure || [],
          });
          cycle.process_completed++;
          await this.cycleRepo.save(cycle);
        } catch (err) {
          cycle.process_failed++;
          cycle.total_errors++;
          cycle.last_error = err.message;
          await this.cycleRepo.save(cycle);
          totalErrors++;
          lastError = err.message;
          this.logger.error(`Processing failed F${dl.forecastHour}: ${err.message}`);
        }
      }

      await this.updateCycle(cycle, { process_completed_at: new Date() });

      // Stage 4: Grid Ingest
      await this.updateCycle(cycle, { status: 'ingesting' });

      for (const pr of processedResults) {
        const validTime = new Date(
          initTime.getTime() + pr.forecastHour * 3600 * 1000,
        );

        // Insert surface rows
        if (pr.surface.length > 0) {
          const surfaceEntities = pr.surface.map((row) => {
            const entity = new HrrrSurface();
            entity.init_time = initTime;
            entity.forecast_hour = pr.forecastHour;
            entity.valid_time = validTime;
            entity.lat = row.lat;
            entity.lng = row.lng;
            entity.cloud_total = row.cloud_total;
            entity.cloud_low = row.cloud_low;
            entity.cloud_mid = row.cloud_mid;
            entity.cloud_high = row.cloud_high;
            entity.ceiling_ft = row.ceiling_ft;
            entity.cloud_base_ft = row.cloud_base_ft;
            entity.cloud_top_ft = row.cloud_top_ft;
            entity.flight_category = row.flight_category;
            entity.visibility_sm = row.visibility_sm;
            entity.wind_dir = row.wind_dir;
            entity.wind_speed_kt = row.wind_speed_kt;
            entity.wind_gust_kt = row.wind_gust_kt;
            entity.temperature_c = row.temperature_c;
            return entity;
          });

          await this.bulkInsert(this.surfaceRepo, surfaceEntities);
          cycle.ingest_surface_rows += surfaceEntities.length;
          totalRecords += surfaceEntities.length;
        }

        // Insert pressure rows
        if (pr.pressure.length > 0) {
          const pressureEntities = pr.pressure.map((row) => {
            const entity = new HrrrPressure();
            entity.init_time = initTime;
            entity.forecast_hour = pr.forecastHour;
            entity.valid_time = validTime;
            entity.lat = row.lat;
            entity.lng = row.lng;
            entity.pressure_level = row.pressure_level;
            entity.altitude_ft = row.altitude_ft;
            entity.relative_humidity = row.relative_humidity;
            entity.wind_dir = row.wind_dir;
            entity.wind_speed_kt = row.wind_speed_kt;
            entity.temperature_c = row.temperature_c;
            return entity;
          });

          await this.bulkInsert(this.pressureRepo, pressureEntities);
          cycle.ingest_pressure_rows += pressureEntities.length;
          totalRecords += pressureEntities.length;
        }

        await this.cycleRepo.save(cycle);
      }

      await this.updateCycle(cycle, { ingest_completed_at: new Date() });

      // Stage 5: Activation (skip tile generation for Phase 1)
      await this.activateCycle(cycle);

      // Sync the local object with what activateCycle wrote to the DB
      cycle.status = 'active';
      cycle.is_active = true;
      cycle.total_duration_ms = Date.now() - pipelineStart;
      await this.cycleRepo.save(cycle);

      // Cleanup temp files
      for (const dl of downloadedFiles) {
        this.cleanupFile(dl.surfacePath);
        this.cleanupFile(dl.pressurePath);
      }

      // Cleanup old superseded cycles
      await this.cleanupOldCycles();

      this.logger.log(
        `HRRR cycle ${initTime.toISOString()}: ${totalRecords} records in ${cycle.total_duration_ms}ms`,
      );
    } catch (err) {
      await this.updateCycle(cycle, {
        status: 'failed',
        last_error: err.message,
        total_duration_ms: Date.now() - pipelineStart,
      });
      throw err;
    }

    return {
      recordsUpdated: totalRecords,
      errors: totalErrors,
      lastError,
    };
  }

  // --- Stage 1: Cycle Discovery ---

  private async discoverLatestCycle(): Promise<Date | null> {
    const now = new Date();

    // HRRR data is available ~1-2 hours after init time.
    // Try from (current hour - 2) backwards.
    for (let hoursBack = 2; hoursBack <= HRRR.CYCLE_LOOKBACK_HOURS; hoursBack++) {
      const initTime = new Date(now);
      initTime.setUTCMinutes(0, 0, 0);
      initTime.setUTCHours(initTime.getUTCHours() - hoursBack);

      const dateStr = this.formatDateStr(initTime);
      const hourStr = String(initTime.getUTCHours()).padStart(2, '0');

      // Check if the .idx file exists for F01 (lightweight HEAD request)
      const idxUrl =
        `${HRRR.S3_BASE_URL}/hrrr.${dateStr}/conus/` +
        `hrrr.t${hourStr}z.wrfsfcf01.grib2.idx`;

      try {
        await firstValueFrom(
          this.http.head(idxUrl, { timeout: HRRR.S3_TIMEOUT_MS }),
        );
        this.logger.log(
          `Found HRRR cycle: ${initTime.toISOString()} (${hoursBack}h ago)`,
        );
        return initTime;
      } catch {
        // Not available yet, try earlier
        continue;
      }
    }

    return null;
  }

  // --- Stage 2: Download ---

  private async downloadForecastHour(
    initTime: Date,
    forecastHour: number,
  ): Promise<{
    surfacePath: string | null;
    pressurePath: string | null;
    surfaceBytes: number;
    pressureBytes: number;
  }> {
    const dateStr = this.formatDateStr(initTime);
    const hourStr = String(initTime.getUTCHours()).padStart(2, '0');
    const fhStr = String(forecastHour).padStart(2, '0');
    const tmpDir = os.tmpdir();

    let surfacePath: string | null = null;
    let pressurePath: string | null = null;
    let surfaceBytes = 0;
    let pressureBytes = 0;

    // Download surface variables from wrfsfcf
    const sfcBase =
      `${HRRR.S3_BASE_URL}/hrrr.${dateStr}/conus/` +
      `hrrr.t${hourStr}z.wrfsfcf${fhStr}.grib2`;

    const sfcRanges = await this.parseIdxAndGetRanges(
      `${sfcBase}.idx`,
      HRRR.SURFACE_VARS,
    );
    if (sfcRanges.length > 0) {
      surfacePath = path.join(
        tmpDir,
        `hrrr_sfc_${dateStr}_${hourStr}_f${fhStr}.grib2`,
      );
      surfaceBytes = await this.downloadByteRanges(
        sfcBase,
        sfcRanges,
        surfacePath,
      );
      this.logger.log(
        `Downloaded wrfsfcf F${fhStr}: ${(surfaceBytes / 1024 / 1024).toFixed(1)} MB`,
      );
    }

    // Download pressure-level variables from wrfprsf
    const prsBase =
      `${HRRR.S3_BASE_URL}/hrrr.${dateStr}/conus/` +
      `hrrr.t${hourStr}z.wrfprsf${fhStr}.grib2`;

    // Build pressure-level filter patterns
    const pressureVarPatterns: string[] = [];
    for (const varName of HRRR.PRESSURE_VARS) {
      for (const level of HRRR.PRESSURE_LEVELS) {
        pressureVarPatterns.push(`${varName}:${level} mb`);
      }
    }

    const prsRanges = await this.parseIdxAndGetRanges(
      `${prsBase}.idx`,
      pressureVarPatterns,
    );
    if (prsRanges.length > 0) {
      pressurePath = path.join(
        tmpDir,
        `hrrr_prs_${dateStr}_${hourStr}_f${fhStr}.grib2`,
      );
      pressureBytes = await this.downloadByteRanges(
        prsBase,
        prsRanges,
        pressurePath,
      );
      this.logger.log(
        `Downloaded wrfprsf F${fhStr}: ${(pressureBytes / 1024 / 1024).toFixed(1)} MB`,
      );
    }

    return { surfacePath, pressurePath, surfaceBytes, pressureBytes };
  }

  /** Parse a GRIB2 .idx file and return byte ranges for matching variables. */
  private async parseIdxAndGetRanges(
    idxUrl: string,
    varPatterns: string[],
  ): Promise<Array<{ start: number; end: number }>> {
    const { data } = await firstValueFrom(
      this.http.get<string>(idxUrl, {
        timeout: HRRR.S3_TIMEOUT_MS,
        responseType: 'text',
      }),
    );

    const lines = data.trim().split('\n');
    const entries: IdxEntry[] = lines.map((line) => {
      const parts = line.split(':');
      return {
        messageNum: parseInt(parts[0], 10),
        startByte: parseInt(parts[1], 10),
        date: parts[2],
        variable: parts[3],
        level: parts[4],
        forecast: parts[5],
      };
    });

    const ranges: Array<{ start: number; end: number }> = [];

    for (let i = 0; i < entries.length; i++) {
      const entry = entries[i];
      const varLevel = `${entry.variable}:${entry.level}`;

      if (varPatterns.some((p) => varLevel.includes(p))) {
        const start = entry.startByte;
        const end =
          i + 1 < entries.length ? entries[i + 1].startByte - 1 : start + 5_000_000;
        ranges.push({ start, end });
      }
    }

    return this.mergeRanges(ranges);
  }

  /** Merge overlapping or adjacent byte ranges to minimize HTTP requests. */
  private mergeRanges(
    ranges: Array<{ start: number; end: number }>,
  ): Array<{ start: number; end: number }> {
    if (ranges.length === 0) return [];
    const sorted = [...ranges].sort((a, b) => a.start - b.start);
    const merged: Array<{ start: number; end: number }> = [sorted[0]];

    for (let i = 1; i < sorted.length; i++) {
      const last = merged[merged.length - 1];
      // Merge if ranges are within 100KB of each other (avoid tiny gaps)
      if (sorted[i].start <= last.end + 100_000) {
        last.end = Math.max(last.end, sorted[i].end);
      } else {
        merged.push(sorted[i]);
      }
    }
    return merged;
  }

  /** Download specific byte ranges from a GRIB2 file on S3. */
  private async downloadByteRanges(
    fileUrl: string,
    ranges: Array<{ start: number; end: number }>,
    outputPath: string,
  ): Promise<number> {
    const chunks: Buffer[] = [];
    let totalBytes = 0;

    for (const range of ranges) {
      const { data } = await firstValueFrom(
        this.http.get(fileUrl, {
          headers: { Range: `bytes=${range.start}-${range.end}` },
          responseType: 'arraybuffer',
          timeout: HRRR.S3_TIMEOUT_MS,
          maxContentLength: 100 * 1024 * 1024,
          maxBodyLength: 100 * 1024 * 1024,
        }),
      );
      chunks.push(Buffer.from(data));
      totalBytes += data.byteLength;
    }

    fs.writeFileSync(outputPath, Buffer.concat(chunks));
    return totalBytes;
  }

  // --- Stage 3: Processing ---

  private async processGrib2(
    surfacePath: string | null,
    pressurePath: string | null,
  ): Promise<{ surface: any[]; pressure: any[] }> {
    // IMPORTANT: don't derive the processor path from `__dirname`.
    // In production we run compiled JS from `dist/…`, and `__dirname` depth changes,
    // which previously caused paths like `/hrrr-processor/process.py`.
    //
    // Defaults assume the API is started with CWD = `.../api` (local) or `/app/api` (container),
    // and the processor lives next to it at `../hrrr-processor`.
    const processorDir = process.env.HRRR_PROCESSOR_DIR
      ? path.resolve(process.env.HRRR_PROCESSOR_DIR)
      : path.resolve(process.cwd(), '..', 'hrrr-processor');

    const scriptPath = process.env.HRRR_PROCESSOR_SCRIPT
      ? path.resolve(process.env.HRRR_PROCESSOR_SCRIPT)
      : path.join(processorDir, 'process.py');

    const args: string[] = [];
    if (surfacePath) {
      args.push('--surface', surfacePath);
    }
    if (pressurePath) {
      args.push('--pressure', pressurePath);
    }

    args.push(
      '--grid-spacing', String(HRRR.GRID_SPACING_DEG),
      '--lat-min', String(DATA_PLATFORM.CONUS_BOUNDS.minLat),
      '--lat-max', String(DATA_PLATFORM.CONUS_BOUNDS.maxLat),
      '--lng-min', String(DATA_PLATFORM.CONUS_BOUNDS.minLng),
      '--lng-max', String(DATA_PLATFORM.CONUS_BOUNDS.maxLng),
      '--pressure-levels', HRRR.PRESSURE_LEVELS.join(','),
    );

    const venvPython = path.join(processorDir, 'venv', 'bin', 'python3');
    const pythonCmd = process.env.HRRR_PYTHON_PATH || venvPython;

    if (!fs.existsSync(scriptPath)) {
      throw new Error(
        `HRRR processor script not found at "${scriptPath}". ` +
          `This usually means the "hrrr-processor" folder was not deployed alongside the API.`,
      );
    }
    if (path.isAbsolute(pythonCmd) && !fs.existsSync(pythonCmd)) {
      throw new Error(
        `HRRR python binary not found at "${pythonCmd}". ` +
          `Set HRRR_PYTHON_PATH to a valid python3 path, or ensure the hrrr-processor venv is built in the runtime image.`,
      );
    }

    const { stdout, stderr } = await execFileAsync(pythonCmd, [scriptPath, ...args], {
      timeout: HRRR.PROCESSOR_TIMEOUT_MS,
      maxBuffer: 100 * 1024 * 1024, // 100MB for large JSON output
    });

    if (stderr) {
      // Python progress messages go to stderr; log them
      for (const line of stderr.trim().split('\n')) {
        if (line) this.logger.log(`[Python] ${line}`);
      }
    }

    return JSON.parse(stdout);
  }

  // --- Stage 5: Activation ---

  private async activateCycle(cycle: HrrrCycle): Promise<void> {
    await this.cycleRepo.manager.transaction(async (em) => {
      // Supersede the currently active cycle
      await em
        .createQueryBuilder()
        .update(HrrrCycle)
        .set({
          is_active: false,
          status: 'superseded',
          superseded_at: new Date(),
        })
        .where('is_active = true')
        .execute();

      // Activate the new cycle
      await em
        .createQueryBuilder()
        .update(HrrrCycle)
        .set({
          is_active: true,
          status: 'active',
          activated_at: new Date(),
        })
        .where('init_time = :initTime', { initTime: cycle.init_time })
        .execute();
    });

    this.logger.log(`Activated HRRR cycle: ${cycle.init_time.toISOString()}`);
  }

  // --- Cleanup ---

  private async cleanupOldCycles(): Promise<void> {
    const staleThreshold = new Date(
      Date.now() - HRRR.MAX_CYCLE_AGE_HOURS * 3600 * 1000,
    );

    // Find superseded cycles older than threshold
    const staleCycles = await this.cycleRepo
      .createQueryBuilder('c')
      .where('c.status = :status', { status: 'superseded' })
      .andWhere('c.superseded_at < :threshold', { threshold: staleThreshold })
      .getMany();

    for (const old of staleCycles) {
      const initTimeStr = old.init_time.toISOString();

      // Delete grid data
      await this.surfaceRepo.delete({ init_time: old.init_time });
      await this.pressureRepo.delete({ init_time: old.init_time });

      // Delete cycle record
      await this.cycleRepo.delete({ init_time: old.init_time });

      this.logger.log(`Cleaned up old HRRR cycle: ${initTimeStr}`);
    }
  }

  // --- Helpers ---

  private async updateCycle(
    cycle: HrrrCycle,
    updates: Partial<HrrrCycle>,
  ): Promise<void> {
    Object.assign(cycle, updates);
    await this.cycleRepo.save(cycle);
  }

  private async bulkInsert<T extends object>(
    repo: Repository<T>,
    entities: T[],
  ): Promise<void> {
    const chunkSize = 500;
    await repo.manager.transaction(async (em) => {
      for (let i = 0; i < entities.length; i += chunkSize) {
        const chunk = entities.slice(i, i + chunkSize);
        await em
          .createQueryBuilder()
          .insert()
          .into(repo.target)
          .values(chunk)
          .orIgnore() // Skip if unique constraint hit (re-run safety)
          .execute();
      }
    });
  }

  private formatDateStr(date: Date): string {
    const y = date.getUTCFullYear();
    const m = String(date.getUTCMonth() + 1).padStart(2, '0');
    const d = String(date.getUTCDate()).padStart(2, '0');
    return `${y}${m}${d}`;
  }

  private cleanupFile(filePath: string | null): void {
    if (filePath && fs.existsSync(filePath)) {
      try {
        fs.unlinkSync(filePath);
      } catch {
        // Non-critical
      }
    }
  }
}
