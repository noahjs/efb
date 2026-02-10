import {
  Controller,
  Get,
  Param,
  Query,
  NotFoundException,
} from '@nestjs/common';
import { NavaidsService } from './navaids.service';
import { Public } from '../auth/guards/public.decorator';

@Public()
@Controller()
export class NavaidsController {
  constructor(private readonly navaidsService: NavaidsService) {}

  // --- Navaids ---

  @Get('navaids/search')
  async searchNavaids(
    @Query('q') query?: string,
    @Query('type') type?: string,
    @Query('limit') limit?: string,
  ) {
    return this.navaidsService.searchNavaids(
      query,
      type,
      limit ? parseInt(limit, 10) : 50,
    );
  }

  @Get('navaids/bounds')
  async navaidsInBounds(
    @Query('minLat') minLat: string,
    @Query('maxLat') maxLat: string,
    @Query('minLng') minLng: string,
    @Query('maxLng') maxLng: string,
    @Query('limit') limit?: string,
  ) {
    return this.navaidsService.getNavaidsInBounds(
      parseFloat(minLat),
      parseFloat(maxLat),
      parseFloat(minLng),
      parseFloat(maxLng),
      limit ? parseInt(limit, 10) : 200,
    );
  }

  @Get('navaids/:id')
  async findNavaid(@Param('id') id: string) {
    const navaid = await this.navaidsService.findNavaidById(id.toUpperCase());
    if (!navaid) {
      throw new NotFoundException(`Navaid ${id} not found`);
    }
    return navaid;
  }

  // --- Fixes ---

  @Get('fixes/search')
  async searchFixes(
    @Query('q') query?: string,
    @Query('limit') limit?: string,
  ) {
    return this.navaidsService.searchFixes(
      query,
      limit ? parseInt(limit, 10) : 50,
    );
  }

  // --- Waypoint Resolution ---

  @Get('waypoints/resolve')
  async resolveRoute(@Query('ids') ids: string) {
    if (!ids) return [];
    const identifiers = ids
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
    return this.navaidsService.resolveRoute(identifiers);
  }

  @Get('fixes/bounds')
  async fixesInBounds(
    @Query('minLat') minLat: string,
    @Query('maxLat') maxLat: string,
    @Query('minLng') minLng: string,
    @Query('maxLng') maxLng: string,
    @Query('limit') limit?: string,
  ) {
    return this.navaidsService.getFixesInBounds(
      parseFloat(minLat),
      parseFloat(maxLat),
      parseFloat(minLng),
      parseFloat(maxLng),
      limit ? parseInt(limit, 10) : 200,
    );
  }
}
