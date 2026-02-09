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
} from '@nestjs/common';
import { EndorsementsService } from './endorsements.service';
import { CreateEndorsementDto } from './dto/create-endorsement.dto';
import { UpdateEndorsementDto } from './dto/update-endorsement.dto';

@Controller('endorsements')
export class EndorsementsController {
  constructor(private readonly endorsementsService: EndorsementsService) {}

  @Get()
  findAll(
    @Query('q') query?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.endorsementsService.findAll(
      query,
      limit ? parseInt(limit, 10) : 50,
      offset ? parseInt(offset, 10) : 0,
    );
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.endorsementsService.findOne(id);
  }

  @Post()
  create(@Body() dto: CreateEndorsementDto) {
    return this.endorsementsService.create(dto);
  }

  @Put(':id')
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateEndorsementDto,
  ) {
    return this.endorsementsService.update(id, dto);
  }

  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.endorsementsService.remove(id);
  }
}
