import { Controller, Get, Query } from '@nestjs/common';
import { AirspacesService } from './airspaces.service';

@Controller()
export class AirspacesController {
  constructor(private readonly airspacesService: AirspacesService) {}

  @Get('airspaces/bounds')
  async airspacesInBounds(
    @Query('minLat') minLat: string,
    @Query('maxLat') maxLat: string,
    @Query('minLng') minLng: string,
    @Query('maxLng') maxLng: string,
    @Query('types') types?: string,
    @Query('classes') classes?: string,
    @Query('limit') limit?: string,
  ) {
    return this.airspacesService.getAirspacesInBounds(
      parseFloat(minLat),
      parseFloat(maxLat),
      parseFloat(minLng),
      parseFloat(maxLng),
      types ? types.split(',') : undefined,
      classes ? classes.split(',') : undefined,
      limit ? parseInt(limit, 10) : 500,
    );
  }

  @Get('airways/bounds')
  async airwaysInBounds(
    @Query('minLat') minLat: string,
    @Query('maxLat') maxLat: string,
    @Query('minLng') minLng: string,
    @Query('maxLng') maxLng: string,
    @Query('types') types?: string,
    @Query('limit') limit?: string,
  ) {
    return this.airspacesService.getAirwaysInBounds(
      parseFloat(minLat),
      parseFloat(maxLat),
      parseFloat(minLng),
      parseFloat(maxLng),
      types ? types.split(',') : undefined,
      limit ? parseInt(limit, 10) : 1000,
    );
  }

  @Get('artcc/bounds')
  async artccInBounds(
    @Query('minLat') minLat: string,
    @Query('maxLat') maxLat: string,
    @Query('minLng') minLng: string,
    @Query('maxLng') maxLng: string,
    @Query('limit') limit?: string,
  ) {
    return this.airspacesService.getArtccInBounds(
      parseFloat(minLat),
      parseFloat(maxLat),
      parseFloat(minLng),
      parseFloat(maxLng),
      limit ? parseInt(limit, 10) : 100,
    );
  }
}
