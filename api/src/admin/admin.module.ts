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
import { Fbo } from '../fbos/entities/fbo.entity';
import { FuelPrice } from '../fbos/entities/fuel-price.entity';
import { Metar } from '../data-platform/entities/metar.entity';
import { Taf } from '../data-platform/entities/taf.entity';
import { DataSource as DataSourceEntity } from '../data-platform/entities/data-source.entity';
import { PollerRun } from '../data-platform/entities/poller-run.entity';
import { MasterWBProfile } from '../aircraft/entities/master-wb-profile.entity';
import { WeatherModule } from '../weather/weather.module';
import { ImageryModule } from '../imagery/imagery.module';
import { WindyModule } from '../windy/windy.module';
import { TrafficModule } from '../traffic/traffic.module';
import { FilingModule } from '../filing/filing.module';
import { DataPlatformModule } from '../data-platform/data-platform.module';

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
      Fbo,
      FuelPrice,
      Metar,
      Taf,
      DataSourceEntity,
      PollerRun,
      MasterWBProfile,
    ]),
    WeatherModule,
    ImageryModule,
    WindyModule,
    TrafficModule,
    FilingModule,
    DataPlatformModule,
  ],
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
