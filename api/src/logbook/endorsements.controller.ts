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
import { CurrentUser } from '../auth/decorators/current-user.decorator';

@Controller('endorsements')
export class EndorsementsController {
  constructor(private readonly endorsementsService: EndorsementsService) {}

  @Get()
  findAll(
    @CurrentUser() user: { id: string },
    @Query('q') query?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.endorsementsService.findAll(
      user.id,
      query,
      limit ? parseInt(limit, 10) : 50,
      offset ? parseInt(offset, 10) : 0,
    );
  }

  @Get(':id')
  findOne(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.endorsementsService.findOne(user.id, id);
  }

  @Post()
  create(
    @CurrentUser() user: { id: string },
    @Body() dto: CreateEndorsementDto,
  ) {
    return this.endorsementsService.create(user.id, dto);
  }

  @Put(':id')
  update(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateEndorsementDto,
  ) {
    return this.endorsementsService.update(user.id, id, dto);
  }

  @Delete(':id')
  remove(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.endorsementsService.remove(user.id, id);
  }
}
