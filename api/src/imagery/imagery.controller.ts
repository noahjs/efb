import { Controller, Get, Param, Query, Res } from '@nestjs/common';
import type { Response } from 'express';
import { ImageryService } from './imagery.service';
import { Public } from '../auth/guards/public.decorator';

@Public()
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

  @Get('icing/:param')
  async getIcingChart(
    @Param('param') param: string,
    @Query('level') level: string,
    @Query('forecastHour') forecastHour: string,
    @Res() res: Response,
  ) {
    const effectiveLevel = level || 'max';
    const hour = parseInt(forecastHour, 10) || 0;
    const buffer = await this.imageryService.getIcingChart(
      param,
      effectiveLevel,
      hour,
    );

    if (!buffer) {
      res.status(404).json({ error: 'Icing chart not found' });
      return;
    }

    res.set({
      'Content-Type': 'image/gif',
      'Cache-Control': 'public, max-age=1800',
    });
    res.send(buffer);
  }

  @Get('winds/:level')
  async getWindsAloftChart(
    @Param('level') level: string,
    @Query('area') area: string,
    @Query('forecastHour') forecastHour: string,
    @Res() res: Response,
  ) {
    const effectiveArea = area || 'a';
    const hour = parseInt(forecastHour, 10) || 6;
    const buffer = await this.imageryService.getWindsAloftChart(
      level,
      effectiveArea,
      hour,
    );

    if (!buffer) {
      res.status(404).json({ error: 'Winds aloft chart not found' });
      return;
    }

    res.set({
      'Content-Type': 'image/gif',
      'Cache-Control': 'public, max-age=3600',
    });
    res.send(buffer);
  }

  @Get('convective/:day')
  async getConvectiveOutlook(
    @Param('day') day: string,
    @Query('type') type: string,
    @Res() res: Response,
  ) {
    const dayNum = parseInt(day, 10) || 1;
    const effectiveType = type || 'cat';
    const buffer = await this.imageryService.getConvectiveOutlook(
      dayNum,
      effectiveType,
    );

    if (!buffer) {
      res.status(404).json({ error: 'Convective outlook not found' });
      return;
    }

    res.set({
      'Content-Type': 'image/gif',
      'Cache-Control': 'public, max-age=1800',
    });
    res.send(buffer);
  }

  @Get('tfrs')
  async getTfrs() {
    return this.imageryService.getTfrs();
  }

  @Get('advisories/:type')
  async getAdvisories(
    @Param('type') type: string,
    @Query('fore') fore?: string,
  ) {
    const forecastHour = fore != null ? parseInt(fore, 10) : undefined;
    return this.imageryService.getAdvisories(
      type,
      forecastHour != null && !isNaN(forecastHour) ? forecastHour : undefined,
    );
  }

  @Get('pireps')
  async getPireps(@Query('bbox') bbox?: string, @Query('age') age?: string) {
    return this.imageryService.getPireps(
      bbox,
      age ? parseInt(age, 10) : undefined,
    );
  }
}
