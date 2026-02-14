import { Module, Global } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DataCycle } from './entities/data-cycle.entity';
import { DataCycleService } from './data-cycle.service';
import { DataCycleController } from './data-cycle.controller';
import { CycleQueryHelper } from './cycle-query.helper';

@Global()
@Module({
  imports: [TypeOrmModule.forFeature([DataCycle])],
  controllers: [DataCycleController],
  providers: [DataCycleService, CycleQueryHelper],
  exports: [DataCycleService, CycleQueryHelper],
})
export class DataCycleModule {}
