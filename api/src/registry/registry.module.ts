import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { FaaRegistryAircraft } from './entities/faa-registry-aircraft.entity';
import { RegistryController } from './registry.controller';
import { RegistryService } from './registry.service';

@Module({
  imports: [TypeOrmModule.forFeature([FaaRegistryAircraft])],
  controllers: [RegistryController],
  providers: [RegistryService],
})
export class RegistryModule {}
