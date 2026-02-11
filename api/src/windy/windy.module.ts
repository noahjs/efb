import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { WindyController } from './windy.controller';
import { WindyService } from './windy.service';
import { ElevationService } from './elevation.service';

@Module({
  imports: [HttpModule.register({ timeout: 15000 })],
  controllers: [WindyController],
  providers: [WindyService, ElevationService],
  exports: [WindyService, ElevationService],
})
export class WindyModule {}
