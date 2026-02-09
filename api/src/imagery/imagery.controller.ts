import { Controller, Get, Param, Query, Res } from '@nestjs/common';
import type { Response } from 'express';
import { ImageryService } from './imagery.service';

@Controller('imagery')
export class ImageryController {
  constructor(private readonly imageryService: ImageryService) {}

  @Get('catalog')
  getCatalog() {
    return this.imageryService.getCatalog();
  }

  @Get('gfa/:type/:region')
  async getGfaImage(
    @Param('type') type: string,
    @Param('region') region: string,
    @Query('forecastHour') forecastHour: string,
    @Res() res: Response,
  ) {
    const hour = parseInt(forecastHour, 10) || 3;
    const buffer = await this.imageryService.getGfaImage(type, region, hour);

    if (!buffer) {
      res.status(404).json({ error: 'GFA image not found' });
      return;
    }

    res.set({
      'Content-Type': 'image/png',
      'Cache-Control': 'public, max-age=1800',
    });
    res.send(buffer);
  }

  @Get('prog/:type')
  async getProgChart(
    @Param('type') type: string,
    @Query('forecastHour') forecastHour: string,
    @Res() res: Response,
  ) {
    const defaultHour = type === 'sfc' ? 0 : 6;
    const hour = parseInt(forecastHour, 10) || defaultHour;
    const buffer = await this.imageryService.getProgChart(type, hour);

    if (!buffer) {
      res.status(404).json({ error: 'Prog chart not found' });
      return;
    }

    res.set({
      'Content-Type': 'image/gif',
      'Cache-Control': 'public, max-age=1800',
    });
    res.send(buffer);
  }

  @Get('advisories/:type')
  async getAdvisories(@Param('type') type: string) {
    return this.imageryService.getAdvisories(type);
  }

  @Get('pireps')
  async getPireps(
    @Query('bbox') bbox?: string,
    @Query('age') age?: string,
  ) {
    return this.imageryService.getPireps(
      bbox,
      age ? parseInt(age, 10) : undefined,
    );
  }
}
