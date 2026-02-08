import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { RoutesController } from './routes.controller';
import { RoutesService } from './routes.service';
import { PreferredRoute } from './entities/preferred-route.entity';
import { PreferredRouteSegment } from './entities/preferred-route-segment.entity';

@Module({
  imports: [TypeOrmModule.forFeature([PreferredRoute, PreferredRouteSegment])],
  controllers: [RoutesController],
  providers: [RoutesService],
  exports: [RoutesService],
})
export class RoutesModule {}
