import { Controller, Post, Body } from '@nestjs/common';
import {
  IsOptional,
  IsString,
  IsNumber,
  IsArray,
} from 'class-validator';
import { CalculateService } from './calculate.service';

class CalculateDto {
  @IsOptional()
  @IsString()
  departure_identifier?: string;

  @IsOptional()
  @IsString()
  destination_identifier?: string;

  @IsOptional()
  @IsString()
  route_string?: string;

  @IsOptional()
  @IsNumber()
  cruise_altitude?: number;

  @IsOptional()
  @IsNumber()
  true_airspeed?: number;

  @IsOptional()
  @IsNumber()
  fuel_burn_rate?: number;

  @IsOptional()
  @IsString()
  etd?: string;

  @IsOptional()
  @IsNumber()
  performance_profile_id?: number;
}

class CalculateAltitudesDto extends CalculateDto {
  @IsArray()
  altitudes: number[];
}

@Controller('calculate')
export class CalculateController {
  constructor(private readonly calculateService: CalculateService) {}

  @Post()
  async calculate(@Body() dto: CalculateDto) {
    return this.calculateService.calculate(dto);
  }

  @Post('debug')
  async calculateDebug(@Body() dto: CalculateDto) {
    return this.calculateService.calculateDebug(dto);
  }

  @Post('altitudes')
  async calculateAltitudes(@Body() dto: CalculateAltitudesDto) {
    return this.calculateService.calculateForAltitudes(dto, dto.altitudes);
  }
}
