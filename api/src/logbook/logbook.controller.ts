import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  ParseIntPipe,
  UseInterceptors,
  UploadedFile,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { LogbookService } from './logbook.service';
import { CurrencyService } from './currency.service';
import { ImportService } from './import.service';
import { CreateLogbookEntryDto } from './dto/create-logbook-entry.dto';
import { UpdateLogbookEntryDto } from './dto/update-logbook-entry.dto';
import { CurrentUser } from '../auth/decorators/current-user.decorator';

@Controller('logbook')
export class LogbookController {
  constructor(
    private readonly logbookService: LogbookService,
    private readonly currencyService: CurrencyService,
    private readonly importService: ImportService,
  ) {}

  @Get()
  findAll(
    @CurrentUser() user: { id: string },
    @Query('q') query?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.logbookService.findAll(
      user.id,
      query,
      limit ? parseInt(limit, 10) : 50,
      offset ? parseInt(offset, 10) : 0,
    );
  }

  @Get('summary')
  getSummary(@CurrentUser() user: { id: string }) {
    return this.logbookService.getSummary(user.id);
  }

  @Get('experience-report')
  getExperienceReport(
    @CurrentUser() user: { id: string },
    @Query('period') period?: string,
  ) {
    return this.logbookService.getExperienceReport(user.id, period);
  }

  @Get('currency')
  getCurrency(@CurrentUser() user: { id: string }) {
    return this.currencyService.getCurrency(user.id);
  }

  @Post('import')
  @UseInterceptors(
    FileInterceptor('file', { limits: { fileSize: 10 * 1024 * 1024 } }),
  )
  importLogbook(
    @CurrentUser() user: { id: string },
    @UploadedFile() file: Express.Multer.File,
    @Body('source') source: string,
    @Body('preview') preview: string,
  ) {
    if (!file) {
      throw new BadRequestException('No file uploaded');
    }
    if (!source || !['foreflight', 'garmin'].includes(source)) {
      throw new BadRequestException('Source must be "foreflight" or "garmin"');
    }
    const isPreview = preview !== 'false';
    const fileContent = file.buffer.toString('utf-8');
    return this.importService.processImport(
      user.id,
      fileContent,
      source,
      isPreview,
    );
  }

  @Get(':id')
  findOne(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.logbookService.findOne(user.id, id);
  }

  @Post()
  create(
    @CurrentUser() user: { id: string },
    @Body() dto: CreateLogbookEntryDto,
  ) {
    return this.logbookService.create(user.id, dto);
  }

  @Put(':id')
  update(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateLogbookEntryDto,
  ) {
    return this.logbookService.update(user.id, id, dto);
  }

  @Delete(':id')
  remove(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.logbookService.remove(user.id, id);
  }
}
