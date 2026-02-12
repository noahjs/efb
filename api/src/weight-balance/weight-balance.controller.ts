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
import { CurrentUser } from '../auth/decorators/current-user.decorator';

@Controller('aircraft/:aircraftId/wb')
export class WeightBalanceController {
  constructor(private readonly wbService: WeightBalanceService) {}

  // --- Profiles ---

  @Get('profiles')
  findProfiles(
    @CurrentUser() user: { id: string },
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
  ) {
    return this.wbService.findProfiles(aircraftId, user.id);
  }

  @Post('profiles')
  createProfile(
    @CurrentUser() user: { id: string },
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Body() dto: CreateWBProfileDto,
  ) {
    return this.wbService.createProfile(aircraftId, dto, user.id);
  }

  @Get('profiles/:profileId')
  findProfile(
    @CurrentUser() user: { id: string },
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
  ) {
    return this.wbService.findProfile(aircraftId, profileId, user.id);
  }

  @Put('profiles/:profileId')
  updateProfile(
    @CurrentUser() user: { id: string },
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
    @Body() dto: UpdateWBProfileDto,
  ) {
    return this.wbService.updateProfile(aircraftId, profileId, dto, user.id);
  }

  @Delete('profiles/:profileId')
  removeProfile(
    @CurrentUser() user: { id: string },
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
  ) {
    return this.wbService.removeProfile(aircraftId, profileId, user.id);
  }

  // --- Stations ---

  @Post('profiles/:profileId/stations')
  createStation(
    @CurrentUser() user: { id: string },
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
    @Body() dto: CreateWBStationDto,
  ) {
    return this.wbService.createStation(aircraftId, profileId, dto, user.id);
  }

  @Put('profiles/:profileId/stations/:stationId')
  updateStation(
    @CurrentUser() user: { id: string },
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
    @Param('stationId', ParseIntPipe) stationId: number,
    @Body() dto: UpdateWBStationDto,
  ) {
    return this.wbService.updateStation(
      aircraftId,
      profileId,
      stationId,
      dto,
      user.id,
    );
  }

  @Delete('profiles/:profileId/stations/:stationId')
  removeStation(
    @CurrentUser() user: { id: string },
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
    @Param('stationId', ParseIntPipe) stationId: number,
  ) {
    return this.wbService.removeStation(
      aircraftId,
      profileId,
      stationId,
      user.id,
    );
  }

  @Put('profiles/:profileId/stations/reorder')
  reorderStations(
    @CurrentUser() user: { id: string },
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
    @Body() body: { station_ids: number[] },
  ) {
    return this.wbService.reorderStations(
      aircraftId,
      profileId,
      body.station_ids,
      user.id,
    );
  }

  // --- Envelopes ---

  @Put('profiles/:profileId/envelopes')
  upsertEnvelope(
    @CurrentUser() user: { id: string },
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
    @Body() dto: UpsertWBEnvelopeDto,
  ) {
    return this.wbService.upsertEnvelope(aircraftId, profileId, dto, user.id);
  }

  // --- Scenarios ---

  @Get('profiles/:profileId/scenarios')
  findScenarios(
    @CurrentUser() user: { id: string },
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
  ) {
    return this.wbService.findScenarios(aircraftId, profileId, user.id);
  }

  @Post('profiles/:profileId/scenarios')
  createScenario(
    @CurrentUser() user: { id: string },
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
    @Body() dto: CreateWBScenarioDto,
  ) {
    return this.wbService.createScenario(aircraftId, profileId, dto, user.id);
  }

  @Get('profiles/:profileId/scenarios/:scenarioId')
  findScenario(
    @CurrentUser() user: { id: string },
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
    @Param('scenarioId', ParseIntPipe) scenarioId: number,
  ) {
    return this.wbService.findScenario(
      aircraftId,
      profileId,
      scenarioId,
      user.id,
    );
  }

  @Put('profiles/:profileId/scenarios/:scenarioId')
  updateScenario(
    @CurrentUser() user: { id: string },
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
      user.id,
    );
  }

  @Delete('profiles/:profileId/scenarios/:scenarioId')
  removeScenario(
    @CurrentUser() user: { id: string },
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
    @Param('scenarioId', ParseIntPipe) scenarioId: number,
  ) {
    return this.wbService.removeScenario(
      aircraftId,
      profileId,
      scenarioId,
      user.id,
    );
  }

  // --- Calculate (stateless) ---

  @Post('profiles/:profileId/calculate')
  calculate(
    @CurrentUser() user: { id: string },
    @Param('aircraftId', ParseIntPipe) aircraftId: number,
    @Param('profileId', ParseIntPipe) profileId: number,
    @Body() dto: CalculateWBDto,
  ) {
    return this.wbService.calculate(aircraftId, profileId, dto, user.id);
  }
}
