import {
  Controller,
  Get,
  Param,
  Res,
  Header,
  ParseIntPipe,
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
}
