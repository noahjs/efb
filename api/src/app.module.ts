import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ThrottlerModule } from '@nestjs/throttler';
import { AirportsModule } from './airports/airports.module';
import { WeatherModule } from './weather/weather.module';
import { WeatherStation } from './weather/entities/weather-station.entity';
import { AtisRecording } from './weather/entities/atis-recording.entity';
import { Fbo } from './fbos/entities/fbo.entity';
import { FuelPrice } from './fbos/entities/fuel-price.entity';
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
import { MasterWBProfile } from './aircraft/entities/master-wb-profile.entity';
import { AirspacesModule } from './airspaces/airspaces.module';
import { Airspace } from './airspaces/entities/airspace.entity';
import { AirwaySegment } from './airspaces/entities/airway-segment.entity';
import { ArtccBoundary } from './airspaces/entities/artcc-boundary.entity';
import { CalculateModule } from './calculate/calculate.module';
import { ImageryModule } from './imagery/imagery.module';
import { LogbookModule } from './logbook/logbook.module';
import { LogbookEntry } from './logbook/entities/logbook-entry.entity';
import { Endorsement } from './logbook/entities/endorsement.entity';
import { Certificate } from './logbook/entities/certificate.entity';
import { FaaRegistryAircraft } from './registry/entities/faa-registry-aircraft.entity';
import { RegistryModule } from './registry/registry.module';
import { FilingModule } from './filing/filing.module';
import { HealthModule } from './health/health.module';
import { WeightBalanceModule } from './weight-balance/weight-balance.module';
import { WBProfile } from './weight-balance/entities/wb-profile.entity';
import { WBStation } from './weight-balance/entities/wb-station.entity';
import { WBEnvelope } from './weight-balance/entities/wb-envelope.entity';
import { WBScenario } from './weight-balance/entities/wb-scenario.entity';
import { CifpModule } from './cifp/cifp.module';
import { WindyModule } from './windy/windy.module';
import { CifpApproach } from './cifp/entities/cifp-approach.entity';
import { CifpLeg } from './cifp/entities/cifp-leg.entity';
import { CifpIls } from './cifp/entities/cifp-ils.entity';
import { CifpMsa } from './cifp/entities/cifp-msa.entity';
import { CifpRunway } from './cifp/entities/cifp-runway.entity';
import { DocumentsModule } from './documents/documents.module';
import { Document } from './documents/entities/document.entity';
import { DocumentFolder } from './documents/entities/document-folder.entity';
import { TrafficModule } from './traffic/traffic.module';
import { AuthModule } from './auth/auth.module';
import { BriefingModule } from './briefing/briefing.module';
import { DataPlatformModule } from './data-platform/data-platform.module';
import { HrrrModule } from './hrrr/hrrr.module';
import { HrrrCycle } from './data-platform/entities/hrrr-cycle.entity';
import { HrrrSurface } from './data-platform/entities/hrrr-surface.entity';
import { HrrrPressure } from './data-platform/entities/hrrr-pressure.entity';
import { HrrrTileMeta } from './data-platform/entities/hrrr-tile-meta.entity';
import { Metar } from './data-platform/entities/metar.entity';
import { Taf } from './data-platform/entities/taf.entity';
import { Advisory } from './data-platform/entities/advisory.entity';
import { Pirep } from './data-platform/entities/pirep.entity';
import { Tfr } from './data-platform/entities/tfr.entity';
import { WindsAloft } from './data-platform/entities/winds-aloft.entity';
import { WindGrid } from './data-platform/entities/wind-grid.entity';
import { Notam } from './data-platform/entities/notam.entity';
import { NwsForecast } from './data-platform/entities/nws-forecast.entity';
import { Atis } from './data-platform/entities/atis.entity';
import { WeatherAlert } from './data-platform/entities/weather-alert.entity';
import { StormCell } from './data-platform/entities/storm-cell.entity';
import { LightningThreat } from './data-platform/entities/lightning-threat.entity';
import { DataSource as DataSourceEntity } from './data-platform/entities/data-source.entity';
import { PollerRun } from './data-platform/entities/poller-run.entity';
import { NotificationsModule } from './notifications/notifications.module';
import { DeviceToken } from './notifications/entities/device-token.entity';
import { NotificationLog } from './notifications/entities/notification-log.entity';
import { MetarCategoryCache } from './notifications/entities/metar-category-cache.entity';
import { dbConfig } from './db.config';
import { DataCycleModule } from './data-cycle/data-cycle.module';
import { DataCycle } from './data-cycle/entities/data-cycle.entity';

@Module({
  imports: [
    ConfigModule.forRoot(),
    TypeOrmModule.forRoot({
      ...dbConfig,
      entities: [
        DataCycle,
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
        MasterWBProfile,
        Airspace,
        AirwaySegment,
        ArtccBoundary,
        LogbookEntry,
        Endorsement,
        Certificate,
        FaaRegistryAircraft,
        WBProfile,
        WBStation,
        WBEnvelope,
        WBScenario,
        CifpApproach,
        CifpLeg,
        CifpIls,
        CifpMsa,
        CifpRunway,
        Document,
        DocumentFolder,
        WeatherStation,
        AtisRecording,
        Fbo,
        FuelPrice,
        DataSourceEntity,
        Metar,
        Taf,
        Advisory,
        Pirep,
        Tfr,
        WindsAloft,
        WindGrid,
        Notam,
        NwsForecast,
        Atis,
        WeatherAlert,
        StormCell,
        LightningThreat,
        HrrrCycle,
        HrrrSurface,
        HrrrPressure,
        HrrrTileMeta,
        PollerRun,
        DeviceToken,
        NotificationLog,
        MetarCategoryCache,
      ],
    }),
    ThrottlerModule.forRoot([{ ttl: 60000, limit: 100 }]),
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
    HealthModule,
    WeightBalanceModule,
    CifpModule,
    WindyModule,
    DocumentsModule,
    TrafficModule,
    AuthModule,
    BriefingModule,
    DataPlatformModule,
    HrrrModule,
    NotificationsModule,
    DataCycleModule,
  ],
})
export class AppModule {}
