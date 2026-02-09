import {
  Controller,
  Get,
  Param,
  Res,
  Header,
  ParseIntPipe,
  NotFoundException,
} from '@nestjs/common';
import type { Response } from 'express';
import { ProceduresService } from './procedures.service';

@Controller('procedures')
export class ProceduresController {
  constructor(private readonly proceduresService: ProceduresService) {}

  @Get('cycle/current')
  async getCurrentCycle() {
    const cycle = await this.proceduresService.getCurrentCycle();
    if (!cycle) {
      return { loaded: false };
    }
    return { loaded: true, ...cycle };
  }

  @Get(':airportId')
  async getByAirport(@Param('airportId') airportId: string) {
    return this.proceduresService.getByAirport(airportId);
  }

  @Get(':airportId/pdf/:id')
  @Header('Cache-Control', 'public, max-age=86400')
  async getPdf(
    @Param('airportId') airportId: string,
    @Param('id', ParseIntPipe) id: number,
    @Res() res: Response,
  ) {
    const { filePath, fileName } = await this.proceduresService.getPdf(
      airportId,
      id,
    );
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `inline; filename="${fileName}"`);
    res.sendFile(filePath);
  }

  @Get(':airportId/georef/:id')
  @Header('Cache-Control', 'public, max-age=86400')
  async getGeoref(
    @Param('airportId') airportId: string,
    @Param('id', ParseIntPipe) id: number,
  ) {
    const georef = await this.proceduresService.getGeoref(airportId, id);
    if (!georef) {
      throw new NotFoundException('No georef data available for this procedure');
    }
    return georef;
  }

  @Get(':airportId/image/:id')
  @Header('Cache-Control', 'public, max-age=86400')
  async getProcedureImage(
    @Param('airportId') airportId: string,
    @Param('id', ParseIntPipe) id: number,
    @Res() res: Response,
  ) {
    const { filePath, fileName } =
      await this.proceduresService.getProcedureImage(airportId, id);
    res.setHeader('Content-Type', 'image/png');
    res.setHeader('Content-Disposition', `inline; filename="${fileName}"`);
    res.sendFile(filePath);
  }
}
