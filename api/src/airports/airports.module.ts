import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AirportsController } from './airports.controller';
import { AirportsService } from './airports.service';
import { Airport, Runway, RunwayEnd, Frequency } from './entities';
import { Fbo } from '../fbos/entities/fbo.entity';
import { FuelPrice } from '../fbos/entities/fuel-price.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Airport,
      Runway,
      RunwayEnd,
      Frequency,
      Fbo,
      FuelPrice,
    ]),
  ],
  controllers: [AirportsController],
  providers: [AirportsService],
  exports: [AirportsService],
})
export class AirportsModule {}
