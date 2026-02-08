import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CalculateController } from './calculate.controller';
import { CalculateService } from './calculate.service';
import { NavaidsModule } from '../navaids/navaids.module';
import { Airport } from '../airports/entities/airport.entity';
import { PerformanceProfile } from '../aircraft/entities/performance-profile.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([Airport, PerformanceProfile]),
    NavaidsModule,
  ],
  controllers: [CalculateController],
  providers: [CalculateService],
  exports: [CalculateService],
})
export class CalculateModule {}
