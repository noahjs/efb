import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AirportsModule } from '../airports/airports.module';
import { WeatherController } from './weather.controller';
import { WeatherService } from './weather.service';
import { AtisTranscriptionService } from './atis-transcription.service';
import { WeatherStation } from './entities/weather-station.entity';
import { AtisRecording } from './entities/atis-recording.entity';

@Module({
  imports: [
    HttpModule.register({
      timeout: 10000,
      maxRedirects: 3,
    }),
    TypeOrmModule.forFeature([WeatherStation, AtisRecording]),
    AirportsModule,
  ],
  controllers: [WeatherController],
  providers: [WeatherService, AtisTranscriptionService],
  exports: [WeatherService],
})
export class WeatherModule {}
