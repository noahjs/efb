import { Module } from '@nestjs/common';
import { BriefingController } from './briefing.controller';
import { BriefingService } from './briefing.service';
import { FlightsModule } from '../flights/flights.module';
import { WeatherModule } from '../weather/weather.module';
import { ImageryModule } from '../imagery/imagery.module';
import { WindyModule } from '../windy/windy.module';
import { CalculateModule } from '../calculate/calculate.module';
import { AirspacesModule } from '../airspaces/airspaces.module';
import { AirportsModule } from '../airports/airports.module';

@Module({
  imports: [
    FlightsModule,
    WeatherModule,
    ImageryModule,
    WindyModule,
    CalculateModule,
    AirspacesModule,
    AirportsModule,
  ],
  controllers: [BriefingController],
  providers: [BriefingService],
  exports: [BriefingService],
})
export class BriefingModule {}
