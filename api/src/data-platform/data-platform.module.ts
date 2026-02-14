import { Module, OnModuleInit } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HttpModule } from '@nestjs/axios';
import { ScheduleModule } from '@nestjs/schedule';

// Entities
import { DataSource } from './entities/data-source.entity';
import { Metar } from './entities/metar.entity';
import { Taf } from './entities/taf.entity';
import { Advisory } from './entities/advisory.entity';
import { Pirep } from './entities/pirep.entity';
import { Tfr } from './entities/tfr.entity';
import { WindsAloft } from './entities/winds-aloft.entity';
import { WindGrid } from './entities/wind-grid.entity';
import { Notam } from './entities/notam.entity';
import { NwsForecast } from './entities/nws-forecast.entity';
import { StormCell } from './entities/storm-cell.entity';
import { LightningThreat } from './entities/lightning-threat.entity';
import { WeatherAlert } from './entities/weather-alert.entity';
import { PollerRun } from './entities/poller-run.entity';
import { HrrrCycle } from './entities/hrrr-cycle.entity';
import { HrrrSurface } from './entities/hrrr-surface.entity';
import { HrrrPressure } from './entities/hrrr-pressure.entity';
import { HrrrTileMeta } from './entities/hrrr-tile-meta.entity';
import { Airport } from '../airports/entities/airport.entity';
import { Fbo } from '../fbos/entities/fbo.entity';
import { FuelPrice } from '../fbos/entities/fuel-price.entity';

// Infrastructure
import { DataSchedulerService } from './data-scheduler.service';
import { DataWorkerService } from './data-worker.service';
import { DataCleanupService } from './data-cleanup.service';

// Pollers
import { AdvisoryPoller } from './pollers/advisory.poller';
import { PirepPoller } from './pollers/pirep.poller';
import { TfrPoller } from './pollers/tfr.poller';
import { MetarPoller } from './pollers/metar.poller';
import { TafPoller } from './pollers/taf.poller';
import { WindsAloftPoller } from './pollers/winds-aloft.poller';
import { WindGridPoller } from './pollers/wind-grid.poller';
import { NotamPoller } from './pollers/notam.poller';
import { FboPoller } from './pollers/fbo.poller';
import { FuelPricePoller } from './pollers/fuel-price.poller';
import { StormCellPoller } from './pollers/storm-cell.poller';
import { LightningThreatPoller } from './pollers/lightning-threat.poller';
import { WeatherAlertPoller } from './pollers/weather-alert.poller';
import { HrrrPoller } from './pollers/hrrr.poller';
import { NotificationPoller } from './pollers/notification.poller';
import { NotificationsModule } from '../notifications/notifications.module';

const entities = [
  DataSource,
  Metar,
  Taf,
  Advisory,
  Pirep,
  Tfr,
  WindsAloft,
  WindGrid,
  Notam,
  NwsForecast,
  StormCell,
  LightningThreat,
  WeatherAlert,
  PollerRun,
  HrrrCycle,
  HrrrSurface,
  HrrrPressure,
  HrrrTileMeta,
  Airport,
  Fbo,
  FuelPrice,
];

@Module({
  imports: [
    ScheduleModule.forRoot(),
    TypeOrmModule.forFeature(entities),
    HttpModule.register({ timeout: 30000, maxRedirects: 3 }),
    NotificationsModule,
  ],
  providers: [
    DataSchedulerService,
    DataWorkerService,
    DataCleanupService,
    AdvisoryPoller,
    PirepPoller,
    TfrPoller,
    MetarPoller,
    TafPoller,
    WindsAloftPoller,
    WindGridPoller,
    NotamPoller,
    FboPoller,
    FuelPricePoller,
    StormCellPoller,
    LightningThreatPoller,
    WeatherAlertPoller,
    HrrrPoller,
    NotificationPoller,
  ],
  exports: [DataSchedulerService, DataWorkerService, TypeOrmModule],
})
export class DataPlatformModule implements OnModuleInit {
  constructor(
    private readonly worker: DataWorkerService,
    private readonly advisoryPoller: AdvisoryPoller,
    private readonly pirepPoller: PirepPoller,
    private readonly tfrPoller: TfrPoller,
    private readonly metarPoller: MetarPoller,
    private readonly tafPoller: TafPoller,
    private readonly windsAloftPoller: WindsAloftPoller,
    private readonly windGridPoller: WindGridPoller,
    private readonly notamPoller: NotamPoller,
    private readonly fboPoller: FboPoller,
    private readonly fuelPricePoller: FuelPricePoller,
    private readonly stormCellPoller: StormCellPoller,
    private readonly lightningThreatPoller: LightningThreatPoller,
    private readonly weatherAlertPoller: WeatherAlertPoller,
    private readonly hrrrPoller: HrrrPoller,
    private readonly notificationPoller: NotificationPoller,
  ) {}

  async onModuleInit() {
    // Register all pollers with the worker BEFORE starting it
    this.worker.registerPoller('advisory_poll', this.advisoryPoller);
    this.worker.registerPoller('pirep_poll', this.pirepPoller);
    this.worker.registerPoller('tfr_poll', this.tfrPoller);
    this.worker.registerPoller('metar_poll', this.metarPoller);
    this.worker.registerPoller('taf_poll', this.tafPoller);
    this.worker.registerPoller('winds_aloft_poll', this.windsAloftPoller);
    this.worker.registerPoller('wind_grid_poll', this.windGridPoller);
    this.worker.registerPoller('notam_poll', this.notamPoller);
    this.worker.registerPoller('fbo_poll', this.fboPoller);
    this.worker.registerPoller('fuel_price_poll', this.fuelPricePoller);
    this.worker.registerPoller('storm_cell_poll', this.stormCellPoller);
    this.worker.registerPoller('lightning_threat_poll', this.lightningThreatPoller);
    this.worker.registerPoller('weather_alert_poll', this.weatherAlertPoller);
    this.worker.registerPoller('hrrr_poll', this.hrrrPoller);
    this.worker.registerPoller('notification_dispatch', this.notificationPoller);

    // Now start processing jobs (pollers are guaranteed registered)
    await this.worker.start();
  }
}
