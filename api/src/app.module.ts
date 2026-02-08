import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AirportsModule } from './airports/airports.module';
import { WeatherModule } from './weather/weather.module';
import { TilesModule } from './tiles/tiles.module';
import { AdminModule } from './admin/admin.module';
import { FlightsModule } from './flights/flights.module';
import { NavaidsModule } from './navaids/navaids.module';
import { Airport } from './airports/entities/airport.entity';
import { Runway } from './airports/entities/runway.entity';
import { RunwayEnd } from './airports/entities/runway-end.entity';
import { Frequency } from './airports/entities/frequency.entity';
import { Flight } from './flights/entities/flight.entity';
import { Navaid } from './navaids/entities/navaid.entity';
import { Fix } from './navaids/entities/fix.entity';
import { Procedure } from './procedures/entities/procedure.entity';
import { DtppCycle } from './procedures/entities/dtpp-cycle.entity';
import { ProceduresModule } from './procedures/procedures.module';
import { dbConfig } from './db.config';

@Module({
  imports: [
    TypeOrmModule.forRoot({
      ...dbConfig,
      entities: [Airport, Runway, RunwayEnd, Frequency, Flight, Navaid, Fix, Procedure, DtppCycle],
    }),
    AirportsModule,
    WeatherModule,
    TilesModule,
    AdminModule,
    FlightsModule,
    NavaidsModule,
    ProceduresModule,
  ],
})
export class AppModule {}
