import {
  Controller,
  Get,
  Query,
  BadRequestException,
} from '@nestjs/common';
import { TrafficService } from './traffic.service';
import { TRAFFIC } from '../config/constants';
import { Public } from '../auth/guards/public.decorator';

@Public()
@Controller('traffic')
export class TrafficController {
  constructor(private readonly trafficService: TrafficService) {}

  @Get('nearby')
  async getNearby(
    @Query('lat') latStr: string,
    @Query('lon') lonStr: string,
    @Query('radius') radiusStr?: string,
  ) {
    const lat = parseFloat(latStr);
    const lon = parseFloat(lonStr);
    const radius = radiusStr
      ? parseFloat(radiusStr)
      : TRAFFIC.DEFAULT_RADIUS_NM;

    if (isNaN(lat) || lat < -90 || lat > 90) {
      throw new BadRequestException('lat must be between -90 and 90');
    }
    if (isNaN(lon) || lon < -180 || lon > 180) {
      throw new BadRequestException('lon must be between -180 and 180');
    }
    if (isNaN(radius) || radius < 1 || radius > TRAFFIC.MAX_RADIUS_NM) {
      throw new BadRequestException(
        `radius must be between 1 and ${TRAFFIC.MAX_RADIUS_NM}`,
      );
    }

    return this.trafficService.getTrafficNearby(lat, lon, radius);
  }
}
