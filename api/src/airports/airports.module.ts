import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AirportsController } from './airports.controller';
import { AirportsService } from './airports.service';
import { Airport, Runway, RunwayEnd, Frequency } from './entities';

@Module({
  imports: [TypeOrmModule.forFeature([Airport, Runway, RunwayEnd, Frequency])],
  controllers: [AirportsController],
  providers: [AirportsService],
  exports: [AirportsService],
})
export class AirportsModule {}
