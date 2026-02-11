import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { FilingController } from './filing.controller';
import { FilingService } from './filing.service';
import { LeidosMockService } from './leidos-mock.service';
import { LeidosService } from './leidos.service';
import { FlightsModule } from '../flights/flights.module';
import { AircraftModule } from '../aircraft/aircraft.module';
import { UsersModule } from '../users/users.module';
import { AirportsModule } from '../airports/airports.module';
import { filingConfig } from './filing.config';

@Module({
  imports: [
    HttpModule,
    FlightsModule,
    AircraftModule,
    UsersModule,
    AirportsModule,
  ],
  controllers: [FilingController],
  providers: [
    FilingService,
    LeidosService,
    {
      provide: 'LEIDOS_CLIENT',
      useClass: filingConfig.useMock ? LeidosMockService : LeidosService,
    },
  ],
  exports: [LeidosService],
})
export class FilingModule {}
