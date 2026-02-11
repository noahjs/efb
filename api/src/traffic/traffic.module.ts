import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { TrafficController } from './traffic.controller';
import { TrafficService } from './traffic.service';
import { TRAFFIC } from '../config/constants';

@Module({
  imports: [HttpModule.register({ timeout: TRAFFIC.TIMEOUT_MS })],
  controllers: [TrafficController],
  providers: [TrafficService],
  exports: [TrafficService],
})
export class TrafficModule {}
