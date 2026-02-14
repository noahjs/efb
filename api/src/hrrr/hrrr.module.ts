import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HrrrController } from './hrrr.controller';
import { HrrrService } from './hrrr.service';
import { HrrrTileService } from './hrrr-tile.service';
import { HrrrCycle } from '../data-platform/entities/hrrr-cycle.entity';
import { HrrrSurface } from '../data-platform/entities/hrrr-surface.entity';
import { HrrrPressure } from '../data-platform/entities/hrrr-pressure.entity';
import { WindGrid } from '../data-platform/entities/wind-grid.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([HrrrCycle, HrrrSurface, HrrrPressure, WindGrid]),
  ],
  controllers: [HrrrController],
  providers: [HrrrService, HrrrTileService],
  exports: [HrrrService],
})
export class HrrrModule {}
