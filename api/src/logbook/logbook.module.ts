import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { LogbookEntry } from './entities/logbook-entry.entity';
import { Endorsement } from './entities/endorsement.entity';
import { LogbookController } from './logbook.controller';
import { LogbookService } from './logbook.service';
import { EndorsementsController } from './endorsements.controller';
import { EndorsementsService } from './endorsements.service';

@Module({
  imports: [TypeOrmModule.forFeature([LogbookEntry, Endorsement])],
  controllers: [LogbookController, EndorsementsController],
  providers: [LogbookService, EndorsementsService],
  exports: [LogbookService, EndorsementsService],
})
export class LogbookModule {}
