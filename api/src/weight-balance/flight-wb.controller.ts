import { Controller, Get, Param, ParseIntPipe } from '@nestjs/common';
import { WeightBalanceService } from './weight-balance.service';
import { CurrentUser } from '../auth/decorators/current-user.decorator';

@Controller('flights')
export class FlightWBController {
  constructor(private readonly wbService: WeightBalanceService) {}

  @Get(':flightId/wb-scenario')
  findOrCreateForFlight(
    @CurrentUser() user: { id: string },
    @Param('flightId', ParseIntPipe) flightId: number,
  ) {
    return this.wbService.findOrCreateScenarioForFlight(flightId, user.id);
  }
}
