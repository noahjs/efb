import { Controller, Get, Post, Param, ParseIntPipe } from '@nestjs/common';
import { FilingService } from './filing.service';
import { CurrentUser } from '../auth/decorators/current-user.decorator';

@Controller('filing')
export class FilingController {
  constructor(private readonly filingService: FilingService) {}

  @Get(':flightId/validate')
  async validate(
    @CurrentUser() user: { id: string },
    @Param('flightId', ParseIntPipe) flightId: number,
  ) {
    return this.filingService.validateForFiling(flightId, user.id);
  }

  @Post(':flightId/file')
  async file(
    @CurrentUser() user: { id: string },
    @Param('flightId', ParseIntPipe) flightId: number,
  ) {
    return this.filingService.fileFlight(flightId, user.id);
  }

  @Post(':flightId/amend')
  async amend(
    @CurrentUser() user: { id: string },
    @Param('flightId', ParseIntPipe) flightId: number,
  ) {
    return this.filingService.amendFlight(flightId, user.id);
  }

  @Post(':flightId/cancel')
  async cancel(
    @CurrentUser() user: { id: string },
    @Param('flightId', ParseIntPipe) flightId: number,
  ) {
    return this.filingService.cancelFiling(flightId, user.id);
  }

  @Post(':flightId/close')
  async close(
    @CurrentUser() user: { id: string },
    @Param('flightId', ParseIntPipe) flightId: number,
  ) {
    return this.filingService.closeFiling(flightId, user.id);
  }

  @Get(':flightId/status')
  async status(
    @CurrentUser() user: { id: string },
    @Param('flightId', ParseIntPipe) flightId: number,
  ) {
    return this.filingService.getFilingStatus(flightId, user.id);
  }
}
