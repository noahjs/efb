import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { WeightBalanceController } from './weight-balance.controller';
import { FlightWBController } from './flight-wb.controller';
import { WeightBalanceService } from './weight-balance.service';
import { WBProfile } from './entities/wb-profile.entity';
import { WBStation } from './entities/wb-station.entity';
import { WBEnvelope } from './entities/wb-envelope.entity';
import { WBScenario } from './entities/wb-scenario.entity';
import { Flight } from '../flights/entities/flight.entity';
import { AircraftModule } from '../aircraft/aircraft.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      WBProfile,
      WBStation,
      WBEnvelope,
      WBScenario,
      Flight,
    ]),
    AircraftModule,
  ],
  controllers: [WeightBalanceController, FlightWBController],
  providers: [WeightBalanceService],
  exports: [WeightBalanceService],
})
export class WeightBalanceModule {}
