import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ImageryController } from './imagery.controller';
import { ImageryService } from './imagery.service';
import { Advisory } from '../data-platform/entities/advisory.entity';
import { Pirep } from '../data-platform/entities/pirep.entity';
import { Tfr } from '../data-platform/entities/tfr.entity';
import { StormCell } from '../data-platform/entities/storm-cell.entity';
import { LightningThreat } from '../data-platform/entities/lightning-threat.entity';
import { WeatherAlert } from '../data-platform/entities/weather-alert.entity';

@Module({
  imports: [
    HttpModule.register({
      timeout: 15000,
      maxRedirects: 3,
    }),
    TypeOrmModule.forFeature([Advisory, Pirep, Tfr, StormCell, LightningThreat, WeatherAlert]),
  ],
  controllers: [ImageryController],
  providers: [ImageryService],
  exports: [ImageryService],
})
export class ImageryModule {}
