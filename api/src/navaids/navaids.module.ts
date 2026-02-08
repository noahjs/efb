import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { NavaidsController } from './navaids.controller';
import { NavaidsService } from './navaids.service';
import { Navaid } from './entities/navaid.entity';
import { Fix } from './entities/fix.entity';
import { Airport } from '../airports/entities/airport.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Navaid, Fix, Airport])],
  controllers: [NavaidsController],
  providers: [NavaidsService],
  exports: [NavaidsService],
})
export class NavaidsModule {}
