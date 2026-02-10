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

@Controller('logbook')
export class LogbookController {
  constructor(
    private readonly logbookService: LogbookService,
    private readonly currencyService: CurrencyService,
    private readonly importService: ImportService,
  ) {}

  @Get()
  findAll(
    @Query('q') query?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.logbookService.findAll(
      query,
      limit ? parseInt(limit, 10) : 50,
      offset ? parseInt(offset, 10) : 0,
    );
  }

  @Get('summary')
  getSummary() {
    return this.logbookService.getSummary();
  }

  @Get('experience-report')
  getExperienceReport(@Query('period') period?: string) {
    return this.logbookService.getExperienceReport(period);
  }

  @Get('currency')
  getCurrency() {
    return this.currencyService.getCurrency();
  }

  @Post('import')
  @UseInterceptors(
    FileInterceptor('file', { limits: { fileSize: 10 * 1024 * 1024 } }),
  )
  importLogbook(
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
    return this.importService.processImport(fileContent, source, isPreview);
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.logbookService.findOne(id);
  }

  @Post()
  create(@Body() dto: CreateLogbookEntryDto) {
    return this.logbookService.create(dto);
  }

  @Put(':id')
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateLogbookEntryDto,
  ) {
    return this.logbookService.update(id, dto);
  }

  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.logbookService.remove(id);
  }
}
