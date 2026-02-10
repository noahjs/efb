import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { WindyController } from './windy.controller';
import { WindyService } from './windy.service';

@Module({
  imports: [HttpModule.register({ timeout: 15000 })],
  controllers: [WindyController],
  providers: [WindyService],
  exports: [WindyService],
})
export class WindyModule {}
