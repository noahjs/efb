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
import { AircraftService } from './aircraft.service';
import { CreateAircraftDto } from './dto/create-aircraft.dto';
import { UpdateAircraftDto } from './dto/update-aircraft.dto';
import { CreatePerformanceProfileDto } from './dto/create-performance-profile.dto';
import { UpdatePerformanceProfileDto } from './dto/update-performance-profile.dto';
import { CreateFuelTankDto } from './dto/create-fuel-tank.dto';
import { UpdateFuelTankDto } from './dto/update-fuel-tank.dto';
import { UpdateEquipmentDto } from './dto/update-equipment.dto';
import { CurrentUser } from '../auth/decorators/current-user.decorator';

@Controller('aircraft')
export class AircraftController {
  constructor(private readonly aircraftService: AircraftService) {}

  // --- Aircraft CRUD ---

  @Get()
  findAll(
    @CurrentUser() user: { id: string },
    @Query('q') query?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.aircraftService.findAll(
      user.id,
      query,
      limit ? parseInt(limit, 10) : 50,
      offset ? parseInt(offset, 10) : 0,
    );
  }

  @Get('default')
  findDefault(@CurrentUser() user: { id: string }) {
    return this.aircraftService.findDefault(user.id);
  }

  @Get(':id')
  findOne(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.aircraftService.findOne(id, user.id);
  }

  @Post()
  create(@CurrentUser() user: { id: string }, @Body() dto: CreateAircraftDto) {
    return this.aircraftService.create(dto, user.id);
  }

  @Put(':id')
  update(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateAircraftDto,
  ) {
    return this.aircraftService.update(id, dto, user.id);
  }

  @Delete(':id')
  remove(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.aircraftService.remove(id, user.id);
  }

  @Put(':id/default')
  setDefault(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.aircraftService.setDefault(id, user.id);
  }

  // --- Performance Profiles ---

  @Get(':id/profiles')
  findProfiles(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.aircraftService.findProfiles(id, user.id);
  }

  @Post(':id/profiles')
  createProfile(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: CreatePerformanceProfileDto,
  ) {
    return this.aircraftService.createProfile(id, dto, user.id);
  }

  @Put(':id/profiles/:pid')
  updateProfile(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
    @Param('pid', ParseIntPipe) pid: number,
    @Body() dto: UpdatePerformanceProfileDto,
  ) {
    return this.aircraftService.updateProfile(id, pid, dto, user.id);
  }

  @Delete(':id/profiles/:pid')
  removeProfile(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
    @Param('pid', ParseIntPipe) pid: number,
  ) {
    return this.aircraftService.removeProfile(id, pid, user.id);
  }

  @Put(':id/profiles/:pid/default')
  setDefaultProfile(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
    @Param('pid', ParseIntPipe) pid: number,
  ) {
    return this.aircraftService.setDefaultProfile(id, pid, user.id);
  }

  @Post(':id/profiles/:pid/apply-template')
  applyTemplate(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
    @Param('pid', ParseIntPipe) pid: number,
    @Body() body: { type: string },
  ) {
    return this.aircraftService.applyTemplate(id, pid, body.type, user.id);
  }

  // --- Fuel Tanks ---

  @Get(':id/fuel-tanks')
  findTanks(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.aircraftService.findTanks(id, user.id);
  }

  @Post(':id/fuel-tanks')
  createTank(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: CreateFuelTankDto,
  ) {
    return this.aircraftService.createTank(id, dto, user.id);
  }

  @Put(':id/fuel-tanks/:tid')
  updateTank(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
    @Param('tid', ParseIntPipe) tid: number,
    @Body() dto: UpdateFuelTankDto,
  ) {
    return this.aircraftService.updateTank(id, tid, dto, user.id);
  }

  @Delete(':id/fuel-tanks/:tid')
  removeTank(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
    @Param('tid', ParseIntPipe) tid: number,
  ) {
    return this.aircraftService.removeTank(id, tid, user.id);
  }

  // --- Equipment ---

  @Get(':id/equipment')
  findEquipment(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.aircraftService.findEquipment(id, user.id);
  }

  @Put(':id/equipment')
  upsertEquipment(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateEquipmentDto,
  ) {
    return this.aircraftService.upsertEquipment(id, dto, user.id);
  }
}
