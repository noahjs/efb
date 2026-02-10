import { Controller, Get, Param, Query } from '@nestjs/common';
import { RoutesService } from './routes.service';
import { Public } from '../auth/guards/public.decorator';

@Public()
@Controller()
export class RoutesController {
  constructor(private readonly routesService: RoutesService) {}

  @Get('routes/preferred')
  async searchPreferred(
    @Query('origin') origin: string,
    @Query('destination') destination: string,
    @Query('type') type?: string,
  ) {
    return this.routesService.search(origin, destination, type);
  }

  @Get('routes/preferred/from/:id')
  async fromOrigin(@Param('id') id: string, @Query('type') type?: string) {
    return this.routesService.findByOrigin(id, type);
  }

  @Get('routes/types')
  async getRouteTypes() {
    return this.routesService.getRouteTypes();
  }
}
