import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { TypeOrmModule } from '@nestjs/typeorm';
import { WindyController } from './windy.controller';
import { WindyService } from './windy.service';
import { ElevationService } from './elevation.service';
import { WindGrid } from '../data-platform/entities/wind-grid.entity';

@Module({
  imports: [
    HttpModule.register({ timeout: 15000 }),
    TypeOrmModule.forFeature([WindGrid]),
  ],
  controllers: [WindyController],
  providers: [WindyService, ElevationService],
  exports: [WindyService, ElevationService],
})
export class WindyModule {}
