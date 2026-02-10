import {
  Controller,
  Get,
  Param,
  NotFoundException,
  ParseIntPipe,
} from '@nestjs/common';
import { CifpService } from './cifp.service';

@Controller('cifp')
export class CifpController {
  constructor(private readonly cifpService: CifpService) {}

  @Get(':airportId/approaches')
  async getApproaches(@Param('airportId') airportId: string) {
    return this.cifpService.getApproaches(airportId);
  }

  @Get(':airportId/approaches/:id')
  async getApproach(
    @Param('airportId') airportId: string,
    @Param('id', ParseIntPipe) id: number,
  ) {
    const approach = await this.cifpService.getApproach(id);
    if (!approach) {
      throw new NotFoundException(`Approach ${id} not found`);
    }
    return approach;
  }

  @Get(':airportId/ils')
  async getIls(@Param('airportId') airportId: string) {
    return this.cifpService.getIls(airportId);
  }

  @Get(':airportId/msa')
  async getMsa(@Param('airportId') airportId: string) {
    return this.cifpService.getMsa(airportId);
  }

  @Get(':airportId/runways')
  async getRunways(@Param('airportId') airportId: string) {
    return this.cifpService.getRunways(airportId);
  }

  @Get('debug/approach/:id')
  async getDebugData(@Param('id', ParseIntPipe) id: number) {
    const data = await this.cifpService.getDebugData(id);
    if (!data) {
      throw new NotFoundException(`Approach ${id} not found`);
    }
    return data;
  }

  @Get(':airportId/chart-data/:approachId')
  async getChartData(
    @Param('airportId') airportId: string,
    @Param('approachId', ParseIntPipe) approachId: number,
  ) {
    const data = await this.cifpService.getChartData(approachId);
    if (!data) {
      throw new NotFoundException(`Approach ${approachId} not found`);
    }
    return data;
  }
}
