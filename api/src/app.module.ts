import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AirportsModule } from './airports/airports.module';
import { WeatherModule } from './weather/weather.module';
import { TilesModule } from './tiles/tiles.module';
import { AdminModule } from './admin/admin.module';
import { Airport } from './airports/entities/airport.entity';
import { Runway } from './airports/entities/runway.entity';
import { RunwayEnd } from './airports/entities/runway-end.entity';
import { Frequency } from './airports/entities/frequency.entity';

@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: 'better-sqlite3',
      database: 'data/efb.sqlite',
      entities: [Airport, Runway, RunwayEnd, Frequency],
      synchronize: true, // Auto-create tables in dev
    }),
    AirportsModule,
    WeatherModule,
    TilesModule,
    AdminModule,
  ],
})
export class AppModule {}
