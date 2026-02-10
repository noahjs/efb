import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CifpApproach, CifpLeg, CifpIls, CifpMsa, CifpRunway } from './entities';
import { CifpService } from './cifp.service';
import { CifpController } from './cifp.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      CifpApproach,
      CifpLeg,
      CifpIls,
      CifpMsa,
      CifpRunway,
    ]),
  ],
  controllers: [CifpController],
  providers: [CifpService],
  exports: [CifpService],
})
export class CifpModule {}
