import {
  Controller,
  Get,
  Post,
  Delete,
  Param,
  Res,
  HttpCode,
} from '@nestjs/common';
import type { Response } from 'express';
import { AdminService } from './admin.service';
import * as path from 'path';

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
   * Trigger VFR sectional chart download + tile generation
   */
  @Post('charts/process/:chart')
  @HttpCode(200)
  async processChart(@Param('chart') chart: string) {
    return this.adminService.runProcessChart(chart);
  }

  /**
   * Delete a chart's tiles and raw data
   */
  @Delete('charts/:chart')
  async deleteChart(@Param('chart') chart: string) {
    return this.adminService.deleteChart(chart);
  }
}
