import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { LogbookEntry } from './entities/logbook-entry.entity';
import { Endorsement } from './entities/endorsement.entity';
import { Certificate } from './entities/certificate.entity';
import { LogbookController } from './logbook.controller';
import { LogbookService } from './logbook.service';
import { EndorsementsController } from './endorsements.controller';
import { EndorsementsService } from './endorsements.service';
import { CertificatesController } from './certificates.controller';
import { CertificatesService } from './certificates.service';
import { CurrencyService } from './currency.service';
import { ImportService } from './import.service';

@Module({
  imports: [TypeOrmModule.forFeature([LogbookEntry, Endorsement, Certificate])],
  controllers: [
    LogbookController,
    EndorsementsController,
    CertificatesController,
  ],
  providers: [
    LogbookService,
    EndorsementsService,
    CertificatesService,
    CurrencyService,
    ImportService,
  ],
  exports: [LogbookService, EndorsementsService, CertificatesService],
})
export class LogbookModule {}
