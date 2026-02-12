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

// Infrastructure
import { DataSchedulerService } from './data-scheduler.service';
import { DataWorkerService } from './data-worker.service';

// Pollers
import { AdvisoryPoller } from './pollers/advisory.poller';
import { PirepPoller } from './pollers/pirep.poller';
import { TfrPoller } from './pollers/tfr.poller';
import { MetarPoller } from './pollers/metar.poller';
import { TafPoller } from './pollers/taf.poller';
import { WindsAloftPoller } from './pollers/winds-aloft.poller';
import { WindGridPoller } from './pollers/wind-grid.poller';
import { NotamPoller } from './pollers/notam.poller';

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
];

@Module({
  imports: [
    ScheduleModule.forRoot(),
    TypeOrmModule.forFeature(entities),
    HttpModule.register({ timeout: 30000, maxRedirects: 3 }),
  ],
  providers: [
    DataSchedulerService,
    DataWorkerService,
    AdvisoryPoller,
    PirepPoller,
    TfrPoller,
    MetarPoller,
    TafPoller,
    WindsAloftPoller,
    WindGridPoller,
    NotamPoller,
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
  ) {}

  onModuleInit() {
    // Register all pollers with the worker
    this.worker.registerPoller('advisory_poll', this.advisoryPoller);
    this.worker.registerPoller('pirep_poll', this.pirepPoller);
    this.worker.registerPoller('tfr_poll', this.tfrPoller);
    this.worker.registerPoller('metar_poll', this.metarPoller);
    this.worker.registerPoller('taf_poll', this.tafPoller);
    this.worker.registerPoller('winds_aloft_poll', this.windsAloftPoller);
    this.worker.registerPoller('wind_grid_poll', this.windGridPoller);
    this.worker.registerPoller('notam_poll', this.notamPoller);
  }
}
