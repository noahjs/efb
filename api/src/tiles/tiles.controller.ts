import { Controller, Get, Param, Res, NotFoundException } from '@nestjs/common';
import type { Response } from 'express';
import * as path from 'path';
import * as fs from 'fs';
import { Public } from '../auth/guards/public.decorator';

@Public()
@Controller('tiles')
export class TilesController {
  private readonly tilesDir = path.join(
    __dirname,
    '..',
    '..',
    'data',
    'charts',
    'tiles',
  );

  /**
   * Serve VFR Sectional chart tiles.
   * URL pattern: /api/tiles/vfr-sectional/:chart/:z/:x/:y.png
   *
   * gdal2tiles generates TMS tiles (y is flipped vs XYZ).
   * Mapbox requests XYZ tiles, so we flip the y coordinate.
   */
  @Get('vfr-sectional/:chart/:z/:x/:y.png')
  async getVfrTile(
    @Param('chart') chart: string,
    @Param('z') z: string,
    @Param('x') x: string,
    @Param('y') yPng: string,
    @Res() res: Response,
  ) {
    const y = yPng.replace('.png', '');
    const zoom = parseInt(z, 10);
    const yXyz = parseInt(y, 10);

    // Convert XYZ y to TMS y: tmsY = (2^z - 1) - xyzY
    const tmsY = (1 << zoom) - 1 - yXyz;

    const tilePath = path.join(
      this.tilesDir,
      'vfr-sectional',
      chart,
      z,
      x,
      `${tmsY}.png`,
    );

    if (!fs.existsSync(tilePath)) {
      // Return a transparent 1x1 PNG for missing tiles
      res.set('Content-Type', 'image/png');
      res.set('Cache-Control', 'public, max-age=86400');
      // 1x1 transparent PNG
      const transparentPng = Buffer.from(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVQI12NgAAIABQABNjN9GQAAAAlwSFlzAAAWJQAAFiUBSVIk8AAAAA0lEQVQI12P4z8BQDwAEgAF/QualIQAAAABJRU5ErkJggg==',
        'base64',
      );
      return res.send(transparentPng);
    }

    res.set('Content-Type', 'image/png');
    res.set('Cache-Control', 'public, max-age=86400');
    res.sendFile(tilePath);
  }

  /**
   * List available chart tile sets.
   */
  @Get('vfr-sectional')
  listCharts() {
    const chartsDir = path.join(this.tilesDir, 'vfr-sectional');
    if (!fs.existsSync(chartsDir)) {
      return { charts: [] };
    }

    const charts = fs
      .readdirSync(chartsDir, { withFileTypes: true })
      .filter((d) => d.isDirectory())
      .map((d) => d.name);

    return { charts };
  }
}
