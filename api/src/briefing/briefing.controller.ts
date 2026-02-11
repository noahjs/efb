import {
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Query,
} from '@nestjs/common';
import { BriefingService } from './briefing.service';
import { CurrentUser } from '../auth/decorators/current-user.decorator';

@Controller('flights')
export class BriefingController {
  constructor(private readonly briefingService: BriefingService) {}

  @Get(':id/briefing')
  async getBriefing(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.briefingService.generateBriefing(id, user.id);
  }

  @Get(':id/route-airports')
  async getRouteAirports(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
    @Query('corridorNm') corridorNm?: string,
  ) {
    return this.briefingService.getRouteAirports(
      id,
      user.id,
      corridorNm ? parseFloat(corridorNm) : undefined,
    );
  }
}
