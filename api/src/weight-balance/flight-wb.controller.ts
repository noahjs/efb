import {
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseIntPipe,
} from '@nestjs/common';
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

  @Delete(':flightId/wb-scenario')
  @HttpCode(204)
  removeForFlight(
    @CurrentUser() user: { id: string },
    @Param('flightId', ParseIntPipe) flightId: number,
  ) {
    return this.wbService.removeScenarioForFlight(flightId, user.id);
  }
}
