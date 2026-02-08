import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Param,
  Query,
  Body,
  ParseIntPipe,
} from '@nestjs/common';
import { FlightsService } from './flights.service';
import { CreateFlightDto } from './dto/create-flight.dto';
import { UpdateFlightDto } from './dto/update-flight.dto';

@Controller('flights')
export class FlightsController {
  constructor(private readonly flightsService: FlightsService) {}

  @Get()
  async findAll(
    @Query('q') query?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.flightsService.findAll(
      query,
      limit ? parseInt(limit, 10) : 50,
      offset ? parseInt(offset, 10) : 0,
    );
  }

  @Get(':id')
  async findOne(@Param('id', ParseIntPipe) id: number) {
    return this.flightsService.findById(id);
  }

  @Post()
  async create(@Body() dto: CreateFlightDto) {
    return this.flightsService.create(dto);
  }

  @Put(':id')
  async update(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateFlightDto,
  ) {
    return this.flightsService.update(id, dto);
  }

  @Delete(':id')
  async remove(@Param('id', ParseIntPipe) id: number) {
    return this.flightsService.remove(id);
  }

  @Post(':id/copy')
  async copy(@Param('id', ParseIntPipe) id: number) {
    return this.flightsService.copy(id);
  }
}
