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
import { CurrentUser } from '../auth/decorators/current-user.decorator';

@Controller('flights')
export class FlightsController {
  constructor(private readonly flightsService: FlightsService) {}

  @Get()
  async findAll(
    @CurrentUser() user: { id: string },
    @Query('q') query?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.flightsService.findAll(
      user.id,
      query,
      limit ? parseInt(limit, 10) : 50,
      offset ? parseInt(offset, 10) : 0,
    );
  }

  @Get(':id')
  async findOne(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.flightsService.findById(id, user.id);
  }

  @Post()
  async create(
    @CurrentUser() user: { id: string },
    @Body() dto: CreateFlightDto,
  ) {
    return this.flightsService.create(dto, user.id);
  }

  @Put(':id')
  async update(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateFlightDto,
  ) {
    return this.flightsService.update(id, dto, user.id);
  }

  @Delete(':id')
  async remove(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.flightsService.remove(id, user.id);
  }

  @Get(':id/calculate-debug')
  async calculateDebug(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.flightsService.calculateDebug(id, user.id);
  }

  @Post(':id/copy')
  async copy(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.flightsService.copy(id, user.id);
  }
}
