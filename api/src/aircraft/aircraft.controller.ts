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

@Controller('aircraft')
export class AircraftController {
  constructor(private readonly aircraftService: AircraftService) {}

  // --- Aircraft CRUD ---

  @Get()
  findAll(
    @Query('q') query?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.aircraftService.findAll(
      query,
      limit ? parseInt(limit, 10) : 50,
      offset ? parseInt(offset, 10) : 0,
    );
  }

  @Get('default')
  findDefault() {
    return this.aircraftService.findDefault();
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.aircraftService.findOne(id);
  }

  @Post()
  create(@Body() dto: CreateAircraftDto) {
    return this.aircraftService.create(dto);
  }

  @Put(':id')
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateAircraftDto,
  ) {
    return this.aircraftService.update(id, dto);
  }

  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.aircraftService.remove(id);
  }

  @Put(':id/default')
  setDefault(@Param('id', ParseIntPipe) id: number) {
    return this.aircraftService.setDefault(id);
  }

  // --- Performance Profiles ---

  @Get(':id/profiles')
  findProfiles(@Param('id', ParseIntPipe) id: number) {
    return this.aircraftService.findProfiles(id);
  }

  @Post(':id/profiles')
  createProfile(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: CreatePerformanceProfileDto,
  ) {
    return this.aircraftService.createProfile(id, dto);
  }

  @Put(':id/profiles/:pid')
  updateProfile(
    @Param('id', ParseIntPipe) id: number,
    @Param('pid', ParseIntPipe) pid: number,
    @Body() dto: UpdatePerformanceProfileDto,
  ) {
    return this.aircraftService.updateProfile(id, pid, dto);
  }

  @Delete(':id/profiles/:pid')
  removeProfile(
    @Param('id', ParseIntPipe) id: number,
    @Param('pid', ParseIntPipe) pid: number,
  ) {
    return this.aircraftService.removeProfile(id, pid);
  }

  @Put(':id/profiles/:pid/default')
  setDefaultProfile(
    @Param('id', ParseIntPipe) id: number,
    @Param('pid', ParseIntPipe) pid: number,
  ) {
    return this.aircraftService.setDefaultProfile(id, pid);
  }

  @Post(':id/profiles/:pid/apply-template')
  applyTemplate(
    @Param('id', ParseIntPipe) id: number,
    @Param('pid', ParseIntPipe) pid: number,
    @Body() body: { type: string },
  ) {
    return this.aircraftService.applyTemplate(id, pid, body.type);
  }

  // --- Fuel Tanks ---

  @Get(':id/fuel-tanks')
  findTanks(@Param('id', ParseIntPipe) id: number) {
    return this.aircraftService.findTanks(id);
  }

  @Post(':id/fuel-tanks')
  createTank(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: CreateFuelTankDto,
  ) {
    return this.aircraftService.createTank(id, dto);
  }

  @Put(':id/fuel-tanks/:tid')
  updateTank(
    @Param('id', ParseIntPipe) id: number,
    @Param('tid', ParseIntPipe) tid: number,
    @Body() dto: UpdateFuelTankDto,
  ) {
    return this.aircraftService.updateTank(id, tid, dto);
  }

  @Delete(':id/fuel-tanks/:tid')
  removeTank(
    @Param('id', ParseIntPipe) id: number,
    @Param('tid', ParseIntPipe) tid: number,
  ) {
    return this.aircraftService.removeTank(id, tid);
  }

  // --- Equipment ---

  @Get(':id/equipment')
  findEquipment(@Param('id', ParseIntPipe) id: number) {
    return this.aircraftService.findEquipment(id);
  }

  @Put(':id/equipment')
  upsertEquipment(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateEquipmentDto,
  ) {
    return this.aircraftService.upsertEquipment(id, dto);
  }
}
