import {
  Controller,
  Get,
  Post,
  Delete,
  Param,
  Res,
  HttpCode,
  BadRequestException,
} from '@nestjs/common';
import type { Response } from 'express';
import { AdminService, VFR_SECTIONAL_CHARTS } from './admin.service';
import * as path from 'path';
import { Public } from '../auth/guards/public.decorator';

@Public()
@Controller('admin')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  /**
   * Serve the admin HTML page at /api/admin
   */
  @Get()
  serveAdminPage(@Res() res: Response) {
    const htmlPath = path.join(__dirname, '..', '..', 'public', 'admin.html');
    res.sendFile(htmlPath);
  }

  /**
   * Serve the weather coverage HTML page at /api/admin/weather-coverage
   */
  @Get('weather-coverage')
  serveWeatherCoveragePage(@Res() res: Response) {
    const htmlPath = path.join(
      __dirname,
      '..',
      '..',
      'public',
      'weather-coverage.html',
    );
    res.sendFile(htmlPath);
  }

  /**
   * JSON API for weather coverage data
   */
  @Get('weather-coverage/data')
  async getWeatherCoverageData() {
    return this.adminService.getWeatherCoverage();
  }

  /**
   * Get data platform polling job status
   */
  @Get('data-sources')
  async getDataSources() {
    return this.adminService.getDataSources();
  }

  /**
   * Restart a data source poller (cancel existing, re-enqueue)
   */
  @Post('data-sources/:key/restart')
  @HttpCode(200)
  async restartDataSource(@Param('key') key: string) {
    return this.adminService.restartDataSource(key);
  }

  /**
   * Get API service health and stats
   */
  @Get('api-status')
  getApiStatus() {
    return this.adminService.getApiStatus();
  }

  /**
   * Get full system overview: database counts, chart status, disk usage, jobs
   */
  @Get('overview')
  async getOverview() {
    return this.adminService.getOverview();
  }

  /**
   * List all running and completed jobs
   */
  @Get('jobs')
  getJobs() {
    return this.adminService.getJobs();
  }

  /**
   * Get a specific job by ID
   */
  @Get('jobs/:id')
  getJob(@Param('id') id: string) {
    const job = this.adminService.getJob(id);
    if (!job) return { error: 'Job not found' };
    return job;
  }

  /**
   * Trigger airport database seed (FAA NASR data)
   */
  @Post('seed/airports')
  @HttpCode(200)
  async seedAirports() {
    return this.adminService.runSeedAirports();
  }

  /**
   * Trigger navigation data seed (navaids + fixes from FAA NASR)
   */
  @Post('seed/navaids')
  @HttpCode(200)
  async seedNavaids() {
    return this.adminService.runSeedNavaids();
  }

  /**
   * Trigger d-TPP procedure data seed
   */
  @Post('seed/procedures')
  @HttpCode(200)
  async seedProcedures() {
    return this.adminService.runSeedProcedures();
  }

  /**
   * Trigger aircraft registry seed (FAA)
   */
  @Post('seed/registry')
  @HttpCode(200)
  async seedRegistry() {
    return this.adminService.runSeedRegistry();
  }

  /**
   * Trigger FBO scrape from AirNav
   */
  @Post('scrape/fbos')
  @HttpCode(200)
  async scrapeFbos() {
    return this.adminService.runScrapeFbos();
  }

  /**
   * Trigger fuel price update from AirNav
   */
  @Post('scrape/fuel-prices')
  @HttpCode(200)
  async updateFuelPrices() {
    return this.adminService.runUpdateFuelPrices();
  }

  /**
   * Clear cached procedure PDFs
   */
  @Delete('procedures/pdf-cache')
  async clearPdfCache() {
    return this.adminService.clearPdfCache();
  }

  /**
   * Trigger VFR sectional chart download + tile generation
   */
  @Post('charts/process/:chart')
  @HttpCode(200)
  async processChart(@Param('chart') chart: string) {
    if (!VFR_SECTIONAL_CHARTS.includes(chart)) {
      throw new BadRequestException(`Invalid chart name: ${chart}`);
    }
    return this.adminService.runProcessChart(chart);
  }

  /**
   * Delete a chart's tiles and raw data
   */
  @Delete('charts/:chart')
  async deleteChart(@Param('chart') chart: string) {
    if (!VFR_SECTIONAL_CHARTS.includes(chart)) {
      throw new BadRequestException(`Invalid chart name: ${chart}`);
    }
    return this.adminService.deleteChart(chart);
  }
}
