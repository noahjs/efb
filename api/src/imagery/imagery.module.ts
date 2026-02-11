import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { ImageryController } from './imagery.controller';
import { ImageryService } from './imagery.service';

@Module({
  imports: [
    HttpModule.register({
      timeout: 15000,
      maxRedirects: 3,
    }),
  ],
  controllers: [ImageryController],
  providers: [ImageryService],
  exports: [ImageryService],
})
export class ImageryModule {}
