import { Controller, Get, Param, Query } from '@nestjs/common';
import { WeatherService } from './weather.service';

@Controller('weather')
export class WeatherController {
  constructor(private readonly weatherService: WeatherService) {}

  @Get('metar/:icao')
  async metar(@Param('icao') icao: string) {
    const data = await this.weatherService.getMetar(icao.toUpperCase());
    return data ?? { error: 'No METAR available', icao };
  }

  @Get('taf/:icao')
  async taf(@Param('icao') icao: string) {
    const data = await this.weatherService.getTaf(icao.toUpperCase());
    return data ?? { error: 'No TAF available', icao };
  }

  @Get('stations')
  async stations(
    @Query('minLat') minLat: string,
    @Query('maxLat') maxLat: string,
    @Query('minLng') minLng: string,
    @Query('maxLng') maxLng: string,
  ) {
    return this.weatherService.getBulkMetars({
      minLat: parseFloat(minLat),
      maxLat: parseFloat(maxLat),
      minLng: parseFloat(minLng),
      maxLng: parseFloat(maxLng),
    });
  }
}
