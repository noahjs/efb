import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  ParseIntPipe,
} from '@nestjs/common';
import { WeightBalanceService } from './weight-balance.service';
import { CreateWBProfileDto } from './dto/create-wb-profile.dto';
import { UpdateWBProfileDto } from './dto/update-wb-profile.dto';
import { CreateWBStationDto } from './dto/create-wb-station.dto';
import { UpdateWBStationDto } from './dto/update-wb-station.dto';
import { UpsertWBEnvelopeDto } from './dto/upsert-wb-envelope.dto';
import { CreateWBScenarioDto } from './dto/create-wb-scenario.dto';
import { UpdateWBScenarioDto } from './dto/update-wb-scenario.dto';
import { CalculateWBDto } from './dto/calculate-wb.dto';

@Controller('aircraft/:aircraftId/wb')
export class WeightBalanceController {
  constructor(private readonly wbService: WeightBalanceService) {}

  // --- Profiles ---

  @Get('profiles')
  findProfiles(@Param('aircraftId', ParseIntPipe) aircraftId: number) {
    return this.wbService.findProfiles(aircraftId);
  }

  @Post('profiles')
  createProfile(
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Body() dto: CreateWBProfileDto,
  ) {
    return this.wbService.createProfile(aircraftId, dto);
  }

  @Get('profiles/:profileId')
  findProfile(
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
  ) {
    return this.wbService.findProfile(aircraftId, profileId);
  }

  @Put('profiles/:profileId')
  updateProfile(
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
    @Body() dto: UpdateWBProfileDto,
  ) {
    return this.wbService.updateProfile(aircraftId, profileId, dto);
  }

  @Delete('profiles/:profileId')
  removeProfile(
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
  ) {
    return this.wbService.removeProfile(aircraftId, profileId);
  }

  // --- Stations ---

  @Post('profiles/:profileId/stations')
  createStation(
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
    @Body() dto: CreateWBStationDto,
  ) {
    return this.wbService.createStation(aircraftId, profileId, dto);
  }

  @Put('profiles/:profileId/stations/:stationId')
  updateStation(
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
    @Param('stationId', ParseIntPipe) stationId: number,
    @Body() dto: UpdateWBStationDto,
  ) {
    return this.wbService.updateStation(aircraftId, profileId, stationId, dto);
  }

  @Delete('profiles/:profileId/stations/:stationId')
  removeStation(
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
    @Param('stationId', ParseIntPipe) stationId: number,
  ) {
    return this.wbService.removeStation(aircraftId, profileId, stationId);
  }

  @Put('profiles/:profileId/stations/reorder')
  reorderStations(
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
    @Body() body: { station_ids: number[] },
  ) {
    return this.wbService.reorderStations(
      aircraftId,
      profileId,
      body.station_ids,
    );
  }

  // --- Envelopes ---

  @Put('profiles/:profileId/envelopes')
  upsertEnvelope(
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
    @Body() dto: UpsertWBEnvelopeDto,
  ) {
    return this.wbService.upsertEnvelope(aircraftId, profileId, dto);
  }

  // --- Scenarios ---

  @Get('profiles/:profileId/scenarios')
  findScenarios(
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
  ) {
    return this.wbService.findScenarios(aircraftId, profileId);
  }

  @Post('profiles/:profileId/scenarios')
  createScenario(
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
    @Body() dto: CreateWBScenarioDto,
  ) {
    return this.wbService.createScenario(aircraftId, profileId, dto);
  }

  @Get('profiles/:profileId/scenarios/:scenarioId')
  findScenario(
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
    @Param('scenarioId', ParseIntPipe) scenarioId: number,
  ) {
    return this.wbService.findScenario(aircraftId, profileId, scenarioId);
  }

  @Put('profiles/:profileId/scenarios/:scenarioId')
  updateScenario(
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
    @Param('scenarioId', ParseIntPipe) scenarioId: number,
    @Body() dto: UpdateWBScenarioDto,
  ) {
    return this.wbService.updateScenario(
      aircraftId,
      profileId,
      scenarioId,
      dto,
    );
  }

  @Delete('profiles/:profileId/scenarios/:scenarioId')
  removeScenario(
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
    @Param('scenarioId', ParseIntPipe) scenarioId: number,
  ) {
    return this.wbService.removeScenario(aircraftId, profileId, scenarioId);
  }

  // --- Calculate (stateless) ---

  @Post('profiles/:profileId/calculate')
  calculate(
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
    @Body() dto: CalculateWBDto,
  ) {
    return this.wbService.calculate(aircraftId, profileId, dto);
  }
}
