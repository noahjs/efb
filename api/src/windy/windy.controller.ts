import {
  Controller,
  Get,
  Post,
  Query,
  Body,
  Res,
  Header,
} from '@nestjs/common';
import type { Response } from 'express';
import { WindyService } from './windy.service';
import { ElevationService } from './elevation.service';
import { Public } from '../auth/guards/public.decorator';

@Public()
@Controller('windy')
export class WindyController {
  constructor(
    private readonly windyService: WindyService,
    private readonly elevationService: ElevationService,
  ) {}

  /**
   * GET /api/windy/point?lat=39.57&lng=-104.85&model=namConus
   * Returns wind forecast at all pressure levels for a single coordinate.
   */
  @Get('point')
  async pointForecast(
    @Query('lat') lat: string,
    @Query('lng') lng: string,
    @Query('model') model?: string,
  ) {
    return this.windyService.getPointForecast(
      parseFloat(lat),
      parseFloat(lng),
      model,
    );
  }

  /**
   * POST /api/windy/route
   * Body: { waypoints: [{lat, lng}, ...], altitude: 35000, tas: 250 }
   * Returns wind data along a route at a specific altitude.
   */
  @Post('route')
  async routeWinds(
    @Body()
    body: {
      waypoints: Array<{ lat: number; lng: number }>;
      altitude: number;
      tas: number;
    },
  ) {
    return this.windyService.getRouteWinds(
      body.waypoints,
      body.altitude,
      body.tas,
    );
  }

  /**
   * GET /api/windy/grid?minLat=38&maxLat=42&minLng=-106&maxLng=-102&altitude=10000
   * Returns GeoJSON grid of wind data for map overlay.
   */
  @Get('grid')
  async windGrid(
    @Query('minLat') minLat: string,
    @Query('maxLat') maxLat: string,
    @Query('minLng') minLng: string,
    @Query('maxLng') maxLng: string,
    @Query('altitude') altitude: string,
    @Query('spacing') spacing?: string,
  ) {
    return this.windyService.getWindGrid(
      {
        minLat: parseFloat(minLat),
        maxLat: parseFloat(maxLat),
        minLng: parseFloat(minLng),
        maxLng: parseFloat(maxLng),
      },
      parseInt(altitude, 10),
      spacing ? parseFloat(spacing) : undefined,
    );
  }

  /**
   * GET /api/windy/streamlines?minLat=38&maxLat=42&minLng=-106&maxLng=-102&altitude=10000
   * Returns GeoJSON LineString features representing wind flow streamlines.
   */
  /**
   * POST /api/windy/profile
   * Body: { waypoints: [{lat, lng}, ...], altitude: 9500, tas: 120, waypointIdentifiers?: ['APA', 'COS'] }
   * Returns terrain elevation + wind profile along a route.
   */
  @Post('profile')
  async routeProfile(
    @Body()
    body: {
      waypoints: Array<{ lat: number; lng: number }>;
      altitude: number;
      tas: number;
      waypointIdentifiers?: string[];
    },
  ) {
    return this.elevationService.getRouteProfile(
      body.waypoints,
      body.altitude,
      body.tas,
      body.waypointIdentifiers,
    );
  }

  /**
   * GET /api/windy/heatmap?minLat=38&maxLat=42&minLng=-106&maxLng=-102&altitude=10000&width=256&height=256
   * Returns a PNG image of wind speed heatmap.
   */
  @Get('heatmap')
  @Header('Content-Type', 'image/png')
  @Header('Cache-Control', 'public, max-age=1800')
  async windHeatmap(
    @Query('minLat') minLat: string,
    @Query('maxLat') maxLat: string,
    @Query('minLng') minLng: string,
    @Query('maxLng') maxLng: string,
    @Query('altitude') altitude: string,
    @Query('width') width?: string,
    @Query('height') height?: string,
    @Res() res?: Response,
  ) {
    const buffer = await this.windyService.getWindHeatmapPng(
      {
        minLat: parseFloat(minLat),
        maxLat: parseFloat(maxLat),
        minLng: parseFloat(minLng),
        maxLng: parseFloat(maxLng),
      },
      parseInt(altitude, 10),
      width ? parseInt(width, 10) : 256,
      height ? parseInt(height, 10) : 256,
    );
    res!.end(buffer);
  }

  @Get('streamlines')
  async windStreamlines(
    @Query('minLat') minLat: string,
    @Query('maxLat') maxLat: string,
    @Query('minLng') minLng: string,
    @Query('maxLng') maxLng: string,
    @Query('altitude') altitude: string,
  ) {
    return this.windyService.getWindStreamlines(
      {
        minLat: parseFloat(minLat),
        maxLat: parseFloat(maxLat),
        minLng: parseFloat(minLng),
        maxLng: parseFloat(maxLng),
      },
      parseInt(altitude, 10),
    );
  }
}
