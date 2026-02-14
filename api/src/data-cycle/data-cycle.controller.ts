import {
  Controller,
  Get,
  Post,
  Delete,
  Param,
  Body,
  Query,
} from '@nestjs/common';
import { DataCycleService } from './data-cycle.service';
import { CycleDataGroup } from './entities/data-cycle.entity';

@Controller('admin/data-cycles')
export class DataCycleController {
  constructor(private readonly service: DataCycleService) {}

  @Get()
  list(@Query('group') group?: CycleDataGroup) {
    return this.service.list(group);
  }

  @Post()
  create(
    @Body()
    body: {
      data_group: CycleDataGroup;
      cycle_code: string;
      effective_date: string;
      expiration_date: string;
      source_url?: string;
    },
  ) {
    return this.service.create(body);
  }

  @Get('active')
  getActive() {
    return this.service.getActive();
  }

  @Get('pending')
  getPending() {
    return this.service.getPending();
  }

  @Get(':id')
  findById(@Param('id') id: string) {
    return this.service.findById(id);
  }

  @Post(':id/stage')
  stage(@Param('id') id: string) {
    return this.service.stage(id);
  }

  @Post(':id/activate')
  activate(@Param('id') id: string) {
    return this.service.activate(id);
  }

  @Post(':id/rollback')
  rollback(@Param('id') id: string) {
    return this.service.rollback(id);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.service.remove(id);
  }
}
