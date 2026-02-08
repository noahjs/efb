import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ProceduresController } from './procedures.controller';
import { ProceduresService } from './procedures.service';
import { Procedure } from './entities/procedure.entity';
import { DtppCycle } from './entities/dtpp-cycle.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Procedure, DtppCycle])],
  controllers: [ProceduresController],
  providers: [ProceduresService],
})
export class ProceduresModule {}
