import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { LogbookEntry } from './entities/logbook-entry.entity';
import { LogbookController } from './logbook.controller';
import { LogbookService } from './logbook.service';

@Module({
  imports: [TypeOrmModule.forFeature([LogbookEntry])],
  controllers: [LogbookController],
  providers: [LogbookService],
  exports: [LogbookService],
})
export class LogbookModule {}
