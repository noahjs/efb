import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AirportsModule } from '../airports/airports.module';
import { WeatherController } from './weather.controller';
import { WeatherService } from './weather.service';
import { AtisTranscriptionService } from './atis-transcription.service';
import { WeatherStation } from './entities/weather-station.entity';
import { AtisRecording } from './entities/atis-recording.entity';
import { Metar } from '../data-platform/entities/metar.entity';
import { Taf } from '../data-platform/entities/taf.entity';
import { WindsAloft } from '../data-platform/entities/winds-aloft.entity';
import { Notam } from '../data-platform/entities/notam.entity';
import { NwsForecast } from '../data-platform/entities/nws-forecast.entity';

@Module({
  imports: [
    HttpModule.register({
      timeout: 10000,
      maxRedirects: 3,
    }),
    TypeOrmModule.forFeature([
      WeatherStation,
      AtisRecording,
      Metar,
      Taf,
      WindsAloft,
      Notam,
      NwsForecast,
    ]),
    AirportsModule,
  ],
  controllers: [WeatherController],
  providers: [WeatherService, AtisTranscriptionService],
  exports: [WeatherService],
})
export class WeatherModule {}
