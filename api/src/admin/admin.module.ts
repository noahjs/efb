import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { Airport } from '../airports/entities/airport.entity';
import { Runway } from '../airports/entities/runway.entity';
import { Frequency } from '../airports/entities/frequency.entity';
import { Navaid } from '../navaids/entities/navaid.entity';
import { Fix } from '../navaids/entities/fix.entity';
import { Procedure } from '../procedures/entities/procedure.entity';
import { DtppCycle } from '../procedures/entities/dtpp-cycle.entity';
import { FaaRegistryAircraft } from '../registry/entities/faa-registry-aircraft.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Airport,
      Runway,
      Frequency,
      Navaid,
      Fix,
      Procedure,
      DtppCycle,
      FaaRegistryAircraft,
    ]),
  ],
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
