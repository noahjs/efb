import { Controller, Get, Param, ParseIntPipe } from '@nestjs/common';
import { WeightBalanceService } from './weight-balance.service';

@Controller('flights')
export class FlightWBController {
  constructor(private readonly wbService: WeightBalanceService) {}

  @Get(':flightId/wb-scenario')
  findOrCreateForFlight(
    @Param('flightId', ParseIntPipe) flightId: number,
  ) {
    return this.wbService.findOrCreateScenarioForFlight(flightId);
  }
}
