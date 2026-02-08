import {
  Controller,
  Get,
  Param,
  Query,
  NotFoundException,
} from '@nestjs/common';
import { AirportsService } from './airports.service';

@Controller('airports')
export class AirportsController {
  constructor(private readonly airportsService: AirportsService) {}

  @Get()
  async search(
    @Query('q') query?: string,
    @Query('state') state?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.airportsService.search(
      query,
      state,
      limit ? parseInt(limit, 10) : 50,
      offset ? parseInt(offset, 10) : 0,
    );
  }

  @Get('nearby')
  async nearby(
    @Query('lat') lat: string,
    @Query('lng') lng: string,
    @Query('radius') radius?: string,
    @Query('limit') limit?: string,
  ) {
    return this.airportsService.findNearby(
      parseFloat(lat),
      parseFloat(lng),
      radius ? parseFloat(radius) : 30,
      limit ? parseInt(limit, 10) : 20,
    );
  }

  @Get('bounds')
  async inBounds(
    @Query('minLat') minLat: string,
    @Query('maxLat') maxLat: string,
    @Query('minLng') minLng: string,
    @Query('maxLng') maxLng: string,
    @Query('limit') limit?: string,
  ) {
    return this.airportsService.getInBounds(
      parseFloat(minLat),
      parseFloat(maxLat),
      parseFloat(minLng),
      parseFloat(maxLng),
      limit ? parseInt(limit, 10) : 200,
    );
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    const airport = await this.airportsService.findById(id.toUpperCase());
    if (!airport) {
      throw new NotFoundException(`Airport ${id} not found`);
    }
    return airport;
  }

  @Get(':id/runways')
  async runways(@Param('id') id: string) {
    return this.airportsService.getRunways(id.toUpperCase());
  }

  @Get(':id/frequencies')
  async frequencies(@Param('id') id: string) {
    return this.airportsService.getFrequencies(id.toUpperCase());
  }
}
