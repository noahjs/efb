import { Controller, Get, Post, Param, ParseIntPipe } from '@nestjs/common';
import { FilingService } from './filing.service';

@Controller('filing')
export class FilingController {
  constructor(private readonly filingService: FilingService) {}

  @Get(':flightId/validate')
  async validate(@Param('flightId', ParseIntPipe) flightId: number) {
    return this.filingService.validateForFiling(flightId);
  }

  @Post(':flightId/file')
  async file(@Param('flightId', ParseIntPipe) flightId: number) {
    return this.filingService.fileFlight(flightId);
  }

  @Post(':flightId/amend')
  async amend(@Param('flightId', ParseIntPipe) flightId: number) {
    return this.filingService.amendFlight(flightId);
  }

  @Post(':flightId/cancel')
  async cancel(@Param('flightId', ParseIntPipe) flightId: number) {
    return this.filingService.cancelFiling(flightId);
  }

  @Post(':flightId/close')
  async close(@Param('flightId', ParseIntPipe) flightId: number) {
    return this.filingService.closeFiling(flightId);
  }

  @Get(':flightId/status')
  async status(@Param('flightId', ParseIntPipe) flightId: number) {
    return this.filingService.getFilingStatus(flightId);
  }
}
