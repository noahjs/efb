import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AircraftController } from './aircraft.controller';
import { AircraftService } from './aircraft.service';
import { Aircraft } from './entities/aircraft.entity';
import { PerformanceProfile } from './entities/performance-profile.entity';
import { FuelTank } from './entities/fuel-tank.entity';
import { Equipment } from './entities/equipment.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Aircraft,
      PerformanceProfile,
      FuelTank,
      Equipment,
    ]),
  ],
  controllers: [AircraftController],
  providers: [AircraftService],
  exports: [AircraftService],
})
export class AircraftModule {}
