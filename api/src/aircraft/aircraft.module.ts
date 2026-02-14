import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AircraftController } from './aircraft.controller';
import { AircraftService } from './aircraft.service';
import { Aircraft } from './entities/aircraft.entity';
import { PerformanceProfile } from './entities/performance-profile.entity';
import { FuelTank } from './entities/fuel-tank.entity';
import { Equipment } from './entities/equipment.entity';
import { MasterWBProfile } from './entities/master-wb-profile.entity';
import { WBProfile } from '../weight-balance/entities/wb-profile.entity';
import { WBStation } from '../weight-balance/entities/wb-station.entity';
import { WBEnvelope } from '../weight-balance/entities/wb-envelope.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Aircraft,
      PerformanceProfile,
      FuelTank,
      Equipment,
      MasterWBProfile,
      WBProfile,
      WBStation,
      WBEnvelope,
    ]),
  ],
  controllers: [AircraftController],
  providers: [AircraftService],
  exports: [AircraftService],
})
export class AircraftModule {}
