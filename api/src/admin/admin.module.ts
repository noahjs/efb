import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { Airport } from '../airports/entities/airport.entity';
import { Runway } from '../airports/entities/runway.entity';
import { Frequency } from '../airports/entities/frequency.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Airport, Runway, Frequency])],
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
