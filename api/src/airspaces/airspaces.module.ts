import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AirspacesController } from './airspaces.controller';
import { AirspacesService } from './airspaces.service';
import { Airspace } from './entities/airspace.entity';
import { AirwaySegment } from './entities/airway-segment.entity';
import { ArtccBoundary } from './entities/artcc-boundary.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Airspace, AirwaySegment, ArtccBoundary])],
  controllers: [AirspacesController],
  providers: [AirspacesService],
  exports: [AirspacesService],
})
export class AirspacesModule {}
