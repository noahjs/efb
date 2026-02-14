import {
  Controller,
  Get,
  Param,
  Query,
  Res,
  ParseFloatPipe,
  ParseIntPipe,
  DefaultValuePipe,
  BadRequestException,
} from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';
import type { Response } from 'express';
import { Public } from '../auth/guards/public.decorator';
import { HrrrService } from './hrrr.service';
import {
  HrrrTileService,
  TILE_PRODUCTS,
  TileProduct,
} from './hrrr-tile.service';
import { HRRR } from '../config/constants';

const VALID_PRESSURE_LEVELS = new Set(HRRR.PRESSURE_LEVELS);

@Public()
@Controller('hrrr')
export class HrrrController {
  constructor(
    private readonly hrrrService: HrrrService,
    private readonly hrrrTileService: HrrrTileService,
  ) {}

  // --- Admin ---

  @Get('cycles')
  getCycles(
    @Query('limit', new DefaultValuePipe(10), ParseIntPipe) limit: number,
  ) {
    return this.hrrrService.getCycles(limit);
  }

  // --- Metadata ---

  @Get('meta')
  getMeta() {
    return this.hrrrService.getMeta();
  }

  // --- Route Weather ---

  @Get('route')
  getRouteWeather(
    @Query('waypoints') waypointsJson: string,
    @Query('altitude', ParseFloatPipe) altitudeFt: number,
  ) {
    const waypoints = this.parseWaypoints(waypointsJson);
    return this.hrrrService.getRouteWeather(waypoints, altitudeFt);
  }

  // --- Route Profile (cross-section) ---

  @Get('profile')
  getRouteProfile(@Query('waypoints') waypointsJson: string) {
    const waypoints = this.parseWaypoints(waypointsJson);
    return this.hrrrService.getRouteProfile(waypoints);
  }

  // --- Wind Comparison ---

  @Get('compare-winds')
  compareWinds(
    @Query('lat', ParseFloatPipe) lat: number,
    @Query('lng', ParseFloatPipe) lng: number,
  ) {
    return this.hrrrService.compareWinds(lat, lng);
  }

  // --- Tiles ---

  @SkipThrottle()
  @Get('tiles/:product/:z/:x/:yPng')
  async getTile(
    @Param('product') product: string,
    @Param('z') zStr: string,
    @Param('x') xStr: string,
    @Param('yPng') yPng: string,
    @Query('fh', new DefaultValuePipe(1), ParseIntPipe) fh: number,
    @Query('level', new DefaultValuePipe(850), ParseIntPipe) level: number,
    @Res() res: Response,
  ) {
    // Validate product
    if (!TILE_PRODUCTS.includes(product as TileProduct)) {
      throw new BadRequestException(
        `Invalid product "${product}". Valid: ${TILE_PRODUCTS.join(', ')}`,
      );
    }

    // Parse y from "5.png"
    const yMatch = yPng.match(/^(\d+)\.png$/);
    if (!yMatch) {
      throw new BadRequestException('Tile URL must end with {y}.png');
    }
    const y = Number(yMatch[1]);
    const z = Number(zStr);
    const x = Number(xStr);

    if (isNaN(z) || isNaN(x) || isNaN(y)) {
      throw new BadRequestException('z, x, y must be integers');
    }

    // Validate zoom
    if (z < HRRR.TILE_ZOOM_MIN || z > HRRR.TILE_ZOOM_MAX) {
      throw new BadRequestException(
        `Zoom must be between ${HRRR.TILE_ZOOM_MIN} and ${HRRR.TILE_ZOOM_MAX}`,
      );
    }

    // Validate forecast hour
    if (fh < 0 || fh > 18) {
      throw new BadRequestException('Forecast hour must be between 0 and 18');
    }

    // Validate pressure level (only matters for 'clouds' product)
    if (product === 'clouds' && !VALID_PRESSURE_LEVELS.has(level)) {
      throw new BadRequestException(
        `Invalid pressure level ${level}. Valid: ${HRRR.PRESSURE_LEVELS.join(', ')}`,
      );
    }

    const buffer = await this.hrrrTileService.renderTile(
      product as TileProduct,
      z,
      x,
      y,
      fh,
      product === 'clouds' ? level : undefined,
    );

    res.set({
      'Content-Type': 'image/png',
      'Cache-Control': 'public, max-age=300',
      'Content-Length': buffer.length,
    });
    res.send(buffer);
  }

  // --- Helpers ---

  private parseWaypoints(
    json: string,
  ): Array<{ lat: number; lng: number }> {
    if (!json) {
      throw new BadRequestException('waypoints query parameter is required');
    }
    try {
      const parsed = JSON.parse(json);
      if (!Array.isArray(parsed) || parsed.length === 0) {
        throw new Error('must be a non-empty array');
      }
      return parsed.map((wp: any) => {
        const lat = Number(wp.lat);
        const lng = Number(wp.lng);
        if (isNaN(lat) || isNaN(lng)) {
          throw new Error('each waypoint must have numeric lat and lng');
        }
        return { lat, lng };
      });
    } catch (e) {
      throw new BadRequestException(
        `Invalid waypoints JSON: ${e.message}`,
      );
    }
  }
}
