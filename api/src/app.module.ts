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
import { RoutesModule } from './routes/routes.module';
import { PreferredRoute } from './routes/entities/preferred-route.entity';
import { PreferredRouteSegment } from './routes/entities/preferred-route-segment.entity';
import { UsersModule } from './users/users.module';
import { User } from './users/entities/user.entity';
import { StarredAirport } from './users/entities/starred-airport.entity';
import { AircraftModule } from './aircraft/aircraft.module';
import { Aircraft } from './aircraft/entities/aircraft.entity';
import { PerformanceProfile } from './aircraft/entities/performance-profile.entity';
import { FuelTank } from './aircraft/entities/fuel-tank.entity';
import { Equipment } from './aircraft/entities/equipment.entity';
import { AirspacesModule } from './airspaces/airspaces.module';
import { Airspace } from './airspaces/entities/airspace.entity';
import { AirwaySegment } from './airspaces/entities/airway-segment.entity';
import { ArtccBoundary } from './airspaces/entities/artcc-boundary.entity';
import { CalculateModule } from './calculate/calculate.module';
import { ImageryModule } from './imagery/imagery.module';
import { LogbookModule } from './logbook/logbook.module';
import { LogbookEntry } from './logbook/entities/logbook-entry.entity';
import { Endorsement } from './logbook/entities/endorsement.entity';
import { FaaRegistryAircraft } from './registry/entities/faa-registry-aircraft.entity';
import { RegistryModule } from './registry/registry.module';
import { FilingModule } from './filing/filing.module';
import { dbConfig } from './db.config';

@Module({
  imports: [
    TypeOrmModule.forRoot({
      ...dbConfig,
      entities: [
        Airport,
        Runway,
        RunwayEnd,
        Frequency,
        Flight,
        Navaid,
        Fix,
        Procedure,
        DtppCycle,
        PreferredRoute,
        PreferredRouteSegment,
        User,
        StarredAirport,
        Aircraft,
        PerformanceProfile,
        FuelTank,
        Equipment,
        Airspace,
        AirwaySegment,
        ArtccBoundary,
        LogbookEntry,
        Endorsement,
        FaaRegistryAircraft,
      ],
    }),
    AirportsModule,
    WeatherModule,
    TilesModule,
    AdminModule,
    FlightsModule,
    NavaidsModule,
    ProceduresModule,
    RoutesModule,
    UsersModule,
    AircraftModule,
    AirspacesModule,
    CalculateModule,
    ImageryModule,
    LogbookModule,
    RegistryModule,
    FilingModule,
  ],
})
export class AppModule {}
